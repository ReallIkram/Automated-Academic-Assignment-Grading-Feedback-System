import os,bcrypt
from datetime import datetime,timezone,timedelta
from .db import *
Base.metadata.create_all(engine)
with Session() as db:
 password=os.getenv('DEMO_PASSWORD')
 if not password or len(password)<8: raise RuntimeError('Set DEMO_PASSWORD (8+ characters) before seeding.')
 users={}
 for role in ('instructor','student','ta'):
  email=f'{role}@gradeflow.local'; u=db.query(User).filter_by(email=email).first()
  if not u:
   u=User(name=role.title()+' Demo',email=email,role=role,password=bcrypt.hashpw(password.encode(),bcrypt.gensalt()).decode()); db.add(u); db.flush()
  users[role]=u
 c=db.query(Course).filter_by(code='DEMO2026').first()
 if not c:
  c=Course(title='Programming Fundamentals',code='DEMO2026',owner=users['instructor'].id); db.add(c); db.flush()
 for role in ('student','ta'):
  if not db.query(Enrollment).filter_by(course_id=c.id,user_id=users[role].id).first(): db.add(Enrollment(course_id=c.id,user_id=users[role].id))
 if not db.query(Assignment).filter_by(course_id=c.id).first():
  for lang in ('python','java','cpp'):
   db.add(Assignment(course_id=c.id,title='Sum two integers · '+lang,description='Read two space-separated integers from stdin. Print their sum. Java: use public class Main. Handle negative numbers.',language=lang,tests=[{'stdin':'2 3','expected':'5','hidden':False},{'stdin':'-3 10','expected':'7','hidden':True}],deadline=(datetime.now(timezone.utc)+timedelta(days=60)).isoformat(),max_score=100))
 db.commit()
print('Demo users and assignments ready.')
