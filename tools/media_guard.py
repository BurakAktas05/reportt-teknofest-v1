#!/usr/bin/env python3
"""
Medya guvenlik kapisi.

Amac:
- Dis mekan olasiligini tahmin etmek
- Selfie veya yuze asiri yakin cekim riskini kabaca tespit etmek
- Uygunsa plakayi OCR ile okumayi denemek

Bu script bir karar motoru degil, ilk savunma katmanidir.
Supheli dosyalari "manual review" akisina iter.

Kurulum:
    pip install opencv-python pillow numpy pytesseract
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

try:
    import cv2  # type: ignore
except Exception:  # pragma: no cover
    cv2 = None

try:
    import numpy as np  # type: ignore
except Exception:  # pragma: no cover
    np = None

try:
    from PIL import Image, ImageStat  # type: ignore
except Exception:  # pragma: no cover
    Image = None
    ImageStat = None

try:
    from plate_reader import extract_plate_text
except Exception:  # pragma: no cover
    extract_plate_text = None


def clamp(value: float, minimum: float = 0.0, maximum: float = 1.0) -> float:
    return max(minimum, min(maximum, float(value)))


def load_with_pillow(path: Path):
    if Image is None:
        raise RuntimeError("Pillow kurulu degil.")
    image = Image.open(path).convert("RGB")
    return image


def extract_video_frame(path: Path):
    if cv2 is None:
        raise RuntimeError("OpenCV kurulu degil.")
    capture = cv2.VideoCapture(str(path))
    ok, frame = capture.read()
    capture.release()
    if not ok or frame is None:
        raise RuntimeError("Videodan frame okunamadi.")
    return frame


def ndarray_to_rgb(frame):
    if cv2 is None or np is None:
        raise RuntimeError("OpenCV veya numpy kurulu degil.")
    return cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)


def analyze_outdoor_with_cv(rgb_image):
    if cv2 is None or np is None:
        raise RuntimeError("OpenCV veya numpy kurulu degil.")

    hsv = cv2.cvtColor(rgb_image, cv2.COLOR_RGB2HSV)
    height, width = hsv.shape[:2]
    top_slice = hsv[: max(1, height // 3), :]

    hue = hsv[:, :, 0]
    sat = hsv[:, :, 1]
    val = hsv[:, :, 2]

    sky_mask = (
        ((top_slice[:, :, 0] >= 85) & (top_slice[:, :, 0] <= 130))
        & (top_slice[:, :, 1] >= 25)
        & (top_slice[:, :, 2] >= 70)
    )
    vegetation_mask = (
        ((hue >= 35) & (hue <= 90))
        & (sat >= 35)
        & (val >= 35)
    )

    gray = cv2.cvtColor(rgb_image, cv2.COLOR_RGB2GRAY)
    edges = cv2.Canny(gray, 60, 160)
    edge_density = float((edges > 0).mean())
    brightness = float(val.mean() / 255.0)
    saturation = float(sat.mean() / 255.0)
    sky_ratio = float(sky_mask.mean())
    vegetation_ratio = float(vegetation_mask.mean())

    score = (
        sky_ratio * 0.40
        + vegetation_ratio * 0.18
        + brightness * 0.18
        + saturation * 0.14
        + min(edge_density * 2.5, 1.0) * 0.10
    )

    return {
        "outdoor_confidence": clamp(score),
        "sky_ratio": round(sky_ratio, 4),
        "vegetation_ratio": round(vegetation_ratio, 4),
        "brightness": round(brightness, 4),
        "saturation": round(saturation, 4),
        "edge_density": round(edge_density, 4),
    }


def analyze_outdoor_with_pillow(image):
    if ImageStat is None:
        raise RuntimeError("Pillow istatistik destegi yok.")
    stat = ImageStat.Stat(image)
    channel_means = stat.mean
    brightness = sum(channel_means) / (len(channel_means) * 255.0)
    blue_dominance = clamp((channel_means[2] - max(channel_means[0], channel_means[1]) * 0.75) / 255.0)
    score = brightness * 0.55 + blue_dominance * 0.45
    return {
        "outdoor_confidence": clamp(score),
        "brightness": round(brightness, 4),
        "blue_dominance": round(blue_dominance, 4),
    }


def detect_selfie_risk(rgb_image):
    if cv2 is None or np is None:
        return {
            "selfie_risk": 0.45,
            "face_count": 0,
            "largest_face_ratio": 0.0,
            "face_center_distance": 1.0,
            "detector": "unavailable",
        }

    gray = cv2.cvtColor(rgb_image, cv2.COLOR_RGB2GRAY)
    classifier = cv2.CascadeClassifier(cv2.data.haarcascades + "haarcascade_frontalface_default.xml")
    faces = classifier.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5, minSize=(60, 60))

    if len(faces) == 0:
        return {
            "selfie_risk": 0.05,
            "face_count": 0,
            "largest_face_ratio": 0.0,
            "face_center_distance": 1.0,
            "detector": "haar",
        }

    height, width = gray.shape[:2]
    image_area = float(height * width)
    cx_image = width / 2.0
    cy_image = height / 2.0

    largest_ratio = 0.0
    best_distance = 1.0
    for x, y, w, h in faces:
        ratio = (w * h) / image_area
        center_x = x + w / 2.0
        center_y = y + h / 2.0
        distance = (((center_x - cx_image) / width) ** 2 + ((center_y - cy_image) / height) ** 2) ** 0.5
        if ratio > largest_ratio:
            largest_ratio = ratio
            best_distance = distance

    centered_bonus = clamp(1.0 - min(best_distance / 0.35, 1.0))
    risk = largest_ratio * 3.2 + centered_bonus * 0.35 + min(len(faces), 3) * 0.06

    return {
        "selfie_risk": clamp(risk),
        "face_count": int(len(faces)),
        "largest_face_ratio": round(largest_ratio, 4),
        "face_center_distance": round(best_distance, 4),
        "detector": "haar",
    }


def maybe_detect_plate(file_path: Path, content_type: str, category: str) -> str | None:
    if extract_plate_text is None:
        return None
    if not content_type.startswith("image/"):
        return None
    if category not in {"PARKING_VIOLATION", "TRAFFIC_OFFENSE"}:
        return None
    try:
        return extract_plate_text(file_path)
    except Exception:
        return None


def summarize(outdoor_confidence: float, selfie_risk: float, detected_plate: str | None, content_type: str) -> str:
    parts: list[str] = []
    if content_type.startswith("video/"):
        parts.append("Video ilk karesi incelendi.")
    if outdoor_confidence >= 0.7:
        parts.append("Dis mekan olasiligi yuksek.")
    elif outdoor_confidence >= 0.5:
        parts.append("Dis mekan olasiligi orta seviyede.")
    else:
        parts.append("Dis mekan olasiligi dusuk.")

    if selfie_risk >= 0.65:
        parts.append("Selfie veya yuze yakin cekim riski yuksek.")
    elif selfie_risk >= 0.4:
        parts.append("Kismi selfie riski var.")
    else:
        parts.append("Belirgin selfie riski gorulmedi.")

    if detected_plate:
        parts.append(f"Muhtemel plaka: {detected_plate}.")

    return " ".join(parts)


def analyze_media(file_path: Path, content_type: str, category: str) -> dict:
    if not file_path.exists():
        return failed_result("Dosya bulunamadi.")

    try:
        if content_type.startswith("video/"):
            frame = extract_video_frame(file_path)
            rgb_image = ndarray_to_rgb(frame)
            outdoor = analyze_outdoor_with_cv(rgb_image)
            selfie = detect_selfie_risk(rgb_image)
        elif cv2 is not None and np is not None:
            frame = cv2.imread(str(file_path))
            if frame is None:
                raise RuntimeError("Gorsel okunamadi.")
            rgb_image = ndarray_to_rgb(frame)
            outdoor = analyze_outdoor_with_cv(rgb_image)
            selfie = detect_selfie_risk(rgb_image)
        else:
            pil_image = load_with_pillow(file_path)
            outdoor = analyze_outdoor_with_pillow(pil_image)
            selfie = {
                "selfie_risk": 0.45,
                "face_count": 0,
                "largest_face_ratio": 0.0,
                "face_center_distance": 1.0,
                "detector": "unavailable",
            }

        outdoor_confidence = clamp(outdoor["outdoor_confidence"])
        selfie_risk = clamp(selfie["selfie_risk"])
        detected_plate = maybe_detect_plate(file_path, content_type, category)
        review_required = outdoor_confidence < 0.5 or selfie_risk >= 0.6
        analysis_status = "REVIEW_REQUIRED" if review_required else "CLEAR"

        return {
            "analysisStatus": analysis_status,
            "summary": summarize(outdoor_confidence, selfie_risk, detected_plate, content_type),
            "outdoorConfidence": round(outdoor_confidence, 4),
            "selfieRisk": round(selfie_risk, 4),
            "detectedPlate": detected_plate,
            "reviewRequired": review_required,
            "signals": {
                **outdoor,
                **selfie,
            },
        }
    except Exception as exc:
        return failed_result(f"Analiz basarisiz: {exc}")


def failed_result(message: str) -> dict:
    return {
        "analysisStatus": "FAILED",
        "summary": message,
        "outdoorConfidence": None,
        "selfieRisk": None,
        "detectedPlate": None,
        "reviewRequired": True,
        "signals": {},
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Medya guvenlik analizi")
    parser.add_argument("--file", required=True, type=Path, help="Analiz edilecek medya dosyasi")
    parser.add_argument("--content-type", default="", help="Medya content type degeri")
    parser.add_argument("--category", default="OTHER", help="Rapor kategorisi")
    args = parser.parse_args()

    result = analyze_media(args.file, args.content_type or "", args.category or "OTHER")
    json.dump(result, sys.stdout, ensure_ascii=True)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
