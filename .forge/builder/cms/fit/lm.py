import numpy as np
def lm(fun, p0, iters=200, lam=1e-3, eps=1e-6, fixed=()):
    p=np.array(p0,float); free=[i for i in range(len(p)) if i not in fixed]
    r=fun(p); cost=r@r
    for it in range(iters):
        J=np.zeros((len(r),len(free)))
        for j,i in enumerate(free):
            dp=np.zeros_like(p); h=eps*max(1.0,abs(p[i])); dp[i]=h
            J[:,j]=(fun(p+dp)-r)/h
        A=J.T@J; g=J.T@r
        while True:
            step=np.linalg.solve(A+lam*np.diag(np.diag(A)+1e-12),-g)
            pn=p.copy(); pn[free]+=step; rn=fun(pn); cn=rn@rn
            if cn<cost:
                p,r,cost=pn,rn,cn; lam=max(lam/3,1e-9); break
            lam*=4
            if lam>1e9: return p,r,J
        if np.abs(step).max()<1e-9: break
    return p,r,J
def line_resid(pts, a, b):
    """perpendicular pixel distance of pts to the image line through a,b"""
    d=b-a; n=np.array([-d[1],d[0]])/np.linalg.norm(d)
    return (np.asarray(pts)-a)@n
