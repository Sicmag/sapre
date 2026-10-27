# Crear estructura de carpetas
$folders = @(
    "backend\app\db", "backend\app\models", "backend\app\api", 
    "backend\app\services", "frontend\src", "frontend\public", "docs"
)
foreach ($folder in $folders) {
    New-Item -ItemType Directory -Force -Path $folder | Out-Null
}

# 1. docker-compose.yml
@"
version: "3.9"

services:
  neo4j:
    image: neo4j:5.20-community
    container_name: sapre-neo4j
    environment:
      NEO4J_AUTH: `${NEO4J_USER}/${NEO4J_PASSWORD}
      NEO4J_PLUGINS: '["apoc"]'
    ports:
      - "7474:7474"
      - "7687:7687"
    volumes:
      - neo4j_data:/data
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:7474"]
      interval: 10s
      timeout: 5s
      retries: 10

  postgis:
    image: postgis/postgis:16-3.4
    container_name: sapre-postgis
    environment:
      POSTGRES_USER: `${POSTGRES_USER}
      POSTGRES_PASSWORD: `${POSTGRES_PASSWORD}
      POSTGRES_DB: `${POSTGRES_DB}
    ports:
      - "5432:5432"
    volumes:
      - postgis_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U `${POSTGRES_USER}"]
      interval: 10s
      timeout: 5s
      retries: 10

  backend:
    build: ./backend
    container_name: sapre-backend
    env_file: .env
    ports:
      - "8000:8000"
    depends_on:
      neo4j:
        condition: service_healthy
      postgis:
        condition: service_healthy
    volumes:
      - ./backend:/app
    command: uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

  frontend:
    build: ./frontend
    container_name: sapre-frontend
    ports:
      - "3000:3000"
    depends_on:
      - backend
    volumes:
      - ./frontend:/app
      - /app/node_modules
    command: npm start

volumes:
  neo4j_data:
  postgis_data:
"@ | Out-File -FilePath docker-compose.yml -Encoding utf8

# 2. .env
@"
NEO4J_URI=bolt://neo4j:7687
NEO4J_USER=neo4j
NEO4J_PASSWORD=cambia_esto_en_produccion

POSTGRES_USER=sapre
POSTGRES_PASSWORD=cambia_esto_en_produccion
POSTGRES_DB=sapre
POSTGRES_HOST=postgis
POSTGRES_PORT=5432

APP_ENV=development
APP_NAME=SAPRE
AUDIT_LOG_PATH=/app/logs/audit.log

ROUTING_CITY=Bogota, Colombia
ROUTING_PENALTY_CAI=0.7
ROUTING_PENALTY_CONGESTION=0.5

MAX_QUERIES_PER_HOUR=200
REQUIRE_HUMAN_VALIDATION=true
"@ | Out-File -FilePath .env -Encoding utf8

# 3. Backend
@"
fastapi==0.115.0
uvicorn[standard]==0.30.6
pydantic==2.9.2
pydantic-settings==2.5.2
neo4j==5.24.0
psycopg[binary]==3.2.3
sqlalchemy==2.0.35
geoalchemy2==0.15.2
osmnx==2.0.1
networkx==3.3
ultralytics==8.3.3
opencv-python-headless==4.10.0.84
easyocr==1.7.1
python-multipart==0.0.9
python-jose[cryptography]==3.3.0
"@ | Out-File -FilePath backend\requirements.txt -Encoding utf8

@"
FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN mkdir -p /app/logs

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
"@ | Out-File -FilePath backend\Dockerfile -Encoding utf8

# Backend App
@"
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    app_env: str = "development"
    app_name: str = "SAPRE"

    neo4j_uri: str = "bolt://neo4j:7687"
    neo4j_user: str = "neo4j"
    neo4j_password: str = "neo4j"

    postgres_user: str = "sapre"
    postgres_password: str = "sapre"
    postgres_db: str = "sapre"
    postgres_host: str = "postgis"
    postgres_port: int = 5432

    audit_log_path: str = "/app/logs/audit.log"

    routing_city: str = "Bogota, Colombia"
    routing_penalty_cai: float = 0.7
    routing_penalty_congestion: float = 0.5

    max_queries_per_hour: int = 200
    require_human_validation: bool = True

    class Config:
        env_file = ".env"

settings = Settings()
"@ | Out-File -FilePath backend\app\config.py -Encoding utf8

@"
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.api import plates, graph, routes, alerts, audit

app = FastAPI(
    title=settings.app_name,
    description="Sistema de Analítica Predictiva para Rutas de Escape - Fase 1",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(plates.router, prefix="/api/v1/plates", tags=["Placas"])
app.include_router(graph.router, prefix="/api/v1/graph", tags=["Grafo"])
app.include_router(routes.router, prefix="/api/v1/routes", tags=["Rutas"])
app.include_router(alerts.router, prefix="/api/v1/alerts", tags=["Alertas"])
app.include_router(audit.router, prefix="/api/v1/audit", tags=["Auditoría"])

@app.get("/health")
def health():
    return {"status": "ok", "app": settings.app_name, "env": settings.app_env}
"@ | Out-File -FilePath backend\app\main.py -Encoding utf8

@"
from neo4j import GraphDatabase
from app.config import settings

_driver = None

def get_driver():
    global _driver
    if _driver is None:
        _driver = GraphDatabase.driver(
            settings.neo4j_uri,
            auth=(settings.neo4j_user, settings.neo4j_password),
        )
    return _driver

def run_query(query: str, params: dict | None = None):
    with get_driver().session() as session:
        result = session.run(query, params or {})
        return [record.data() for record in result]
"@ | Out-File -FilePath backend\app\db\neo4j_client.py -Encoding utf8

@"
import cv2
import easyocr
import numpy as np
from ultralytics import YOLO
from typing import List, Dict

_yolo = YOLO("yolov8n.pt")
_ocr = easyocr.Reader(["en"], gpu=False)

VEHICLE_CLASSES = {2: "car", 3: "motorcycle", 5: "bus", 7: "truck"}

def detect_vehicles(image: np.ndarray) -> List[Dict]:
    results = _yolo(image, verbose=False)
    detections = []
    for r in results:
        for box in r.boxes:
            cls = int(box.cls[0])
            if cls in VEHICLE_CLASSES:
                x1, y1, x2, y2 = map(int, box.xyxy[0].tolist())
                detections.append({
                    "vehicle_type": VEHICLE_CLASSES[cls],
                    "confidence": float(box.conf[0]),
                    "bbox": [x1, y1, x2, y2],
                })
    return detections

def read_plate(image: np.ndarray, bbox: List[int]) -> Dict:
    x1, y1, x2, y2 = bbox
    crop = image[y1:y2, x1:x2]
    if crop.size == 0:
        return {"plate": "", "confidence": 0.0}
    gray = cv2.cvtColor(crop, cv2.COLOR_BGR2GRAY)
    results = _ocr.readtext(gray)
    if not results:
        return {"plate": "", "confidence": 0.0}
    best = max(results, key=lambda r: r[2])
    text = best[1].upper().replace(" ", "").replace("-", "")
    return {"plate": text, "confidence": float(best[2])}

def process_frame(image_bytes: bytes) -> List[Dict]:
    arr = np.frombuffer(image_bytes, np.uint8)
    image = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if image is None:
        return []
    vehicles = detect_vehicles(image)
    out = []
    for v in vehicles:
        plate = read_plate(image, v["bbox"])
        if plate["plate"]:
            out.append({
                "plate": plate["plate"],
                "confidence": plate["confidence"],
                "vehicle_type": v["vehicle_type"],
                "bbox": v["bbox"],
            })
    return out
"@ | Out-File -FilePath backend\app\services\vision.py -Encoding utf8

@"
from app.db.neo4j_client import run_query
import uuid

def upsert_plate_detection(plate: str, source_id: str, legal_basis: str):
    query = """
    MERGE (p:Plate {id: `$plate})
      ON CREATE SET p.legal_basis = `$legal_basis, p.created_at = datetime()
    MERGE (e:Event {id: `$event_id})
      ON CREATE SET e.type = 'detection', e.at = datetime(), e.legal_basis = `$legal_basis
    MERGE (l:Location {id: `$source_id})
      ON CREATE SET l.type = 'camera', l.legal_basis = `$legal_basis
    MERGE (p)-[:DETECTED_AT {legal_basis: `$legal_basis}]->(e)
    MERGE (e)-[:OCCURRED_AT {legal_basis: `$legal_basis}]->(l)
    """
    run_query(query, {
        "plate": plate,
        "source_id": source_id,
        "legal_basis": legal_basis,
        "event_id": str(uuid.uuid4()),
    })

def get_nexos_by_plate(plate: str) -> dict:
    query = """
    MATCH (p:Plate {id: `$plate})
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
"@ | Out-File -FilePath backend\app\services\graph_service.py -Encoding utf8

