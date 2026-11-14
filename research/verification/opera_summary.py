#!/usr/bin/env python3
# Written by AI on 2026.11.14 by model gpt-6 astra
"""Print pooled counts from opera_cause.py's JSON: python opera_summary.py RESULT.json."""
import json,math,sys
r=json.load(open(sys.argv[1]));out={'dwd':{},'surface':{}}
for product in ('RATE','DBZH'):
 for threshold in ('0.1','1','5','block'):
  rows=[x[product][threshold] for x in r['dwd'] if x[product].get(threshold)]
  if not rows:continue
  h,m,f=(sum(x[key] for x in rows) for key in ('hits','misses','false_alarms'))
  out['dwd'][product+' '+threshold]={'hits':h,'misses':m,'false_alarms':f,'pod':h/(h+m),'csi':h/(h+m+f),'false_alarm_ratio':f/(h+f)}
for ref in ('gauge','weather_sensor'):
 for product in ('KNMI','RATE','DBZH','RATE_near','DBZH_near'):
  rows=[x for x in r['gauges'] if math.isfinite(x[ref]) and math.isfinite(x[product])]
  h=sum(x[ref]>=.1 and x[product]>=.1 for x in rows);m=sum(x[ref]>=.1 and x[product]<.1 for x in rows);f=sum(x[ref]<.1 and x[product]>=.1 for x in rows)
  out['surface'][ref+' '+product]={'n':len(rows),'hits':h,'misses':m,'false_alarms':f}
print(json.dumps(out,indent=2))
