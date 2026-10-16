import sys
import numpy as np
from PIL import Image
S=1024; K=3; N=S*K
y,x=np.mgrid[0:N,0:N].astype(np.float32)/K
t=(y/S)[...,None]
img=(np.array([251,246,236])*(1-t)+np.array([240,231,214])*t)/255.0
def blob(cx,cy,r,seed):
    ang=np.arctan2(y-cy,x-cx); d=np.hypot(x-cx,y-cy)
    rr=r*(1+0.04*np.sin(3*ang+seed)+0.02*np.sin(5*ang+2*seed))
    return np.clip(rr-d+0.5,0,1)
r=235; c=(512,540); off=150
import math
pos=[(c[0]+off*math.cos(a),c[1]+off*math.sin(a)) for a in (math.radians(-90),math.radians(150),math.radians(30))]
R,Y,B=[blob(px,py,r,i*2.1) for i,(px,py) in enumerate(pos)]
col=lambda h: np.array([int(h[i:i+2],16)/255 for i in (0,2,4)],np.float32)
red,yel,blu=col('D7261E'),col('F6C21C'),col('1E3FA8')
org,grn,vio,brn=col('EC6A1A'),col('2E7D3A'),col('5A2A6E'),col('3B2A22')
regions=[(R*(1-Y)*(1-B),red),(Y*(1-R)*(1-B),yel),(B*(1-R)*(1-Y),blu),
         (R*Y*(1-B),org),(Y*B*(1-R),grn),(R*B*(1-Y),vio),(R*Y*B,brn)]
cover=np.clip(R+Y+B,0,1)  # approx; use union
union=1-(1-R)*(1-Y)*(1-B)
paint=sum(m[...,None]*c for m,c in regions)
w=sum(m for m,_ in regions)[...,None]
paint=paint/np.maximum(w,1e-6)
img=img*(1-union[...,None])+paint*union[...,None]
Image.fromarray((img.clip(0,1)*255+0.5).astype(np.uint8)).resize((S,S),Image.LANCZOS).save(sys.argv[1])