@"
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
"@ | Out-File -FilePath backend\app\services\audit_service.py -Encoding utf8

@"
from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from app.services.vision import process_frame
from app.services.graph_service import upsert_plate_detection
from app.services.audit_service import log
from pydantic import BaseModel
from datetime import datetime

router = APIRouter()

class PlateDetection(BaseModel):
    plate: str
    confidence: float
    vehicle_type: str
    source_id: str

@router.post("/detect", response_model=list[PlateDetection])
async def detect(
    file: UploadFile = File(...),
    source_id: str = Form(...),
    legal_basis: str = Form(...),
    operator_id: str = Form(...),
):
    if not legal_basis.strip():
        raise HTTPException(status_code=400, detail="Base legal obligatoria")
    content = await file.read()
    detections = process_frame(content)
    results = []
    for d in detections:
        if d["confidence"] < 0.5:
            continue
        upsert_plate_detection(d["plate"], source_id, legal_basis)
        log(operator_id, "plate_detected", d["plate"], {
            "source_id": source_id, "confidence": d["confidence"], "legal_basis": legal_basis,
        })
        results.append(PlateDetection(**d, source_id=source_id))
    return results
"@ | Out-File -FilePath backend\app\api\plates.py -Encoding utf8

@"
from fastapi import APIRouter, HTTPException
from app.services.graph_service import get_nexos_by_plate
from pydantic import BaseModel
from typing import List

