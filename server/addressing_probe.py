# Usage: python3 server/addressing_probe.py plain.h5
# Written by AI on 2026.11.14 by model gpt-6-astra. Design experiment only.
import h5py,numpy as np,zlib,json,math,sys
from pyproj import Proj
f=h5py.File(sys.argv[1]); g=f['geographic'].attrs
p=Proj(f['geographic/map_projection'].attrs['projection_proj4_params'].decode())
a=np.stack([f[f'image{i}/image_data'][()] for i in range(1,26)])
# Preserve exact native 16-bit samples and missing/outside codes for this addressing experiment.
a=a.astype('<u2'); t,h,w=a.shape
point=a.transpose(1,2,0).copy().tobytes()
x,y=p(4.48,51.92); r=math.floor(-y-float(g['geo_row_offset'][0])); c=math.floor(x-float(g['geo_column_offset'][0]))
off=(r*w+c)*t*2
assert np.array_equal(np.frombuffer(point[off:off+50],dtype='<u2'),a[:,r,c])
print(json.dumps({'grid':[h,w],'Rotterdam_cell':[r,c],'point_range':[off,off+49],'raw_series_bytes':50,'native_codes':np.unique(a[:,r,c]).tolist()}))
# Fixed spatial tiles, compressed independently, concatenated with fixed-width offset/length index.
for side in (16,32,64):
 blobs=[]; index=[]; pos=0
 for rr in range(0,h,side):
  for cc in range(0,w,side):
   tile=np.full((25,side,side),65535,dtype='<u2'); sub=a[:,rr:rr+side,cc:cc+side];tile[:,:sub.shape[1],:sub.shape[2]]=sub
   blob=zlib.compress(tile.tobytes());index.append((pos,len(blob)));pos+=len(blob);blobs.append(blob)
 pack=b''.join(blobs); nx=math.ceil(w/side)
 for width in (30,120):
  r0=max(0,r-width//2);r1=min(h,r+width//2);c0=max(0,c-width//2);c1=min(w,c+width//2)
  n=0;bytes_=0
  for tr in range(r0//side,(r1-1)//side+1):
   for tc in range(c0//side,(c1-1)//side+1):
    k=tr*nx+tc;start,size=index[k];dec=np.frombuffer(zlib.decompress(pack[start:start+size]),dtype='<u2').reshape(25,side,side)
    rr=tr*side;cc=tc*side;sub=a[:,rr:rr+side,cc:cc+side]
    assert np.array_equal(dec[:,:sub.shape[1],:sub.shape[2]],sub)
    n+=1;bytes_+=size
  print(json.dumps({'side':side,'viewport':width,'tiles':n,'compressed_bytes':bytes_,'full_pack_bytes':len(pack),'index_bytes':len(index)*8,'objects_per_run_if_split':len(index)}))
