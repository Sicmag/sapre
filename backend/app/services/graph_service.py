from app.db.neo4j_client import run_query
import uuid

def upsert_plate_detection(plate: str, source_id: str, legal_basis: str):
    query = """
    MERGE (p:Plate {id: $plate})
      ON CREATE SET p.legal_basis = $legal_basis, p.created_at = datetime()
    MERGE (e:Event {id: $event_id})
      ON CREATE SET e.type = 'detection', e.at = datetime(), e.legal_basis = $legal_basis
    MERGE (l:Location {id: $source_id})
      ON CREATE SET l.type = 'camera', l.legal_basis = $legal_basis
    MERGE (p)-[:DETECTED_AT {legal_basis: $legal_basis}]->(e)
    MERGE (e)-[:OCCURRED_AT {legal_basis: $legal_basis}]->(l)
    """
    run_query(query, {
        "plate": plate,
        "source_id": source_id,
        "legal_basis": legal_basis,
        "event_id": str(uuid.uuid4()),
    })

def get_nexos_by_plate(plate: str) -> dict:
    query = """
    MATCH (p:Plate {id: $plate})
    OPTIONAL MATCH (p)-[r1]-(n1)
    OPTIONAL MATCH (n1)-[r2]-(n2)
    RETURN p, collect(DISTINCT n1) AS neighbors, collect(DISTINCT n2) AS second_degree
    """
    rows = run_query(query, {"plate": plate})
    if not rows:
        return {"plate": plate, "nodes": [], "relations": []}
    row = rows[0]
    nodes = []
    seen = set()
    for n in row.get("neighbors", []) + row.get("second_degree", []):
        if n and n.get("id") and n["id"] not in seen:
            seen.add(n["id"])
            nodes.append({
                "id": n["id"],
                "type": list(n.labels)[0] if hasattr(n, "labels") else "Unknown",
                "label": n.get("id", ""),
                "legal_basis": n.get("legal_basis", "pendiente"),
            })
    return {"plate": plate, "nodes": nodes, "relations": []}
