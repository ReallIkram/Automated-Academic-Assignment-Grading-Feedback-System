import os
from sqlalchemy import create_engine, Column, Integer, String, Text, ForeignKey, JSON, Float, UniqueConstraint
from sqlalchemy.orm import declarative_base, sessionmaker
engine = create_engine(os.getenv('DATABASE_URL','sqlite:///./gradeflow.db'), **({'connect_args':{'check_same_thread':False}} if os.getenv('DATABASE_URL','sqlite:').startswith('sqlite:') else {}))
Session = sessionmaker(bind=engine)
Base = declarative_base()
class User(Base):
 __tablename__='users'
 id=Column(Integer,primary_key=True); name=Column(String(100)); email=Column(String(255),unique=True); password=Column(String(255)); role=Column(String(20),default='student')
class Course(Base):
 __tablename__='courses'
 id=Column(Integer,primary_key=True); title=Column(String(200)); owner=Column(Integer,ForeignKey('users.id')); code=Column(String(40),unique=True)
class Enrollment(Base):
 __tablename__='enrollments'
 id=Column(Integer,primary_key=True); course_id=Column(Integer,ForeignKey('courses.id')); user_id=Column(Integer,ForeignKey('users.id'))
 __table_args__=(UniqueConstraint('course_id','user_id'),)
class Assignment(Base):
 __tablename__='assignments'
 id=Column(Integer,primary_key=True); course_id=Column(Integer,ForeignKey('courses.id')); title=Column(String(200)); description=Column(Text); language=Column(String(20)); tests=Column(JSON); deadline=Column(String(40)); max_score=Column(Float,default=100)
class Submission(Base):
 __tablename__='submissions'
 id=Column(Integer,primary_key=True); assignment_id=Column(Integer,ForeignKey('assignments.id')); user_id=Column(Integer,ForeignKey('users.id')); code=Column(Text); status=Column(String(30),default='queued'); score=Column(Float); report=Column(JSON); created_at=Column(String(40)); reviewed_score=Column(Float); instructor_feedback=Column(Text); published=Column(Integer,default=0)
def get_db():
 with Session() as db: yield db
