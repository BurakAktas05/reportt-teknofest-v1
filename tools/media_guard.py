#!/usr/bin/env python3
"""
Medya guvenlik kapisi + NLP Aciliyet Skoru Motoru.

Amac:
- Dis mekan olasiligini tahmin etmek
- Selfie veya yuze asiri yakin cekim riskini kabaca tespit etmek
- Uygunsa plakayi OCR ile okumayi denemek
- V2: Dogal Dil Isleme ile aciklama metninden aciliyet skoru (1-10) uretmek

Bu script bir karar motoru degil, ilk savunma katmanidir.
Supheli dosyalari "manual review" akisina iter.

Kurulum:
    pip install opencv-python pillow numpy pytesseract
"""

from __future__ import annotations

import argparse
import json
import re
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


# ═══════════════════════════════════════════════════════════════════
# V2: NLP Aciliyet Skoru Motoru (Modül 1 — Smart Triage)
# ═══════════════════════════════════════════════════════════════════

# Anahtar kelime ağırlık sözlüğü — Türkçe doğal dil işleme
URGENCY_KEYWORDS: dict[str, float] = {
    # Yüksek aciliyet (8-10)
    "ölüm": 10.0, "olum": 10.0,
    "cinayet": 10.0, "silah": 9.5, "silahli": 9.5,
    "bicak": 9.0, "bicakli": 9.0, "biçak": 9.0,
    "vuruldu": 9.5, "vurulmuş": 9.5,
    "rehin": 9.0, "kacirma": 9.0, "kaçırma": 9.0,
    "patlama": 9.5, "bomba": 10.0,
    "yaralama": 8.5, "yaralandi": 8.5,
    "kan": 8.0, "kanli": 8.0, "kanlı": 8.0,
    "tecavuz": 9.5, "tecavüz": 9.5,
    "siddet": 8.5, "şiddet": 8.5,
    "kavga": 7.5, "dovus": 7.5, "dövüş": 7.5,
    "yangin": 9.0, "yangın": 9.0,
    "deprem": 9.0, "sel": 8.5,
    "cocuk": 7.0, "çocuk": 7.0,
    "kadin": 6.5, "kadın": 6.5,
    "tehdit": 7.5,
    "acil": 8.0, "imdat": 9.0,
    "ambulans": 8.5, "polis": 6.0, "itfaiye": 8.5,

    # Orta aciliyet (5-7)
    "hirsizlik": 6.5, "hırsızlık": 6.5,
    "gasp": 7.0, "soygun": 7.0,
    "taciz": 7.0, "takip": 6.0,
    "kaza": 7.0, "trafik": 5.0,
    "sarhos": 5.5, "sarhoş": 5.5, "alkol": 5.0,
    "uyusturucu": 7.5, "uyuşturucu": 7.5,
    "gurultu": 4.0, "gürültü": 4.0,
    "vandalizm": 5.0, "hasar": 5.5,
    "kirildi": 5.0, "kırıldı": 5.0,

    # Düşük aciliyet (1-4)
    "park": 3.0, "durakli": 3.0,
    "cop": 2.5, "çöp": 2.5, "atik": 2.5, "atık": 2.5,
    "kirlilik": 3.0, "kirliliği": 3.0,
    "gurultu": 3.5,
    "bozuk": 2.0, "cukur": 2.5, "çukur": 2.5,
    "tabela": 2.0, "isik": 2.5, "ışık": 2.5,
}

# Kategori bazlı taban aciliyet skorları
CATEGORY_BASE_SCORES: dict[str, float] = {
    "VIOLENCE": 7.0,
    "SECURITY": 6.0,
    "TRAFFIC_OFFENSE": 5.0,
    "PUBLIC_SAFETY": 5.5,
    "VANDALISM": 4.0,
    "PARKING_VIOLATION": 2.5,
    "ENVIRONMENTAL": 3.0,
    "INFRASTRUCTURE": 2.5,
    "OTHER": 3.0,
}


