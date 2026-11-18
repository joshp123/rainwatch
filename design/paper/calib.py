"""Find the font, weight and size that reproduce a word in a capture: render candidates over the
text-free capture and compare pixels inside the word's box."""
import sys, json
from PIL import Image, ImageDraw, ImageFont, ImageChops, ImageStat
D='/Users/josh/Library/Fonts/'
TRAK={5.5:220,6:100,7:60,10:60,11:48,12:40,13:32,14:28,15:8,16:0,17:-8,18:-16,19:-24,20:0,25:-20,36.5:-40,44:-40,77:-50}
def trak(pt, rounded=False):
    ks=sorted(TRAK)
    if rounded and pt<20: return 0
    if pt<=ks[0]: return TRAK[ks[0]]
    for a,b in zip(ks,ks[1:]):
        if a<=pt<=b: return TRAK[a]+(TRAK[b]-TRAK[a])*(pt-a)/(b-a)
    return TRAK[ks[-1]]
def render(bg, text, fontfile, px, colour, box, track_em):
    f=ImageFont.truetype(D+fontfile, size=round(px*4)/4) if False else ImageFont.truetype(D+fontfile, size=px)
    img=bg.copy(); d=ImageDraw.Draw(img)
    # ink box of the string at origin
    pos=[f.getlength(text[:i])+i*track_em*px for i in range(len(text))]
    tmp=Image.new('L',(int(pos[-1]+px*3),int(px*3)),0); td=ImageDraw.Draw(tmp)
    for c,x in zip(text,pos): td.text((x+px,px),c,font=f,fill=255)
    bb=tmp.getbbox()
    ox=box[0]-bb[0]; oy=box[1]-bb[1]
    for c,x in zip(text,pos): d.text((x+px+ox,px+oy),c,font=f,fill=colour)
    return img, (bb[2]-bb[0], bb[3]-bb[1]), (ox+px, oy+px)
def score(a,b,box):
    pad=4; r=(box[0]-pad,box[1]-pad,box[2]+pad+1,box[3]+pad+1)
    diff=ImageChops.difference(a.crop(r).convert('L'),b.crop(r).convert('L'))
    return ImageStat.Stat(diff).mean[0]
if __name__=='__main__':
    spec=json.loads(sys.argv[1])
    real=Image.open(spec['real']).convert('RGB'); bg=Image.open(spec['bg']).convert('RGB')
    box=spec['box']
    # text colour: brightest/most distinct pixel in box
    crop=real.crop((box[0],box[1],box[2]+1,box[3]+1)); bgc=bg.crop((box[0],box[1],box[2]+1,box[3]+1))
    colour=max(zip(crop.getdata(),bgc.getdata()), key=lambda p: sum(abs(x-y) for x,y in zip(*p)))[0]
    best=[]
    for fam in spec['fams']:
        rounded='Rounded' in fam
        for px in [x/4 for x in range(int(spec['lo']*4), int(spec['hi']*4)+1)]:
            t=trak(px/2, rounded)/2048
            img,ink,origin=render(bg,spec['text'],fam,px,colour,box,t)
            best.append((score(img,real,box),fam,px,round(t,4),ink,origin))
    best.sort()
    for b in best[:4]: print(b)
    print('measured ink', box[2]-box[0]+1, box[3]-box[1]+1, 'colour', colour)
