import sys,time,resource,numpy as np,h5py,cv2
from scipy.ndimage import map_coordinates
f=h5py.File(sys.argv[1])
def w(n,o):
    if isinstance(o,h5py.Dataset): print(n,o.shape,o.dtype)
f.visititems(w)
print({k:(v.decode() if isinstance(v,bytes) else v) for k,v in f['where'].attrs.items()})
print({k:(v.decode() if isinstance(v,bytes) else v) for k,v in f['dataset1/data1/what'].attrs.items()})
d=f['dataset1/data1/data'][()].astype(np.float32)
nod=d<=-9000000+1e6*0 if False else (d==-9999000); und=(d==-8888000)
print('shape',d.shape,'nodata share',nod.mean().round(3),'undetect share',und.mean().round(3),'echo share',(~nod&~und).mean().round(4))
z=np.where(nod|und,-32,d); 
for scale in (1,2):
    a=z[::scale,::scale]; b=np.roll(a,(3,5),(0,1))   # stand-in for the previous frame
    t=time.perf_counter()
    n8=lambda x:np.clip((x+32)*255/92,0,255).astype(np.uint8)
    flow=cv2.calcOpticalFlowFarneback(n8(b),n8(a),None,0.5,4,25,3,5,1.1,0)
    t1=time.perf_counter()
    yy,xx=np.meshgrid(np.arange(a.shape[0],dtype=np.float32),np.arange(a.shape[1],dtype=np.float32),indexing='ij')
    out=[]
    for k in range(1,25):
        out.append(map_coordinates(a,[yy-k*flow[...,1],xx-k*flow[...,0]],order=1,mode='constant',cval=-32))
    t2=time.perf_counter()
    print(f'grid {a.shape} ({scale} km): motion field {t1-t:.1f} s, 24 steps moved forward {t2-t1:.1f} s, total {t2-t:.1f} s, peak memory {resource.getrusage(resource.RUSAGE_SELF).ru_maxrss/2**30:.2f} GB')
