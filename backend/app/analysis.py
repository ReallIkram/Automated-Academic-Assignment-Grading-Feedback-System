import ast, re
from collections import Counter
from difflib import SequenceMatcher

def analyze(code,language):
 warnings=[]
 if language=='python':
  try: tree=ast.parse(code)
  except SyntaxError as e: return {'syntax_error':str(e),'complexity':0,'warnings':['Fix syntax before resubmitting.'],'fingerprint':[]}
  nodes=list(ast.walk(tree)); fingerprint=[type(n).__name__ for n in nodes]
  complexity=1+sum(isinstance(n,(ast.If,ast.For,ast.While,ast.IfExp,ast.ExceptHandler,ast.BoolOp)) for n in nodes)
  if not ast.get_docstring(tree): warnings.append('Add a module docstring explaining your solution.')
  if any(isinstance(n,ast.ExceptHandler) and n.type is None for n in nodes): warnings.append('Avoid bare except; catch specific exceptions.')
 else:
  from tree_sitter import Language,Parser
  if language=='java':
   import tree_sitter_java as grammar
  else:
   import tree_sitter_cpp as grammar
  parser=Parser(Language(grammar.language())); tree=parser.parse(code.encode())
  def walk(n):
   result=[n.type] if n.is_named else []
   for child in n.children: result.extend(walk(child))
   return result
  fingerprint=walk(tree.root_node)
  complexity=1+sum(n in ('if_statement','for_statement','while_statement','catch_clause','conditional_expression') for n in fingerprint)
  if tree.root_node.has_error: warnings.append('Parser found a syntax issue; inspect compiler feedback.')
 if any(len(line)>100 for line in code.splitlines()): warnings.append('Keep lines under 100 characters for readability.')
 if complexity>10: warnings.append('Split complex logic into smaller functions.')
 return {'complexity':complexity,'warnings':warnings,'fingerprint':fingerprint}

def similarity(left,right):
 if not left or not right: return 0.0
 return round(100*SequenceMatcher(None,left,right,autojunk=False).ratio(),2)
