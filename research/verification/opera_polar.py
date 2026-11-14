#!/usr/bin/env python3
# Written by AI on 2026.11.14 by model gpt-6 astra
"""Trace Dutch echoes into OPERA: python opera_polar.py WORKDIR OUT.json.
Use opera_cause.py's cached 13 November 18:00 composites and KNMI file first.
Downloads two 17:55 Dutch volumes anonymously, once. Needs numpy, h5py, pyproj, scipy.
Polar matching uses geodesic azimuth/range and nearest ray; high sweeps (>3 degrees)
are excluded to avoid a planar slant-range approximation at high elevation.
"""
import sys,json,urllib.request,xml.etree.ElementTree as ET
from pathlib import Path
import h5py,numpy as np
from pyproj import Proj,Geod
from scipy.spatial import cKDTree
w=Path(sys.argv[1]);base='https://object-store.os-api.cci1.ecmwf.int/openradar-24h-backup';ns={'s':'http://s3.amazonaws.com/doc/2006-03-01/'}
def cached(name,subdir):
 p=w/subdir/name
 return p if p.exists() else w/name
wet_dbz=10*np.log10(200*.1**1.6)
with h5py.File(cached('RAD_NL25_RAC_RT_202611131800.h5','knmi')) as f:
 p=Proj(f['geographic/map_projection'].attrs['projection_proj4_params'].decode());r,c=np.indices((765,700));lon,lat=p(c+.5,-r-.5-3650,inverse=True);K=f['image1/image_data'][()]*.12;K[K>=65534*.12]=np.nan
with h5py.File(cached('202611131800_DBZH.h5','opera')) as f:
 a=f['where'].attrs;p=Proj(a['projdef'].decode());x,y=p(lon,lat);r=np.floor(-y/1000).astype(int);c=np.floor(x/1000).astype(int);O=f['dataset1/data1/data'][()][r,c]
result={};geod=Geod(ellps='WGS84')
for product in ('RATE','DBZH'):
 with h5py.File(cached(f'202611131800_{product}.h5','opera')) as f:
  metadata={key:{k:str(v) for k,v in f[key].attrs.items()} for key in ['how','where','dataset1/what','dataset1/data1/what','dataset1/data1/quality1/how']}
  p=Proj(f['where'].attrs['projdef'].decode());x,y=p(4.3419,51.4478);scale=f['where'].attrs['xscale'];rr,cc=int(-y/scale),int(x/scale)
  metadata['Woensdrecht']={'stored_value':float(f['dataset1/data1/data'][rr,cc]),'quality':float(f['dataset1/data1/quality1/data'][rr,cc])}
  result[product+'_metadata']=metadata
for node in ('nldhl','nlhrw'):
 path=w/(node+'.h5')
 if not path.exists():
  root=ET.fromstring(urllib.request.urlopen(base+f'?list-type=2&prefix=2026/11/13/NL/{node}/PVOL/{node}@20261113T1755').read());key=root.find('s:Contents/s:Key',ns).text;urllib.request.urlretrieve(base+'/'+key,path)
 with h5py.File(path) as f:
  a=f['where'].attrs;az,_,dist=geod.inv(np.full(lon.shape,a['lon']),np.full(lat.shape,a['lat']),lon,lat);az=az%360
  sel=(dist<100000)&(K>=.1);out=[];maxv=np.full(K.shape,-np.inf)
  for d in sorted([k for k in f if k.startswith('dataset')],key=lambda x:int(x[7:])):
   a=f[d+'/where'].attrs;elev=a['elangle']
   if elev>3:continue
   h=f[d+'/how'].attrs
   # circular mean handles wrap at north
   angles=np.angle(np.exp(1j*np.deg2rad(h['startazA']))+np.exp(1j*np.deg2rad(h['stopazA'])),deg=True)%360
   tree=cKDTree(np.c_[np.cos(np.deg2rad(angles)),np.sin(np.deg2rad(angles))]);_,ray=tree.query(np.c_[np.cos(np.deg2rad(az.ravel())),np.sin(np.deg2rad(az.ravel()))]);ray=ray.reshape(K.shape)
   gate=np.floor((dist/np.cos(np.deg2rad(elev))-a['rstart']*1000)/a['rscale']).astype(int);ok=(gate>=0)&(gate<a['nbins']);gate=gate.clip(0,a['nbins']-1)
   for k in f[d]:
    if not k.startswith('data'):continue
    q=f[d+'/'+k+'/what'].attrs
    if q['quantity']!=b'DBZH':continue
    raw=f[d+'/'+k+'/data'][()][ray,gate];v=raw*q['gain']+q['offset'];v[(raw==q['nodata'])|(raw==q['undetect'])|~ok]=-np.inf;maxv=np.maximum(maxv,v)
    out.append({'scan':d,'elevation':float(elev),'knmi_wet':int(sel.sum()),'input_wet_on_knmi_wet':int((sel&(v>=wet_dbz)).sum()),'input_wet_but_opera_dry':int((sel&(v>=wet_dbz)&(O<wet_dbz)).sum())})
  result[node]={'scans':out,'max_low_sweeps_hits':int((sel&(maxv>=wet_dbz)).sum()),'opera_hits':int((sel&(O>=wet_dbz)).sum()),'input_ge20_opera_dry':int((sel&(maxv>=20)&(O<wet_dbz)).sum())}
Path(sys.argv[2]).write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
