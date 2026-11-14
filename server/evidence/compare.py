import sys, numpy as np, h5py
from PIL import Image
br=Image.open(sys.argv[1]); pal=np.array(br.getpalette()).reshape(-1,3); idx=np.array(br)
rgba=np.array(br.convert('RGBA')); wet=rgba[...,3]>0
H,W=idx.shape
N,S,Wd,E=54.8,49.5,0.0,10.0
merc=lambda la: np.log(np.tan(np.pi/4+np.radians(la)/2))
# lat/lon of each BR pixel centre
px=(np.arange(W)+0.5)/W*(E-Wd)+Wd
my=merc(N)-(np.arange(H)+0.5)/H*(merc(N)-merc(S)); la=np.degrees(2*np.arctan(np.exp(my))-np.pi/2)
LON,LAT=np.meshgrid(px,la)
f=h5py.File(sys.argv[2]); d=f['image1/image_data'][()].astype(float); d[d>=65534]=np.nan; d*=0.12
# KNMI polar stereographic: +proj=stere +lat_0=90 +lon_0=0 +lat_ts=60 +a=6378.137 +b=6356.752 (km)
print(f['geographic/map_projection'].attrs['projection_proj4_params'])
a,b=6378.137,6356.752; e=np.sqrt(1-(b/a)**2)
def tfun(phi): return np.tan(np.pi/4-phi/2)/((1-e*np.sin(phi))/(1+e*np.sin(phi)))**(e/2)
phi=np.radians(LAT); lam=np.radians(LON); pts=np.radians(60)
mc=np.cos(pts)/np.sqrt(1-e**2*np.sin(pts)**2)
rho=a*mc*tfun(phi)/tfun(pts)
x=rho*np.sin(lam); y=-rho*np.cos(lam)
col=np.floor(x-0).astype(int); row=np.floor(-y-3650).astype(int)
ok=(row>=0)&(row<765)&(col>=0)&(col<700)
k=np.full(idx.shape,np.nan); k[ok]=d[row[ok],col[ok]]
kw=np.nan_to_num(k)>=0.1
print('Rotterdam check', np.floor(a*mc*tfun(np.radians(51.92))/tfun(pts)*np.sin(np.radians(4.48))), np.floor(a*mc*tfun(np.radians(51.92))/tfun(pts)*np.cos(np.radians(4.48))-3650))
print('BR wet px',wet.sum(),'KNMI>=0.1 px',kw.sum(),'agree',(wet==kw)[ok].mean())
# km per pixel
print('km/px EW at 52N', (E-Wd)*111.32*np.cos(np.radians(52))/W, 'NS', (N-S)*110.9/H)
# how many BR pixels share one KNMI cell: run lengths of identical values along rows inside rain
def runs(m):
    r=[]; 
    for rowv in m:
        ch=np.flatnonzero(np.diff(rowv)!=0); r+=list(np.diff(ch))
    return np.array(r)
# crop around biggest rain area
ys,xs=np.nonzero(wet&ok); cy,cx=int(np.median(ys)),int(np.median(xs))
sl=(slice(cy-60,cy+60),slice(cx-60,cx+60))
print('crop centre lat/lon',LAT[cy,cx],LON[cy,cx])
# intensity class image for BR: map palette index to rank by first appearance of darkness
bri=idx[sl]; 
def up(a,s=6): return a.repeat(s,0).repeat(s,1)
Image.fromarray(np.ascontiguousarray(up(np.where(rgba[sl][...,3:]>0,rgba[sl][...,:3],0)))).save(sys.argv[3]+'/br.png')
kk=np.nan_to_num(k[sl]); g=(np.clip(np.log10(np.maximum(kk,0.05)/0.05)/np.log10(100/0.05),0,1)*255).astype(np.uint8)
Image.fromarray(up(g)).save(sys.argv[3]+'/knmi.png')
# spectral test: fraction of variance removed by 2x2 block-averaging (i.e. content finer than 1.3 km)
def fine(z):
    z=z[:z.shape[0]//2*2,:z.shape[1]//2*2].astype(float); c=z.reshape(z.shape[0]//2,2,z.shape[1]//2,2).mean((1,3)); return ((z-np.kron(c,np.ones((2,2))))**2).mean()/z.var()
lum=rgba[...,3].astype(float)*(255-rgba[...,:3].mean(-1))/255
print('share of variance finer than 2 px: BR', round(fine(lum[sl]),4),' KNMI nearest-resampled to same grid', round(fine(kk),4))
from scipy import ndimage
sm=ndimage.zoom(np.nan_to_num(d),1/0.65,order=1)
print('KNMI bilinear to 0.65 km', round(fine(sm[300:420,300:420]),4))
