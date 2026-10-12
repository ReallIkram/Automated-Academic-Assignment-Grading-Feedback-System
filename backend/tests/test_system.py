import os
os.environ['JWT_SECRET']='test-secret-012345678901234567890123456789'
os.environ['DATABASE_URL']='sqlite:///./test-gradeflow.db'
import pytest,bcrypt
from fastapi.testclient import TestClient
from app.main import app
from app.db import Base,engine,Session,User,Submission
from app.analysis import analyze,similarity
@pytest.fixture
def client():
 Base.metadata.drop_all(engine)
 with TestClient(app) as c: yield c
 Base.metadata.drop_all(engine)
def account(c,email,role='student'):
 c.post('/auth/register',json={'name':email,'email':email,'password':'password123'})
 with Session() as db:
  u=db.query(User).filter_by(email=email).one();u.role=role;db.commit()
 token=c.post('/auth/login',json={'email':email,'password':'password123'}).json()['token']
 return {'Authorization':'Bearer '+token}
def test_auth_and_role_boundaries(client):
 c=client;h=account(c,'s@a.com')
 assert c.post('/courses',headers=h,json={'title':'Course'}).status_code==403
 assert c.get('/courses').status_code in (401,403)
 assert c.post('/auth/login',json={'email':'s@a.com','password':'wrong'}).status_code==401
 assert c.post('/auth/register',json={'name':'Test','email':'s@a.com','password':'password123'}).status_code==409
def setup(c):
 teacher=account(c,'t@a.com','instructor');student=account(c,'s@a.com'); outsider=account(c,'o@a.com')
 course=c.post('/courses',headers=teacher,json={'title':'Programming'}).json()
 with Session() as db:
  from app.db import Course
  code=db.get(Course,course['id']).code
 c.post('/courses/enroll',headers=student,json={'code':code})
 a=c.post('/assignments',headers=teacher,json={'course_id':course['id'],'title':'Sum','description':'Sum integers','language':'python','deadline':'2099-01-01T00:00:00+00:00','tests':[{'stdin':'1 2','expected':'3','hidden':False},{'stdin':'3 4','expected':'7','hidden':True}]}).json()
 return teacher,student,outsider,a['id']
def test_hidden_tests_and_access(client,monkeypatch):
 c=client;t,s,o,aid=setup(c);monkeypatch.setattr('app.main.enqueue',lambda sid:None)
 assert len(c.get('/assignments',headers=s).json()[0]['tests'])==1
 assert len(c.get('/assignments',headers=t).json()[0]['tests'])==2
 assert c.post('/submissions',headers=o,json={'assignment_id':aid,'code':'print(3)'}).status_code==403
 result=c.post('/submissions',headers=s,json={'assignment_id':aid,'code':'print(3)'}).json();sid=result['id']
 with Session() as db:
  row=db.get(Submission,sid);row.status='completed';row.score=50;row.report={'tests':[{'name':'Test 2','hidden':True,'passed':False,'stdout':'secret','stderr':'secret'}],'matches':[{'submission_id':999,'similarity':100}]};db.commit()
 report=c.get('/submissions',headers=s).json()[0]['report']
 assert 'matches' not in report and 'stdout' not in report['tests'][0]
 assert c.post(f'/submissions/{sid}/review',headers=o,json={'score':100,'feedback':'test'}).status_code==403
 assert c.post(f'/submissions/{sid}/review',headers=t,json={'score':101,'feedback':'test'}).status_code==422
 assert c.post(f'/submissions/{sid}/review',headers=t,json={'score':90,'feedback':'Reviewed'}).status_code==200
 assert c.get('/submissions',headers=s).json()[0]['score']==90
 assert c.get('/reports.csv',headers=s).status_code==200
def test_grading_and_queue_failure(client,monkeypatch):
 c=client;t,s,o,aid=setup(c);monkeypatch.setattr('app.main.enqueue',lambda sid:None)
 sid=c.post('/submissions',headers=s,json={'assignment_id':aid,'code':'a,b=map(int,input().split());print(a+b)'}).json()['id']
 monkeypatch.setattr('app.jobs.run_case',lambda code,lang,stdin:{'stdout':str(sum(map(int,stdin.split()))),'stderr':'','exit_code':0,'seconds':0.1})
 from app.jobs import grade
 grade(sid)
 row=c.get('/submissions',headers=s).json()[0]
 assert row['status']=='completed' and row['score']==100
 def fail(sid): raise ConnectionError()
 monkeypatch.setattr('app.main.enqueue',fail)
 assert c.post('/submissions',headers=s,json={'assignment_id':aid,'code':'print(3)'}).status_code==503
def test_ast_three_languages():
 p=analyze('a=2\nprint(a)','python');q=analyze('renamed=9\nprint(renamed)','python')
 assert similarity(p['fingerprint'],q['fingerprint'])==100
 assert analyze('public class Main { public static void main(String[] args) { int a=1; } }','java')['fingerprint']
 assert analyze('int main(){int a=1;return a;}','cpp')['fingerprint']
 assert 'syntax_error' in analyze('def broken(','python')
