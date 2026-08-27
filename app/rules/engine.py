def make(rule,severity,r,title,observed,threshold,reason,saving,recommendation): return {"rule_id":rule,"severity":severity,"resource_id":r["id"],"resource_name":r["name"],"title":title,"observed":observed,"threshold":threshold,"reason":reason,"saving":round(saving,2),"recommendation":recommendation}
def analyse(resources,costs):
 out=[]
 for r in resources:
  if r["service"]=="EC2" and r["state"]=="running":
   cpu,h=r.get("cpu_avg",100),r.get("observation_hours",0)
   if cpu<5 and h>=72: out.append(make("possible_underutilised_instance","warning",r,"Possible underutilised instance",[f"Average CPU: {cpu:.1f}%",f"Observation period: {h} hours"],"Average CPU below 5% for at least 72 hours.","Sustained utilisation is below the demo threshold.",r["monthly_cost"]*.5,f"{r['name']} has averaged {cpu:.1f}% CPU for {h} hours. Review whether it needs to run continuously."))
   if r["type"] in {"m5.large","m5.xlarge","t3.xlarge"} and cpu<15 and r.get("memory_avg",100)<25 and h>=168: out.append(make("potentially_oversized_instance","medium",r,"Potentially oversized EC2 instance",[f"Average CPU: {cpu:.1f}%",f"Average memory: {r['memory_avg']:.1f}%",f"Instance type: {r['type']}"],"CPU below 15% and memory below 25% for at least 168 hours.","Compute and memory use remain low.",r["monthly_cost"]-r["estimated_rightsized_cost"],f"Compare {r['name']} with a smaller instance class in a controlled test."))
  if r["service"]=="EBS" and r["state"]=="available" and not r.get("attachment"): out.append(make("unattached_ebs_volume","high",r,"Unattached EBS volume",["Volume state: available","Attachment: none",f"Monthly cost: £{r['monthly_cost']:.2f}"],"State is available and no attachment is present.","The volume is billed but unattached.",r["monthly_cost"],f"Confirm whether {r['name']} is needed, snapshot it if appropriate, then consider deletion."))
 base=costs["baseline"]["average"]; pct=(costs["monthly_spend"]-base)/base*100
 if pct>costs["baseline"]["spike_threshold_percent"]:
  r={"id":"environment","name":"Kairo Labs (Demo)"}; out.append(make("cost_spike_detected","high",r,"Cost spike detected",[f"Current spend: £{costs['monthly_spend']:.2f}",f"Historical baseline: £{base:.2f}",f"Increase: {pct:.1f}%"],f"Spend exceeds baseline by more than {costs['baseline']['spike_threshold_percent']}%.","Current demo spend is materially above its synthetic baseline.",costs["monthly_spend"]-base,"Review EC2 growth and recent simulated resource changes."))
 return out
