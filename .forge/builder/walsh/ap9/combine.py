import json, itertools, sys
caps=json.load(open(sys.argv[1]))
W=list(caps)
sols=[]
for c in range(0,10):
    need=(14-c,2,14,2*c)
    for combo in itertools.product(*[caps[w] for w in W]):
        tot=[sum(v[i] for v in combo) for i in range(4)]
        if all(t>=n for t,n in zip(tot,need)):
            sols.append((c,dict(zip(W,[tuple(v) for v in combo])),tot))
print('solutions',len(sols))
by_c={}
for c,d,t in sols: by_c.setdefault(c,[]).append((d,t))
for c in sorted(by_c):
    print('cut sheets',c,'->',len(by_c[c]),'wall combos; e.g.')
    for d,t in by_c[c][:6]: print('   ',d,'tot',t)
