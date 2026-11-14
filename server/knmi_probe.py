# Written by AI on 2026.11.14 by model claude opus 5.5. Prototype: reads a KNMI radar_forecast 2.0 file, prints the
# five-minute rain series (mm/h) at a few places and the size of a 100 km tile in 4-bit steps.
# Run: nix shell --impure --expr 'with import (builtins.getFlake "nixpkgs") {}; python3.withPackages (p: [ p.h5py p.numpy p.pyproj ])' -c python3 -I knmi_probe.py <file.h5>
import h5py, numpy as np, json, zlib, time, sys
from pyproj import Proj
t0=time.time()
f=h5py.File(sys.argv[1])
proj4=f['geographic/map_projection'].attrs['projection_proj4_params'].decode()
cal=f['image1/calibration']
print('proj4:',proj4)
print('calibration:',{k:(v.decode() if isinstance(v,bytes) else v.tolist() if hasattr(v,'tolist') else v) for k,v in cal.attrs.items()})
p=Proj(proj4)
g=f['geographic'].attrs
col_off=float(g['geo_column_offset'][0]); row_off=float(g['geo_row_offset'][0])
def cell(lat,lon):
    x,y=p(lon,lat)   # metres
    xk,yk=x,y   # the projection is already in km
    col=int(round(xk-col_off)); row=int(round(-yk-row_off))  # rows run south from y = -3650 km
    return row,col
frames=[]
for i in range(1,26):
    d=f[f'image{i}/image_data'][()].astype(np.float32)
    d[d>=65534]=np.nan
    frames.append(d*0.01*12)   # mm per 5 min -> mm/h
grid=np.stack(frames)
print('grid',grid.shape,'max mm/h anywhere over 2h:',np.nanmax(grid).round(2),'cells with rain now:',int(np.nansum(grid[0]>0)))
for name,(lat,lon) in {'Rotterdam':(51.92,4.48),'Amsterdam':(52.37,4.90),'Groningen':(53.22,6.57),'Maastricht':(50.85,5.69),'Brussels':(50.85,4.35)}.items():
    r,c=cell(lat,lon)
    print(name,(r,c),'series mm/h:',np.round(grid[:,r,c],2).tolist()[:8],'...')
r,c=cell(51.92,4.48)
tile=grid[:,max(0,r-50):r+50,max(0,c-50):c+50]
q=np.nan_to_num(np.clip(np.round(np.log2(tile+1)*4),0,15)).astype(np.uint8)  # 4-bit log scale
packed=(q[...,0::2]<<4)|q[...,1::2]
z=zlib.compress(packed.tobytes(),9)
print('tile',tile.shape,'raw 4-bit bytes',packed.nbytes,'zlib',len(z),'time %.2fs'%(time.time()-t0))
