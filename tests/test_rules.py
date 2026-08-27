from app.rules.engine import analyse
def costs(now=100,base=100): return {"monthly_spend":now,"baseline":{"average":base,"spike_threshold_percent":20}}
def test_rules():
 r={"id":"i","service":"EC2","name":"demo","type":"t3.small","state":"running","cpu_avg":4.9,"memory_avg":50,"observation_hours":72,"monthly_cost":20,"estimated_rightsized_cost":10}
 assert analyse([r],costs())[0]["rule_id"]=="possible_underutilised_instance"
 assert analyse([{**r,"cpu_avg":5}],costs())==[] and analyse([{**r,"observation_hours":71}],costs())==[]
 v={"id":"v","service":"EBS","name":"orphan","type":"gp3","state":"available","attachment":None,"monthly_cost":8}
 assert analyse([v],costs())[0]["rule_id"]=="unattached_ebs_volume"
 assert analyse([],costs(121))[0]["rule_id"]=="cost_spike_detected" and analyse([],costs(120))==[]