router = APIRouter()

class GraphNode(BaseModel):
    id: str
    type: str
    label: str
    legal_basis: str

class NexosResponse(BaseModel):
    plate: str
    nodes: List[GraphNode]
    relations: List[dict]

@router.get("/nexos/{plate}", response_model=NexosResponse)
def nexos_by_plate(plate: str):
    data = get_nexos_by_plate(plate)
    if not data["nodes"]:
        raise HTTPException(status_code=404, detail="Placa sin nexos registrados")
    return data
"@ | Out-File -FilePath backend\app\api\graph.py -Encoding utf8

@"
import osmnx as ox
import networkx as nx
from typing import List
from fastapi import APIRouter
from pydantic import BaseModel

router = APIRouter()
_graph = None

def get_graph():
    global _graph
    if _graph is None:
        _graph = ox.graph_from_place("Bogota, Colombia", network_type="drive")
    return _graph

class RouteRequest(BaseModel):
    origin_lat: float
    origin_lon: float
    n_routes: int = 3

class RouteResult(BaseModel):
    route_id: int
    score: float
    distance_m: float
    geometry: List[List[float]]
    penalized_cai: bool
    penalized_congestion: bool

class RoutesResponse(BaseModel):
    origin: List[float]
    routes: List[RouteResult]

@router.post("/compute", response_model=RoutesResponse)
def compute(req: RouteRequest):
    G = get_graph()
    origin_node = ox.distance.nearest_nodes(G, req.origin_lon, req.origin_lat)
    candidates = list(G.successors(origin_node))
    routes = []
    for i, target in enumerate(candidates[:max(req.n_routes * 3, 9)]):
        try:
            path = nx.shortest_path(G, origin_node, target, weight="length")
        except nx.NetworkXNoPath:
            continue
        length = sum(G[u][v][0].get("length", 0) for u, v in zip(path[:-1], path[1:]))
        score = 1.0 / (1.0 + length / 1000.0)
        geometry = [[G.nodes[n]["y"], G.nodes[n]["x"]] for n in path]
        routes.append({
            "route_id": i, "score": round(score, 4), "distance_m": round(length, 1),
            "geometry": geometry, "penalized_cai": False, "penalized_congestion": False,
        })
    routes.sort(key=lambda r: r["score"], reverse=True)
    return {"origin": [req.origin_lat, req.origin_lon], "routes": routes[:req.n_routes]}
"@ | Out-File -FilePath backend\app\api\routes.py -Encoding utf8

@"
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from datetime import datetime
import uuid
from app.services.audit_service import log
from app.config import settings

router = APIRouter()

class AlertCreate(BaseModel):
    plate: str
    operator_id: str
    operator_note: str

class AlertResponse(BaseModel):
    alert_id: str
    status: str
    created_at: datetime
    requires_human_validation: bool

