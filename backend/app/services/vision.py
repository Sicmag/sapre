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
