#!/usr/bin/env python3
"""
Basit plaka tanima prototipi.

Kurulum:
    pip install opencv-python pytesseract

Not:
    Tesseract OCR'in sistemde kurulu olmasi gerekir.
    Windows icin gerekiyorsa `pytesseract.pytesseract.tesseract_cmd`
    satirini kendi kurulum yoluna gore acabilirsiniz.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

import cv2
import pytesseract

# Ornek:
# pytesseract.pytesseract.tesseract_cmd = r"C:\\Program Files\\Tesseract-OCR\\tesseract.exe"

TR_PLATE_REGEX = re.compile(r"\b\d{2}[A-Z]{1,3}\d{2,4}\b")


def preprocess(image):
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    filtered = cv2.bilateralFilter(gray, 11, 17, 17)
    edged = cv2.Canny(filtered, 30, 200)
    return gray, edged


def find_plate_roi(image):
    gray, edged = preprocess(image)
    contours, _ = cv2.findContours(edged.copy(), cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
    contours = sorted(contours, key=cv2.contourArea, reverse=True)[:20]

    for contour in contours:
        perimeter = cv2.arcLength(contour, True)
        polygon = cv2.approxPolyDP(contour, 0.018 * perimeter, True)
        if len(polygon) == 4:
            x, y, w, h = cv2.boundingRect(polygon)
            candidate = gray[y:y + h, x:x + w]
            if candidate.size > 0:
                return candidate
    return gray


def extract_plate_text(image_path: Path) -> str | None:
    image = cv2.imread(str(image_path))
    if image is None:
        raise FileNotFoundError(f"Gorsel okunamadi: {image_path}")

    plate_roi = find_plate_roi(image)
    threshold = cv2.threshold(plate_roi, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)[1]
    raw_text = pytesseract.image_to_string(
        threshold,
        config="--psm 7 -c tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    )

    normalized = re.sub(r"[^A-Z0-9]", "", raw_text.upper())
    match = TR_PLATE_REGEX.search(normalized)
    return match.group(0) if match else None


def main():
    parser = argparse.ArgumentParser(description="Turk plaka tanima prototipi")
    parser.add_argument("image", type=Path, help="Islenecek gorsel dosyasi")
    args = parser.parse_args()

    plate = extract_plate_text(args.image)
    if plate:
        print(plate)
        return

    print("Plaka tespit edilemedi")


if __name__ == "__main__":
    main()
