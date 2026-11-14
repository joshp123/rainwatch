#!/usr/bin/env python3
# Written by AI on 2026.11.14 by model gpt-6 astra
"""Independent DWD and surface-station checks. python opera_cause.py WORKDIR OUT.json
Needs numpy, h5py, pyproj, xarray, netcdf4; KNMI_API_KEY in environment.
Caches every download. Fewer than 150 KNMI requests per complete run; stops on 429.
The fixed historical dates require an archive after rolling stores expire.
"""
import datetime as dt, io, json, os, sys, tarfile, urllib.request
from pathlib import Path
import h5py, numpy as np, xarray as xr
from pyproj import Proj
import opera_check as old
W=Path(sys.argv[1]); W.mkdir(exist_ok=True,parents=True)
manifest=[]
def get(url,name,auth=False):
 p=W/name
 if not p.exists():
  req=urllib.request.Request(url,headers={'User-Agent':'RainWatch radar research',**({'Authorization':os.environ['KNMI_API_KEY']} if auth else {})})
  with urllib.request.urlopen(req,timeout=90) as r: p.write_bytes(r.read())
 manifest.append({'url':url if not auth else url.split('?')[0],'file':name})
 return p

def knmi(dataset,name):
 p=W/name
 if p.exists(): return p
 base=f'https://api.dataplatform.knmi.nl/open-data/v1/datasets/{dataset}/versions/1.0/files/{name}/url'
 req=urllib.request.Request(base,headers={'Authorization':os.environ['KNMI_API_KEY'],'User-Agent':'RainWatch radar research'})
 with urllib.request.urlopen(req,timeout=60) as r: u=json.load(r)['temporaryDownloadUrl']
 # Do not retain signed download URLs.
 with urllib.request.urlopen(u,timeout=90) as r: p.write_bytes(r.read())
 manifest.append({'dataset':dataset,'file':name})
 return p

def odim(f):
 a=f['dataset1/data1/what'].attrs; raw=f['dataset1/data1/data'][()]
 v=raw.astype(float)*a['gain']+a['offset'];v[raw==a['undetect']]=0;v[raw==a['nodata']]=np.nan
 if a['quantity']==b'DBZH':
  v=(10**(v/10)/200)**(1/1.6);v[raw==a['undetect']]=0
 if a['quantity']==b'ACRR':v*=12
 return v

def mapping(f,lon,lat):
 a=f['where'].attrs;p=Proj(a['projdef'].decode());x,y=p(lon,lat);ulx,uly=p(a['UL_lon'],a['UL_lat'])
 # Corner round-off must not move boundary samples into adjacent cells.
 c=np.floor((x-ulx)/a['xscale']+1e-7).astype(int);r=np.floor((uly-y)/a['yscale']+1e-7).astype(int)
 return r,c

def sample(f,lon,lat):
 v=odim(f);r,c=mapping(f,lon,lat);ok=(r>=0)&(c>=0)&(r<v.shape[0])&(c<v.shape[1]);out=np.full(lon.shape,np.nan);out[ok]=v[r[ok],c[ok]];return out

def score(a,b,threshold=.1):
 ok=np.isfinite(a)&np.isfinite(b);a=a[ok];b=b[ok];aw=a>=threshold;bw=b>=threshold
 h=int((aw&bw).sum());m=int((aw&~bw).sum());fa=int((~aw&bw).sum())
 return dict(n=len(a),hits=h,misses=m,false_alarms=fa,pod=h/(h+m) if h+m else None,csi=h/(h+m+fa) if h+m+fa else None,volume_ratio=float(b.sum()/a.sum()) if a.sum() else None,reference_max=float(a.max()) if len(a) else None)

def op(t,p):
 name=f'{t:%Y%m%d%H%M}_{p}.h5'
 # Reuse inspection files.
 if (W/'opera'/name).exists():return W/'opera'/name
 return get(old.opera_url(t,p),name)

