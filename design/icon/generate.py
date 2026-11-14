# Written by AI on 2026.11.14 by model claude opus 5.5. Generates the BuienWatch app icon (App/Rain/AppIcon.icon) and a rejected alternative.
# Two candidate BuienWatch icons as Icon Composer bundles, plus flat previews.
import json, math, os, sys
C=512
def arc_point(r, deg):
    a=math.radians(deg); return (C+r*math.cos(a), C+r*math.sin(a))
def swell(r0, start, end, peak, steps=120):
    # rain band rising outwards from the track: smooth bump (sin^2) with a second smaller swell
    out=[];inn=[]
    for i in range(steps+1):
        t=i/steps; d=start+(end-start)*t
        h=peak*(math.sin(math.pi*t)**2)*(0.75+0.25*math.cos(2*math.pi*t*1.0))
        out.append(arc_point(r0+h, d)); inn.append(arc_point(r0, d))
    pts=out+inn[::-1]
    return 'M'+' L'.join(f'{x:.1f},{y:.1f}' for x,y in pts)+' Z'
def svg(body): return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">{body}</svg>'
def bundle(name, layers):
    os.makedirs(f'{name}.icon/Assets', exist_ok=True)
    groups=[]
    for gname, specular, items in layers:
        ls=[]
        for lname, body, opacity in items:
            open(f'{name}.icon/Assets/{lname}.svg','w').write(svg(body))
            ls.append({"image-name": f"{lname}.svg", "name": lname, "opacity": opacity})
        groups.append({"name": gname, "specular": specular, "layers": ls})
    fill={"linear-gradient":["extended-srgb:0.42353,0.68235,0.88235,1.00000","extended-srgb:0.13725,0.36078,0.61961,1.00000"],
          "orientation":{"start":{"x":0.5,"y":0.0},"stop":{"x":0.5,"y":1.0}}}
    json.dump({"fill":fill,"groups":groups,"supported-platforms":{"circles":["watchOS"]}}, open(f'{name}.icon/icon.json','w'), indent=2)
    # flat preview: gradient circle + layers
    body=('<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#6CAEE1"/><stop offset="1" stop-color="#235C9E"/></linearGradient>'
          '<clipPath id="c"><circle cx="512" cy="512" r="512"/></clipPath></defs><g clip-path="url(#c)"><rect width="1024" height="1024" fill="url(#g)"/>')
    for _,_,items in layers:
        for lname, b, opacity in items: body+=f'<g opacity="{opacity}">{b}</g>'
    open(f'{name}-preview.svg','w').write(svg(body+'</g>'))

# A: gauge, as on the face
r=300; start,end=150,390
track=f'<path d="M{arc_point(r,start)[0]:.1f},{arc_point(r,start)[1]:.1f} A{r},{r} 0 1 1 {arc_point(r,end)[0]:.1f},{arc_point(r,end)[1]:.1f}" fill="none" stroke="#FFFFFF" stroke-width="44" stroke-linecap="round"/>'
dot_deg=196
rain=f'<path d="{swell(r-22, dot_deg+16, 318, 150)}" fill="#FFFFFF"/>'
dx,dy=arc_point(r,dot_deg)
dot=f'<circle cx="{dx:.1f}" cy="{dy:.1f}" r="34" fill="#FFFFFF"/>'
# keep the track clear round the dot
track_cut=f'<mask id="m"><rect width="1024" height="1024" fill="white"/><circle cx="{dx:.1f}" cy="{dy:.1f}" r="62" fill="black"/></mask><g mask="url(#m)">{track}</g>'
bundle('gauge', [("Track", False, [("track", track_cut, 0.45)]), ("Rain", True, [("rain", rain, 1.0), ("dot", dot, 1.0)])])

# B: the line over a baseline, as in the slot and the app
x0,x1,base=150,874,690
def curve(t):  # a shower: quick rise, a peak, a smaller second swell, fall
    return 400*math.exp(-((t-0.37)/0.14)**2)+190*math.exp(-((t-0.68)/0.10)**2)
pts=[(x0+ (x1-x0)*i/200, base-curve(i/200)) for i in range(201)]
pts=[p for p in pts if base-p[1]>2]
edge='M'+' L'.join(f'{x:.1f},{y:.1f}' for x,y in pts)
area=edge+f' L{pts[-1][0]:.1f},{base} L{pts[0][0]:.1f},{base} Z'
baseline=f'<path d="M{x0},{base} L{x1},{base}" stroke="#FFFFFF" stroke-width="44" stroke-linecap="round"/>'
dotB=f'<circle cx="{pts[0][0]-52:.1f}" cy="{base}" r="52" fill="#FFFFFF"/>'
cutB=f'<mask id="m"><rect width="1024" height="1024" fill="white"/><circle cx="{pts[0][0]-52:.1f}" cy="{base}" r="88" fill="black"/></mask><g mask="url(#m)">{baseline}</g>'
bundle('line', [("Base", False, [("baseline", cutB, 0.6)]), ("Rain", True, [("fill", f'<path d="{area}" fill="#FFFFFF"/>', 0.7), ("edge", f'<path d="{edge}" fill="none" stroke="#FFFFFF" stroke-width="48" stroke-linecap="round" stroke-linejoin="round"/>', 1.0), ("dot", dotB, 1.0)])])
