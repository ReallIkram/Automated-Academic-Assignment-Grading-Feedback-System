import os,secrets,csv,io
from datetime import datetime,timezone,timedelta
from contextlib import asynccontextmanager
import bcrypt,jwt
from fastapi import FastAPI,Depends,HTTPException
from fastapi.security import HTTPBearer,HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from pydantic import BaseModel,Field
from redis import Redis
from rq import Queue
from .db import *
SECRET=os.getenv('JWT_SECRET')
if not SECRET or len(SECRET)<32: raise RuntimeError('Set JWT_SECRET to a random value of at least 32 characters.')
@asynccontextmanager
async def lifespan(app):
 Base.metadata.create_all(engine); yield
app=FastAPI(title='GradeFlow API',lifespan=lifespan)
app.add_middleware(CORSMiddleware,allow_origins=os.getenv('CORS_ORIGINS','http://localhost:3000').split(','),allow_credentials=False,allow_methods=['*'],allow_headers=['*'])
bearer=HTTPBearer()
def current(auth:HTTPAuthorizationCredentials=Depends(bearer),db=Depends(get_db)):
 try: data=jwt.decode(auth.credentials,SECRET,algorithms=['HS256']); u=db.get(User,int(data['sub']))
 except Exception: raise HTTPException(401,'Session expired. Sign in again.')
 if not u: raise HTTPException(401,'Unknown user')
 return u
def staff(u):
 if u.role not in ('instructor','ta'): raise HTTPException(403,'Instructor access required')
def manages(db,u,c):
 return c.owner==u.id or (u.role=='ta' and db.query(Enrollment).filter_by(course_id=c.id,user_id=u.id).first() is not None)
def access_course(db,u,cid,write=False):
 c=db.get(Course,cid)
 if not c: raise HTTPException(404,'Course not found')
 if write and not manages(db,u,c): raise HTTPException(403,'Only the course instructor may change this course')
 if c.owner!=u.id and not db.query(Enrollment).filter_by(course_id=cid,user_id=u.id).first(): raise HTTPException(403,'Enroll in this course first')
 return c
def user_json(u): return {'id':u.id,'name':u.name,'email':u.email,'role':u.role}
class Register(BaseModel):
 name:str=Field(min_length=2,max_length=100); email:str=Field(min_length=5,max_length=255); password:str=Field(min_length=8,max_length=72)
class Login(BaseModel):
 email:str; password:str=Field(max_length=72)
class CourseInput(BaseModel):
 title:str=Field(min_length=2,max_length=200)
class EnrollInput(BaseModel): code:str
class TestInput(BaseModel):
 stdin:str=Field(max_length=10000); expected:str=Field(max_length=10000); hidden:bool=False
class AssignmentInput(BaseModel):
 course_id:int; title:str=Field(min_length=2,max_length=200); description:str=Field(max_length=20000); language:str; tests:list[TestInput]=Field(min_length=1,max_length=30); deadline:str; max_score:float=Field(default=100,gt=0,le=1000)
class SubmissionInput(BaseModel):
 assignment_id:int; code:str=Field(min_length=1,max_length=50000)
class Review(BaseModel):
 score:float=Field(ge=0); feedback:str=Field(max_length=10000); published:bool=True
@app.get('/health')
def health(): return {'status':'ok'}
@app.post('/auth/register')
def register(data:Register,db=Depends(get_db)):
 email=data.email.strip().lower()
 if '@' not in email: raise HTTPException(422,'Invalid email')
 if db.query(User).filter_by(email=email).first(): raise HTTPException(409,'Email already registered')
 u=User(name=data.name,email=email,password=bcrypt.hashpw(data.password.encode(),bcrypt.gensalt()).decode(),role='student'); db.add(u); db.commit(); return user_json(u)
@app.post('/auth/login')
def login(data:Login,db=Depends(get_db)):
 u=db.query(User).filter_by(email=data.email.strip().lower()).first()
 if not u or not bcrypt.checkpw(data.password.encode(),u.password.encode()): raise HTTPException(401,'Incorrect email or password')
 token=jwt.encode({'sub':str(u.id),'exp':datetime.now(timezone.utc)+timedelta(hours=8)},SECRET,algorithm='HS256')
 return {'token':token,'user':user_json(u)}
@app.get('/me')
def me(u=Depends(current)): return user_json(u)
@app.get('/courses')
def courses(u=Depends(current),db=Depends(get_db)):
 ids=[e.course_id for e in db.query(Enrollment).filter_by(user_id=u.id)]
 return [{'id':c.id,'title':c.title,'code':c.code,'owner':c.owner} for c in db.query(Course).filter((Course.owner==u.id)|(Course.id.in_(ids))).all()]
@app.post('/courses')
def create_course(data:CourseInput,u=Depends(current),db=Depends(get_db)):
 staff(u); c=Course(title=data.title,owner=u.id,code=secrets.token_hex(4)); db.add(c); db.commit(); return {'id':c.id,'code':c.code}
@app.post('/courses/enroll')
def enroll(data:EnrollInput,u=Depends(current),db=Depends(get_db)):
 c=db.query(Course).filter_by(code=data.code.strip()).first()
 if not c: raise HTTPException(404,'Invalid enrollment code')
 if not db.query(Enrollment).filter_by(course_id=c.id,user_id=u.id).first(): db.add(Enrollment(course_id=c.id,user_id=u.id)); db.commit()
 return {'ok':True}
