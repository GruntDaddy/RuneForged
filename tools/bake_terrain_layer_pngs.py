"""Bake tileable albedo + packed normal/rough PNGs for Terrain3D (inspector-friendly)."""
from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path


def _write_png_rgba(path: Path, width: int, height: int, rgba: bytes) -> None:
    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    raw = b""
    stride = width * 4
    for y in range(height):
        raw += b"\x00" + rgba[y * stride : (y + 1) * stride]
    compressed = zlib.compress(raw, 9)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", compressed) + chunk(b"IEND", b"")
    path.write_bytes(png)


def _fbm(nx: float, ny: float, seed: float) -> float:
    v = 0.0
    a = 0.55
    f = 1.0
    for _ in range(5):
        v += a * (0.5 + 0.5 * math.sin((nx + seed) * f) * (0.5 + 0.5 * math.cos((ny - seed * 0.7) * f * 1.17)))
        f *= 2.05
        a *= 0.48
    return max(0.0, min(1.0, v))


def _height(nx: float, ny: float, seed: float) -> float:
    return _fbm(nx, ny, seed)


def bake(out_dir: Path, size: int = 512) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)

    # --- Grass ---
    grass_alb = bytearray(size * size * 4)
    grass_h = [[0.0] * size for _ in range(size)]
    for y in range(size):
        for x in range(size):
            nx = x / float(size)
            ny = y / float(size)
            h = _height(nx * 6.2, ny * 6.2, 2.18)
            grass_h[y][x] = h
            # Dark turf with lighter flecks (multiply with Terrain3D albedo_color in scene)
            r = 0.12 + 0.22 * h
            g = 0.22 + 0.35 * h
            b = 0.10 + 0.18 * h
            i = (y * size + x) * 4
            grass_alb[i : i + 4] = bytes(
                (int(max(0, min(255, r * 255))), int(max(0, min(255, g * 255))), int(max(0, min(255, b * 255))), 255)
            )

    grass_nrm = bytearray(size * size * 4)
    for y in range(size):
        for x in range(size):
            xm = (x - 1) % size
            xp = (x + 1) % size
            ym = (y - 1) % size
            yp = (y + 1) % size
            dx = (grass_h[y][xp] - grass_h[y][xm]) * 0.5 * 6.0
            dy = (grass_h[yp][x] - grass_h[ym][x]) * 0.5 * 6.0
            n = (-dx, 1.0, -dy)
            ln = math.sqrt(n[0] * n[0] + n[1] * n[1] + n[2] * n[2]) or 1.0
            n = (n[0] / ln, n[1] / ln, n[2] / ln)
            r = int(max(0, min(255, n[0] * 0.5 + 0.5) * 255))
            g = int(max(0, min(255, n[1] * 0.5 + 0.5) * 255))
            b = int(max(0, min(255, n[2] * 0.5 + 0.5) * 255))
            rough = int(0.88 * 255)
            i = (y * size + x) * 4
            grass_nrm[i : i + 4] = bytes((r, g, b, rough))

    _write_png_rgba(out_dir / "grass_terrain_baked_alb.png", size, size, bytes(grass_alb))
    _write_png_rgba(out_dir / "grass_terrain_baked_nrm.png", size, size, bytes(grass_nrm))

    # --- Dirt ---
    dirt_alb = bytearray(size * size * 4)
    dirt_h = [[0.0] * size for _ in range(size)]
    for y in range(size):
        for x in range(size):
            nx = x / float(size)
            ny = y / float(size)
            h = _height(nx * 5.0, ny * 5.0, 9.77)
            dirt_h[y][x] = h
            r = 0.14 + 0.26 * h
            g = 0.11 + 0.22 * h
            b = 0.07 + 0.16 * h
            i = (y * size + x) * 4
            dirt_alb[i : i + 4] = bytes(
                (int(max(0, min(255, r * 255))), int(max(0, min(255, g * 255))), int(max(0, min(255, b * 255))), 255)
            )

    dirt_nrm = bytearray(size * size * 4)
    for y in range(size):
        for x in range(size):
            xm = (x - 1) % size
            xp = (x + 1) % size
            ym = (y - 1) % size
            yp = (y + 1) % size
            dx = (dirt_h[y][xp] - dirt_h[y][xm]) * 0.5 * 7.5
            dy = (dirt_h[yp][x] - dirt_h[ym][x]) * 0.5 * 7.5
            n = (-dx, 1.0, -dy)
            ln = math.sqrt(n[0] * n[0] + n[1] * n[1] + n[2] * n[2]) or 1.0
            n = (n[0] / ln, n[1] / ln, n[2] / ln)
            r = int(max(0, min(255, n[0] * 0.5 + 0.5) * 255))
            g = int(max(0, min(255, n[1] * 0.5 + 0.5) * 255))
            b = int(max(0, min(255, n[2] * 0.5 + 0.5) * 255))
            rough = int(0.94 * 255)
            i = (y * size + x) * 4
            dirt_nrm[i : i + 4] = bytes((r, g, b, rough))

    _write_png_rgba(out_dir / "dirt_path_baked_alb.png", size, size, bytes(dirt_alb))
    _write_png_rgba(out_dir / "dirt_path_baked_nrm.png", size, size, bytes(dirt_nrm))


if __name__ == "__main__":
    root = Path(__file__).resolve().parents[1]
    bake(root / "assets" / "terrain3d" / "textures")
