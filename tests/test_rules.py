# Tests RONIN's rules engine to ensure infrastructure and cost data produce the expected findings, helping prevent broken analysis logic from reaching deployment.

from app.rules.engine import analyse


def costs(now=100, base=100):
    return {
        "monthly_spend": now,
        "baseline": {
            "average": base,
            "spike_threshold_percent": 20,
        },
    }


def test_rules():
    resource = {
        "id": "i",
        "service": "EC2",
        "name": "demo",
        "type": "t3.small",
        "state": "running",
        "cpu_avg": 4.9,
        "memory_avg": 50,
        "observation_hours": 72,
        "monthly_cost": 20,
        "estimated_rightsized_cost": 10,
    }

    assert analyse([resource], costs())[0]["rule_id"] == "possible_underutilised_instance"

    assert analyse([{**resource, "cpu_avg": 5}], costs()) == []
    assert analyse([{**resource, "observation_hours": 71}], costs()) == []

    volume = {
        "id": "v",
        "service": "EBS",
        "name": "orphan",
        "type": "gp3",
        "state": "available",
        "attachment": None,
        "monthly_cost": 8,
    }

    assert analyse([volume], costs())[0]["rule_id"] == "unattached_ebs_volume"

    assert analyse([], costs(121))[0]["rule_id"] == "cost_spike_detected"
    assert analyse([], costs(120)) == []