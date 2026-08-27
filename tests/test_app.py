from app import create_app
def client(): return create_app({"TESTING":True}).test_client()
def test_health():
 r=client().get("/health"); assert r.status_code==200 and r.get_json()=={"status":"ok"}
def test_read_only_apis():
 for p in ("/api/status","/api/resources","/api/findings","/api/costs"): assert client().get(p).status_code==200
 assert client().get("/api/status").get_json()["connected_to_aws"] is False
 assert client().post("/api/resources").status_code==405
def test_headers():
 r=client().get("/"); assert r.headers["X-Frame-Options"]=="DENY"
