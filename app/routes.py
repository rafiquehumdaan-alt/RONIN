from flask import Blueprint,jsonify,render_template
from .data.demo import ENV,RESOURCES,COSTS
from .rules.engine import analyse
api=Blueprint("api",__name__)
def findings(): return analyse(RESOURCES,COSTS)
@api.get("/")
def index(): return render_template("index.html",env=ENV,resources=RESOURCES,costs=COSTS,findings=findings())
@api.get("/health")
def health(): return jsonify(status="ok")
@api.get("/api/status")
def status(): return jsonify(environment=ENV,resource_count=len(RESOURCES),finding_count=len(findings()),connected_to_aws=False)
@api.get("/api/resources")
def resources(): return jsonify(demo=True,resources=RESOURCES)
@api.get("/api/findings")
def fs(): return jsonify(demo=True,engine="deterministic-demo-rules-v1",production_grade=False,findings=findings())
@api.get("/api/costs")
def costs(): return jsonify(COSTS)
