import sys
from luaparser import ast, astnodes as N
src=open(sys.argv[1],encoding='utf-8').read()
tree=ast.parse(src)
top=set()
def names_in(node):
    out=set()
    for n in ast.walk(node):
        if isinstance(n,N.Name): out.add(n.id)
    return out
report=[]
for st in tree.body.body:
    # functions passed as args in top-level calls, and top-level local functions
    funcs=[]
    for n in ast.walk(st):
        if isinstance(n,(N.AnonymousFunction,)) : funcs.append(n)
    if isinstance(st,(N.LocalFunction,N.Function)): funcs.append(st)
    for f in funcs:
        used=names_in(f.body) & top
        report.append((len(used), getattr(f,'line',None) or '?', type(st).__name__))
    if isinstance(st,N.LocalAssign):
        for t in st.targets: top.add(t.id)
    if isinstance(st,N.LocalFunction): top.add(st.name.id)
report.sort(reverse=True)
for r in report[:5]: print(r)
