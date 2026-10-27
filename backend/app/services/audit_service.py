import json
import hashlib
from datetime import datetime
from app.config import settings

def _hash(entry: dict) -> str:
    payload = json.dumps(entry, sort_keys=True, default=str).encode()
    return hashlib.sha256(payload).hexdigest()

def log(actor: str, action: str, resource: str, detail: dict) -> dict:
    entry = {
        "timestamp": datetime.utcnow().isoformat(),
        "actor": actor,
        "action": action,
        "resource": resource,
        "detail": detail,
    }
    entry["hash"] = _hash(entry)
    with open(settings.audit_log_path, "a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    return entry
