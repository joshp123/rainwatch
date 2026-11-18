"""Ink boxes of the words: pixels that differ between a capture and its text-free twin."""
import sys
from PIL import Image, ImageChops
def boxes(a_path, b_path, thresh=40, gap=14):
    a=Image.open(a_path).convert('RGB'); b=Image.open(b_path).convert('RGB')
    d=ImageChops.difference(a,b).convert('L').point(lambda v:255 if v>thresh else 0)
    W,H=d.size; px=d.load()
    rows=[any(px[x,y] for x in range(W)) for y in range(H)]
    out=[]; y=0
    while y<H:
        if not rows[y]: y+=1; continue
        y0=y
        while y<H and rows[y]: y+=1
        y1=y-1
        cols=[any(px[x,yy] for yy in range(y0,y1+1)) for x in range(W)]
        x=0
        while x<W:
            if not cols[x]: x+=1; continue
            x0=x; last=x
            while x<W and (cols[x] or x-last<gap):
                if cols[x]: last=x
                x+=1
            out.append((x0,y0,last,y1))
    return out
if __name__=='__main__':
    for b in boxes(sys.argv[1],sys.argv[2]): print(b, 'w',b[2]-b[0]+1,'h',b[3]-b[1]+1)