out={'dwd':[],'gauges':[],'metadata':{},'knmi_adjustment':[]};start=dt.datetime(2026,11,13,tzinfo=dt.timezone.utc)
# Broad weather/time sample, selected before seeing the DWD rain field.
for hour in range(0,43,3):
 t=start+dt.timedelta(hours=hour);name=f'composite_rv_{t:%Y%m%d_%H%M}.tar'
 path=W/'rv.tar' if hour==18 and (W/'rv.tar').exists() else get('https://opendata.dwd.de/weather/radar/composite/rv/'+name,name)
 with tarfile.open(path) as tar:
  member=next(n for n in tar.getnames() if '_000-hd5' in n)
  with h5py.File(io.BytesIO(tar.extractfile(member).read())) as f:
   D=odim(f);a=f['where'].attrs;p=Proj(a['projdef'].decode());ux,uy=p(a['UL_lon'],a['UL_lat']);r,c=np.indices(D.shape);lon,lat=p(ux+(c+.5)*a['xscale'],uy-(r+.5)*a['yscale'],inverse=True)
   out['metadata']['dwd']={k:str(v) for k,v in f['dataset1/data1/what'].attrs.items()}
   # Entirely inland Germany, well outside the Dutch reference's useful area.
   region=(lon>=9)&(lon<=13)&(lat>=51)&(lat<=54)
   rec={'time':t.isoformat(),'region':'9–13 E, 51–54 N'}
   for product in ('RATE','DBZH'):
    with h5py.File(op(t,product)) as o:
     P=sample(o,lon,lat)
     rec[product]={str(th):score(D[region],P[region],th) for th in (.1,1,5)}
     # 2 km averaging on the OPERA grid, avoiding a resolution advantage.
     rr,cc=mapping(o,lon,lat);ids=rr*int(o['where'].attrs['xsize'])+cc;v=region&np.isfinite(D);u,inv=np.unique(ids[v],return_inverse=True);cnt=np.bincount(inv);avg=np.bincount(inv,weights=D[v])/cnt;pv=odim(o).ravel()[u];rec[product]['block']=score(avg[cnt>=3],pv[cnt>=3]) if product=='RATE' else None
   out['dwd'].append(rec);print('DWD',rec,flush=True)
# Dutch rain: direct surface measurements, including offshore present-weather sensors.
for minutes in range(0,721,30):
 t=start+dt.timedelta(hours=18,minutes=minutes)
 g=xr.open_dataset(knmi('10-minute-in-situ-meteorological-observations',f'KMDS__OPER_P___10M_OBS_L2_{t:%Y%m%d%H%M}.nc'))
 lon=g.lon.values;lat=g.lat.values;keep=lat>49
 vals={}
 for product in ('RATE','DBZH'):
  with h5py.File(op(t,product)) as f:
   vals[product]=sample(f,lon,lat)
   v=odim(f);rr,cc=mapping(f,lon,lat);radius=int(5000/f['where'].attrs['xscale']);near=np.full(lon.shape,np.nan)
   for i in np.where(keep)[0]:
    tile=v[max(0,rr[i]-radius):rr[i]+radius+1,max(0,cc[i]-radius):cc[i]+radius+1]
    if tile.size and np.isfinite(tile).any():near[i]=np.nanmax(tile)
   vals[product+'_near']=near
 # Match gauge's ten-minute interval with both five-minute radar accumulations.
 ks=[]
 for offset in (0,-5):
  ktime=t+dt.timedelta(minutes=offset);name=f'RAD_NL25_RAC_RT_{ktime:%Y%m%d%H%M}.h5';path=W/'knmi'/name
  if not path.exists():path=knmi('nl_rdr_data_rtcor_5m',name)
  with h5py.File(path) as f:
   p=Proj(f['geographic/map_projection'].attrs['projection_proj4_params'].decode());x,y=p(lon,lat);r=np.floor(-y-3650).astype(int);c=np.floor(x).astype(int);ok=keep&(r>=0)&(r<765)&(c>=0)&(c<700);v=old.read_knmi(path);k=np.full(lon.shape,np.nan);k[ok]=v[r[ok],c[ok]];ks.append(k)
   adj=f['image3/image_data'][()];adj=adj[adj<254]*.16-20.24;out['knmi_adjustment'].append({'time':ktime.isoformat(),'db_min':float(adj.min()),'db_max':float(adj.max())})
 vals['KNMI']=(ks[0]+ks[1])/2
 for i in np.where(keep)[0]:
  out['gauges'].append({'time':t.isoformat(),'station':str(g.stationname.values[i]),'lon':float(lon[i]),'lat':float(lat[i]),'gauge':float(g.rg.values[i,0]),'weather_sensor':float(g.pg.values[i,0]),**{k:float(v[i]) for k,v in vals.items()}})
 g.close();print('gauges',t,flush=True)
out['manifest']=manifest
Path(sys.argv[2]).write_text(json.dumps(out,indent=2,allow_nan=True))