@app.get('/assignments')
def assignments(u=Depends(current),db=Depends(get_db)):
 ids=[e.course_id for e in db.query(Enrollment).filter_by(user_id=u.id)]+[c.id for c in db.query(Course).filter_by(owner=u.id)]
 result=[]
 for a in db.query(Assignment).filter(Assignment.course_id.in_(ids)).all():
  item={k:getattr(a,k) for k in ('id','course_id','title','description','language','deadline','max_score')}
  owner=manages(db,u,db.get(Course,a.course_id))
  item['tests']=a.tests if owner else [t for t in a.tests if not t.get('hidden')]
  item['can_manage']=owner; result.append(item)
 return result
@app.post('/assignments')
def create_assignment(data:AssignmentInput,u=Depends(current),db=Depends(get_db)):
 access_course(db,u,data.course_id,True)
 if data.language not in ('python','java','cpp'): raise HTTPException(422,'Unsupported language')
 try: deadline=datetime.fromisoformat(data.deadline.replace('Z','+00:00')); assert deadline.tzinfo
 except Exception: raise HTTPException(422,'Deadline must include timezone, e.g. 2026-12-31T23:59:00+05:00')
 a=Assignment(**data.model_dump()); a.tests=[t.model_dump() for t in data.tests]; db.add(a); db.commit(); return {'id':a.id}
def enqueue(sid):
 Queue('grading',connection=Redis.from_url(os.getenv('REDIS_URL','redis://localhost:6379/0'))).enqueue('app.jobs.grade',sid,job_timeout=240)
@app.post('/submissions')
def submit(data:SubmissionInput,u=Depends(current),db=Depends(get_db)):
 a=db.get(Assignment,data.assignment_id)
 if not a: raise HTTPException(404,'Assignment not found')
 access_course(db,u,a.course_id)
 if datetime.now(timezone.utc)>datetime.fromisoformat(a.deadline.replace('Z','+00:00')): raise HTTPException(409,'Deadline has passed')
 s=Submission(assignment_id=a.id,user_id=u.id,code=data.code,created_at=datetime.now(timezone.utc).isoformat()); db.add(s); db.commit()
 try: enqueue(s.id)
 except Exception: s.status='error'; s.report={'feedback':'Queue unavailable; instructor can regrade.'}; db.commit(); raise HTTPException(503,'Queue unavailable')
 return {'id':s.id,'status':s.status}
def visible_submission(db,u,s):
 a=db.get(Assignment,s.assignment_id); owner=manages(db,u,db.get(Course,a.course_id))
 if s.user_id!=u.id and not owner: raise HTTPException(403,'Access denied')
 report=dict(s.report or {})
 if not owner:
  report.pop('matches',None); report.pop('error',None)
  report['tests']=[({'name':t['name'],'passed':t['passed'],'hidden':True} if t.get('hidden') else t) for t in report.get('tests',[])]
 if 'analysis' in report: report['analysis']={k:v for k,v in report['analysis'].items() if k!='fingerprint'}
 student=db.get(User,s.user_id)
 return {'id':s.id,'assignment_id':s.assignment_id,'title':a.title,'student':student.name,'status':s.status,'score':s.reviewed_score if s.reviewed_score is not None and (owner or s.published) else s.score,'max_score':a.max_score,'report':report,'created_at':s.created_at,'instructor_feedback':s.instructor_feedback if owner or s.published else None,'published':bool(s.published),'can_manage':owner}
@app.get('/submissions')
def submissions(u=Depends(current),db=Depends(get_db)):
 owned=[c.id for c in db.query(Course).all() if manages(db,u,c)]; aids=[a.id for a in db.query(Assignment).filter(Assignment.course_id.in_(owned))]
 return [visible_submission(db,u,s) for s in db.query(Submission).filter((Submission.user_id==u.id)|(Submission.assignment_id.in_(aids))).order_by(Submission.id.desc()).all()]
@app.post('/submissions/{sid}/review')
def review(sid:int,data:Review,u=Depends(current),db=Depends(get_db)):
 s=db.get(Submission,sid)
 if not s: raise HTTPException(404,'Submission not found')
 a=db.get(Assignment,s.assignment_id); access_course(db,u,a.course_id,True)
 if data.score>a.max_score: raise HTTPException(422,'Score exceeds assignment maximum')
 s.reviewed_score=data.score; s.instructor_feedback=data.feedback; s.published=int(data.published); db.commit(); return {'ok':True}
@app.post('/submissions/{sid}/regrade')
def regrade(sid:int,u=Depends(current),db=Depends(get_db)):
 s=db.get(Submission,sid)
 if not s: raise HTTPException(404,'Submission not found')
 a=db.get(Assignment,s.assignment_id); access_course(db,u,a.course_id,True)
 if s.status in ('queued','running'): raise HTTPException(409,'Already queued or running')
 s.status='queued'; s.score=None; s.report=None; s.reviewed_score=None; s.published=0; db.commit()
 try: enqueue(s.id)
 except Exception: s.status='error'; db.commit(); raise HTTPException(503,'Queue unavailable')
 return {'ok':True}
@app.get('/reports.csv')
def report_csv(u=Depends(current),db=Depends(get_db)):
 out=io.StringIO(); writer=csv.writer(out); writer.writerow(['Submission','Assignment','Student','Status','Score','Max score'])
 for row in submissions(u,db):
  def safe(v): return "'"+str(v) if str(v).startswith(('=','+','-','@')) else v
  writer.writerow([safe(row[k]) for k in ('id','title','student','status','score','max_score')])
 return Response(out.getvalue(),media_type='text/csv',headers={'Content-Disposition':'attachment; filename=grades.csv'})
