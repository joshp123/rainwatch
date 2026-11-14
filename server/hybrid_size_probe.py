# Usage: python3 server/hybrid_size_probe.py plain.h5 matching-blend.nc
# Sizing only: excludes observations and transport headers; not a production decoder.
# Written by AI on 2026.11.14 by model gpt-6-astra. Design experiment, no service.
import h5py,numpy as np,zlib,math,time,json,sys
from pyproj import Proj
start=time.perf_counter()
f=h5py.File(sys.argv[1]); b=h5py.File(sys.argv[2]); p=Proj(f['geographic/map_projection'].attrs['projection_proj4_params'].decode())
raw=np.stack([f[f'image{i}/image_data'][()] for i in range(1,26)])
a=raw.astype('float32')*.12;a[raw>=65534]=np.nan
h,w=raw.shape[1:];xx,yy=np.meshgrid(np.arange(w)+.5,-(np.arange(h)+.5+3650)); lon,lat=p(xx,yy,inverse=True)
blat=b['lat'][:];blon=b['lon'][:]
def near(axis, vals):
 if axis[0]>axis[-1]:return len(axis)-1-near(axis[::-1],vals)
 idx=np.clip(np.searchsorted(axis,vals),1,len(axis)-1)
 return np.where(abs(vals-axis[idx-1])<=abs(vals-axis[idx]),idx-1,idx)
bi=near(blat,lat);bj=near(blon,lon)
inside=(lat>=min(blat))&(lat<=max(blat))&(lon>=min(blon))&(lon<=max(blon))
times=list(b['time'][:]); wet=np.zeros(a.shape,dtype=np.uint8); diffs=0
for step in range(7,25):
 raw_m=b['precip_intensity'][:,times.index(step*300),:,:]
 m=raw_m.astype('float32')*float(b['precip_intensity'].attrs['scale_factor'][0]);m[raw_m==65535]=np.nan
 med=np.median(m,axis=0)[bi,bj]; count=(m>=.1).sum(axis=0)[bi,bj]; med[~inside]=np.nan
 a[step]=med; wet[step]=count; diffs+=int(np.count_nonzero(inside&((count>=10)!=(med>=.1))))
# 0.01mm/h numeric precision, missing reserved65535; separate count per cell/time.
encoded=np.where(np.isfinite(a),np.clip(np.rint(a*100),0,65534),65535).astype('<u2')
for side in (16,32,64):
 sizes={};count=0
 for r in range(0,h,side):
  for c in range(0,w,side):
   tile=encoded[:,r:r+side,c:c+side];prob=wet[:,r:r+side,c:c+side]
   sizes[(r//side,c//side)]=len(zlib.compress(tile.tobytes()+prob.tobytes()));count+=1
 out={'tile':side,'nationwide_bytes':sum(sizes.values()),'tile_max':max(sizes.values()),'rotterdam_point_bytes':sizes[(452//side,321//side)]}
 for width in (30,120):
  keys=[(r,c) for r in range((452-width//2)//side,(452+width//2-1)//side+1) for c in range((321-width//2)//side,(321+width//2-1)//side+1)]
  out[str(width)+'km']={'requests':len(keys),'bytes':sum(sizes[k] for k in keys)}
 print(json.dumps(out))
print(json.dumps({'time_s':time.perf_counter()-start,'half_vote_median_disagreements':diffs}))
