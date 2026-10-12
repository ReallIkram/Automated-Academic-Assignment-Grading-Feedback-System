"""Trusted local operator command. Never exposed through HTTP."""
import argparse
from .db import Session,User
parser=argparse.ArgumentParser();parser.add_argument('email');parser.add_argument('role',choices=['student','instructor','ta']);args=parser.parse_args()
with Session() as db:
 u=db.query(User).filter_by(email=args.email.lower()).first()
 if not u: raise SystemExit('Register the user first through the application.')
 u.role=args.role;db.commit()
print('Role updated. TAs must enroll in a course to manage it.')
