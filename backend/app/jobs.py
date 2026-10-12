from .db import Session,Submission,Assignment
from .analysis import analyze,similarity
from .sandbox import run_case

def grade(submission_id):
 with Session() as db:
  s=db.get(Submission,submission_id)
  if not s: return
  s.status='running'; db.commit()
  a=db.get(Assignment,s.assignment_id)
  try:
   analysis=analyze(s.code,a.language); cases=[]
   for i,test in enumerate(a.tests):
    result=run_case(s.code,a.language,test['stdin'])
    result['passed']=result['exit_code']==0 and result['stdout'].strip()==test['expected'].strip()
    result['name']=f'Test {i+1}'; result['hidden']=test.get('hidden',False)
    cases.append(result)
   passed=sum(c['passed'] for c in cases)
   matches=[]
   for other in db.query(Submission).filter(Submission.assignment_id==a.id,Submission.user_id!=s.user_id,Submission.status=='completed').all():
    fingerprint=(other.report or {}).get('analysis',{}).get('fingerprint',[])
    value=similarity(analysis['fingerprint'],fingerprint)
    if value>=85: matches.append({'submission_id':other.id,'similarity':value})
   s.score=round(a.max_score*passed/len(cases),2)
   s.report={'tests':cases,'analysis':analysis,'matches':matches,'feedback':f'{passed}/{len(cases)} tests passed. '+('Review failed cases and edge conditions.' if passed<len(cases) else 'All tests passed. Review style suggestions.')}
   s.status='completed'
  except Exception as e:
   s.status='error'; s.report={'feedback':'Grading infrastructure unavailable. Ask the instructor to regrade.','error':type(e).__name__}
  db.commit()