@router.post("/validate", response_model=AlertResponse)
def validate_alert(alert: AlertCreate):
    if settings.require_human_validation and not alert.operator_note.strip():
        raise HTTPException(status_code=400, detail="Nota del operador requerida")
    alert_id = str(uuid.uuid4())
    log(alert.operator_id, "alert_validated", alert_id, {
        "plate": alert.plate, "note": alert.operator_note
    })
    return {
        "alert_id": alert_id, "status": "validated", 
        "created_at": datetime.utcnow(), "requires_human_validation": True
    }
"@ | Out-File -FilePath backend\app\api\alerts.py -Encoding utf8

@"
from fastapi import APIRouter
from fastapi.responses import PlainTextResponse
from app.config import settings

router = APIRouter()

@router.get("/tail", response_class=PlainTextResponse)
def tail(lines: int = 50):
    try:
        with open(settings.audit_log_path, "r", encoding="utf-8") as f:
            content = f.readlines()[-lines:]
        return "".join(content)
    except FileNotFoundError:
        return "Sin registros de auditoría aún."
"@ | Out-File -FilePath backend\app\api\audit.py -Encoding utf8

# Init empty files
"" | Out-File -FilePath backend\app\__init__.py
"" | Out-File -FilePath backend\app\db\__init__.py
"" | Out-File -FilePath backend\app\api\__init__.py
"" | Out-File -FilePath backend\app\services\__init__.py

# 4. Frontend
@"
{
  "name": "sapre-frontend",
  "version": "0.1.0",
  "private": true,
  "dependencies": {
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "react-scripts": "5.0.1"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build"
  },
  "browserslist": {
    "production": [">0.2%", "not dead", "not op_mini all"],
    "development": ["last 1 chrome version", "last 1 firefox version"]
  }
}
"@ | Out-File -FilePath frontend\package.json -Encoding utf8

@"
FROM node:20-alpine
WORKDIR /app
COPY package.json .
RUN npm install
COPY . .
EXPOSE 3000
CMD ["npm", "start"]
"@ | Out-File -FilePath frontend\Dockerfile -Encoding utf8

@"
<!DOCTYPE html>
<html lang="es">
  <head>
    <meta charset="utf-8" />
    <title>SAPRE</title>
  </head>
  <body>
    <div id="root"></div>
  </body>
</html>
"@ | Out-File -FilePath frontend\public\index.html -Encoding utf8

@"
import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";

const root = ReactDOM.createRoot(document.getElementById("root"));
root.render(<App />);
"@ | Out-File -FilePath frontend\src\index.js -Encoding utf8

@"
import { useState } from "react";

const API = "http://localhost:8000";

export default function App() {
  const [plate, setPlate] = useState("");
  const [nexos, setNexos] = useState(null);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function consultar() {
    setError("");
    setNexos(null);
    if (!plate.trim()) return;
    setLoading(true);
    try {
      const r = await fetch(`${API}/api/v1/graph/nexos/${plate.trim().toUpperCase()}`);
      if (!r.ok) throw new Error("Sin nexos registrados para esta placa");
      setNexos(await r.json());
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div style={{ fontFamily: "sans-serif", padding: 24, maxWidth: 900, margin: "auto" }}>
      <h1>SAPRE — Fase 1</h1>
      <p style={{ color: "#666" }}>
        Analítica de vigilancia con revisión humana obligatoria. Sin facial. Sin operaciones encubiertas.
      </p>

      <div style={{ display: "flex", gap: 8, margin: "16px 0" }}>
        <input
          value={plate}
          onChange={(e) => setPlate(e.target.value)}
          placeholder="Placa (ej: ABC123)"
          style={{ padding: 8, flex: 1, textTransform: "uppercase" }}
        />
        <button onClick={consultar} disabled={loading} style={{ padding: "8px 16px" }}>
          {loading ? "Consultando..." : "Consultar nexos"}
        </button>
      </div>

      {error && <p style={{ color: "crimson" }}>{error}</p>}

      {nexos && (
        <div>
          <h2>Nexos para {nexos.plate}</h2>
          <ul>
            {nexos.nodes.map((n) => (
              <li key={n.id}>
                <strong>{n.type}</strong>: {n.label} — base legal: {n.legal_basis}
              </li>
            ))}
          </ul>
        </div>
      )}

      <footer style={{ marginTop: 32, fontSize: 12, color: "#888" }}>
        Cada consulta queda registrada en auditoría inmutable. Revisión humana obligatoria antes de cualquier acción.
      </footer>
    </div>
  );
}
"@ | Out-File -FilePath frontend\src\App.jsx -Encoding utf8

Write-Host "¡Estructura y archivos creados exitosamente!" -ForegroundColor Green