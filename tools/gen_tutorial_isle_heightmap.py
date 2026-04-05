"""
Generate an original 16-bit grayscale heightmap for Terrain3D (not derived from OSRS/Jagex data).
Run from repo root: python tools/gen_tutorial_isle_heightmap.py
"""
from __future__ import annotations

import os

import numpy as np
from PIL import Image

# Output: Terrain3D expects 16-bit for smooth terrain (docs discourage 8-bit).


def main() -> None:
    w = h = 512
    xs = np.linspace(-1.0, 1.0, w)
    ys = np.linspace(-1.0, 1.0, h)
    x, y = np.meshgrid(xs, ys)

    angle = np.arctan2(y, x)
    # Elongated "kidney" silhouette (readable from above; generic coastal tutorial vibe).
    a, b = 0.88, 0.74
    ex, ey = x / a, y / b
    r = np.sqrt(ex * ex + ey * ey)

    wobble = (
        0.11 * np.sin(3.0 * angle)
        + 0.07 * np.sin(5.0 * angle + 1.65)
        + 0.045 * np.cos(2.4 * angle + 0.35)
    )
    shore = 0.70 + wobble
    edge = (shore - r) / 0.085
    mask = np.clip(edge, 0.0, 1.0)
    mask = mask * mask * (3.0 - 2.0 * mask)

    # Gentle interior dome + low-frequency "chunky" variation (early-2000s MMO readability).
    roll = (
        0.022 * np.sin(x * 11.0 + y * 8.5)
        + 0.016 * np.sin(x * 19.0 - y * 14.0)
        + 0.012 * np.sin(x * 6.2 + 2.1) * np.sin(y * 7.1 - 1.4)
    )
    dome = 0.22 * (1.0 - np.minimum(r / 0.58, 1.0) ** 2)
    interior = 0.14 + dome + roll
    interior = np.clip(interior, 0.0, 1.0)

    # Courtyard-ish flatter pad (future building / guide NPC spot) — subtle, not a plateau copy.
    cx, cy = -0.14, 0.26
    d2 = (x - cx) ** 2 + (y - cy) ** 2
    pad = np.exp(-d2 / (0.11**2))
    interior = interior - pad * 0.045 * mask
    interior = np.clip(interior, 0.0, 1.0)

    # Tiny secondary knob (sandy hill / secondary landmark) — breaks symmetry vs a plain ellipse.
    bx, by = 0.42, -0.18
    blob = np.exp(-((x - bx) ** 2 + (y - by) ** 2) / (0.055**2))
    interior = interior + blob * 0.06 * mask

    # Beach ring: slightly lower near shore.
    beach = np.clip((shore - r) / 0.22, 0.0, 1.0)
    height = interior * (0.35 + 0.65 * beach) * mask

    # Sea floor / water — low flat values (avoid true zero if tools treat it specially).
    sea = 0.012
    height = sea + (1.0 - sea) * height

    height = np.clip(height, 0.0, 1.0)
    u16 = (height * 65535.0 + 0.5).astype(np.uint16)
    img = Image.fromarray(u16, "I;16")

    out = os.path.normpath(
        os.path.join(
            os.path.dirname(__file__),
            "..",
            "world",
            "regions",
            "tutorial_isle",
            "data",
            "tutorial_isle_height.png",
        )
    )
    os.makedirs(os.path.dirname(out), exist_ok=True)
    img.save(out)
    print("Wrote", out, f"({w}x{h}, I;16)")


if __name__ == "__main__":
    main()