def analyze_urgency_nlp(description: str, category: str) -> dict:
    """
    Türkçe NLP ile ihbar açıklamasından aciliyet skoru (1-10) üretir.

    Algoritma:
    1. Metin küçük harfe çevrilir ve tokenize edilir
    2. Her token ağırlık sözlüğünden aranır
    3. Bulunan en yüksek ağırlık + kategori taban skoru ağırlıklı ortalanır
    4. Eşleşen anahtar kelime sayısı bonusu eklenir
    5. Final skor 1-10 aralığına normalize edilir
    """
    if not description or not description.strip():
        base = CATEGORY_BASE_SCORES.get(category, 3.0)
        return {
            "urgencyScore": max(1, min(10, round(base))),
            "nlpSummary": "Aciklama metni bos. Kategori tabani kullanildi.",
            "matchedKeywords": [],
            "keywordCount": 0,
        }

    # Tokenize
    text_lower = description.lower()
    # Türkçe karakterleri koruyarak tokenize
    tokens = re.findall(r'[a-zçğıöşü]+', text_lower)

    matched_keywords: list[str] = []
    max_keyword_weight = 0.0

    for token in tokens:
        if token in URGENCY_KEYWORDS:
            weight = URGENCY_KEYWORDS[token]
            matched_keywords.append(token)
            if weight > max_keyword_weight:
                max_keyword_weight = weight

    category_base = CATEGORY_BASE_SCORES.get(category, 3.0)
    keyword_count = len(matched_keywords)

    if keyword_count == 0:
        # Hiç anahtar kelime yoksa kategori tabanı kullan
        final_score = category_base
    else:
        # Ağırlıklı ortalama: %60 en yüksek kelime, %25 kategori tabanı, %15 kelime sayısı bonusu
        keyword_count_bonus = min(keyword_count * 0.5, 2.0)
        final_score = (
            max_keyword_weight * 0.60
            + category_base * 0.25
            + keyword_count_bonus * 0.15
            + keyword_count_bonus
        )

    # Normalize [1, 10]
    urgency_score = max(1, min(10, round(final_score)))

    # Özet oluştur
    if urgency_score >= 8:
        level = "YUKSEK ONCELIK"
    elif urgency_score >= 5:
        level = "ORTA ONCELIK"
    else:
        level = "DUSUK ONCELIK"

    unique_keywords = list(set(matched_keywords))
    summary_parts = [f"Aciliyet: {urgency_score}/10 ({level})."]
    if unique_keywords:
        summary_parts.append(f"Tespit edilen anahtar kelimeler: {', '.join(unique_keywords[:5])}.")
    summary_parts.append(f"Kategori tabani: {category} ({category_base}).")

    return {
        "urgencyScore": urgency_score,
        "nlpSummary": " ".join(summary_parts),
        "matchedKeywords": unique_keywords[:10],
        "keywordCount": keyword_count,
    }


# ═══════════════════════════════════════════════════════════════════


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


def analyze_media(file_path: Path, content_type: str, category: str, description: str = "") -> dict:
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

        # V2: NLP Aciliyet Analizi
        nlp_result = analyze_urgency_nlp(description, category)

        return {
            "analysisStatus": analysis_status,
            "summary": summarize(outdoor_confidence, selfie_risk, detected_plate, content_type),
            "outdoorConfidence": round(outdoor_confidence, 4),
            "selfieRisk": round(selfie_risk, 4),
            "detectedPlate": detected_plate,
            "reviewRequired": review_required,
            # V2: NLP sonuçları
            "urgencyScore": nlp_result["urgencyScore"],
            "nlpSummary": nlp_result["nlpSummary"],
            "signals": {
                **outdoor,
                **selfie,
                "nlp": nlp_result,
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
        "urgencyScore": None,
        "nlpSummary": None,
        "signals": {},
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Medya guvenlik analizi + NLP aciliyet skoru")
    parser.add_argument("--file", required=True, type=Path, help="Analiz edilecek medya dosyasi")
    parser.add_argument("--content-type", default="", help="Medya content type degeri")
    parser.add_argument("--category", default="OTHER", help="Rapor kategorisi")
    parser.add_argument("--description", default="", help="V2: NLP analizi icin ihbar aciklama metni")
    args = parser.parse_args()

    result = analyze_media(
        args.file,
        args.content_type or "",
        args.category or "OTHER",
        args.description or "",
    )
    json.dump(result, sys.stdout, ensure_ascii=True)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
