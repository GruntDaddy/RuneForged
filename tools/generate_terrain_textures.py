from __future__ import annotations

from pathlib import Path
from typing import Dict, Tuple

import numpy as np
from PIL import Image, ImageFilter


SIZE = 1024
SEED = 68421
OUTPUT_DIR = Path("assets/terrain3d/textures")


def tileable_field(size: int, octaves: int, rng: np.random.Generator) -> np.ndarray:
    """Build a seamless scalar field using periodic sine/cosine basis."""
    x = np.linspace(0.0, 1.0, size, endpoint=False)
    y = np.linspace(0.0, 1.0, size, endpoint=False)
    xx, yy = np.meshgrid(x, y, indexing="xy")

    field = np.zeros((size, size), dtype=np.float32)

    for octave in range(1, octaves + 1):
        amp = 1.0 / octave
        fx = rng.integers(1, 8) * octave
        fy = rng.integers(1, 8) * octave
        p1 = rng.uniform(0.0, 2.0 * np.pi)
        p2 = rng.uniform(0.0, 2.0 * np.pi)
        p3 = rng.uniform(0.0, 2.0 * np.pi)

        wave_a = np.sin((2.0 * np.pi * fx * xx) + p1)
        wave_b = np.cos((2.0 * np.pi * fy * yy) + p2)
        wave_c = np.sin((2.0 * np.pi * (fx * xx + fy * yy)) + p3)
        field += amp * (0.45 * wave_a + 0.45 * wave_b + 0.10 * wave_c)

    field -= field.min()
    field /= max(field.max(), 1e-6)
    return field


def mix(a: np.ndarray, b: np.ndarray, t: np.ndarray) -> np.ndarray:
    return (1.0 - t) * a + t * b


def to_uint8(rgb: np.ndarray) -> np.ndarray:
    return np.clip(rgb * 255.0, 0, 255).astype(np.uint8)


def sand_texture(size: int, rng: np.random.Generator) -> np.ndarray:
    n1 = tileable_field(size, 4, rng)
    n2 = tileable_field(size, 7, rng)
    grain = (0.7 * n1 + 0.3 * n2)
    grain = np.clip(grain, 0.0, 1.0)

    c0 = np.array([0.80, 0.72, 0.53], dtype=np.float32)
    c1 = np.array([0.91, 0.85, 0.67], dtype=np.float32)
    rgb = mix(c0[None, None, :], c1[None, None, :], grain[..., None])
    return to_uint8(rgb)


def grass_texture(size: int, rng: np.random.Generator) -> np.ndarray:
    base = tileable_field(size, 5, rng)
    blades = tileable_field(size, 9, rng)
    signal = np.clip(0.65 * base + 0.35 * blades, 0.0, 1.0)

    c0 = np.array([0.19, 0.36, 0.16], dtype=np.float32)
    c1 = np.array([0.34, 0.54, 0.24], dtype=np.float32)
    soil = np.array([0.39, 0.29, 0.20], dtype=np.float32)

    rgb = mix(c0[None, None, :], c1[None, None, :], signal[..., None])
    soil_mask = np.clip((base - 0.66) * 2.5, 0.0, 1.0)
    rgb = mix(rgb, soil[None, None, :], soil_mask[..., None] * 0.35)
    return to_uint8(rgb)


def dirt_texture(size: int, rng: np.random.Generator) -> np.ndarray:
    base = tileable_field(size, 5, rng)
    pebble = tileable_field(size, 10, rng)
    signal = np.clip(0.75 * base + 0.25 * pebble, 0.0, 1.0)

    c0 = np.array([0.29, 0.20, 0.13], dtype=np.float32)
    c1 = np.array([0.49, 0.35, 0.23], dtype=np.float32)
    rgb = mix(c0[None, None, :], c1[None, None, :], signal[..., None])

    pebble_mask = np.clip((pebble - 0.73) * 3.5, 0.0, 1.0)
    pebble_col = np.array([0.55, 0.50, 0.44], dtype=np.float32)
    rgb = mix(rgb, pebble_col[None, None, :], pebble_mask[..., None] * 0.45)
    return to_uint8(rgb)


def rock_texture(size: int, rng: np.random.Generator) -> np.ndarray:
    n1 = tileable_field(size, 5, rng)
    n2 = tileable_field(size, 9, rng)

    x = np.linspace(0.0, 1.0, size, endpoint=False)
    y = np.linspace(0.0, 1.0, size, endpoint=False)
    _, yy = np.meshgrid(x, y, indexing="xy")
    strata = 0.5 * (np.sin(2.0 * np.pi * (yy * 18.0 + n2 * 0.7)) + 1.0)

    signal = np.clip(0.55 * n1 + 0.30 * n2 + 0.15 * strata, 0.0, 1.0)
    c0 = np.array([0.33, 0.34, 0.35], dtype=np.float32)
    c1 = np.array([0.52, 0.50, 0.46], dtype=np.float32)
    rgb = mix(c0[None, None, :], c1[None, None, :], signal[..., None])

    accent = np.array([0.40, 0.31, 0.24], dtype=np.float32)
    warm_mask = np.clip((strata - 0.76) * 2.8, 0.0, 1.0)
    rgb = mix(rgb, accent[None, None, :], warm_mask[..., None] * 0.25)
    return to_uint8(rgb)


def save_texture(path: Path, arr: np.ndarray, blur_radius: float = 0.4) -> None:
    img = Image.fromarray(arr, mode="RGB")
    if blur_radius > 0:
        img = img.filter(ImageFilter.GaussianBlur(radius=blur_radius))
    img.save(path, format="PNG", optimize=True)


def grayscale_from_rgb(rgb: np.ndarray) -> np.ndarray:
    norm = rgb.astype(np.float32) / 255.0
    return (0.2126 * norm[..., 0]) + (0.7152 * norm[..., 1]) + (0.0722 * norm[..., 2])


def normal_from_height(height: np.ndarray, strength: float) -> np.ndarray:
    # Periodic gradients keep the generated normal map tileable.
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5 * strength
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5 * strength

    nx = -dx
    ny = -dy
    nz = np.ones_like(height, dtype=np.float32)
    length = np.sqrt(nx * nx + ny * ny + nz * nz) + 1e-8

    nx /= length
    ny /= length
    nz /= length

    normal = np.stack(
        [
            (nx * 0.5 + 0.5),
            (ny * 0.5 + 0.5),
            (nz * 0.5 + 0.5),
        ],
        axis=-1,
    )
    return to_uint8(normal)


def roughness_from_height(height: np.ndarray, base: float, variation: float) -> np.ndarray:
    lap = np.abs(np.roll(height, -1, axis=1) - height) + np.abs(np.roll(height, -1, axis=0) - height)
    lap -= lap.min()
    lap /= max(lap.max(), 1e-6)

    rough = np.clip(base + (lap * variation), 0.0, 1.0)
    channel = np.clip(rough * 255.0, 0, 255).astype(np.uint8)
    return np.stack([channel, channel, channel], axis=-1)


def save_texture_set(name: str, albedo: np.ndarray, normal_strength: float, rough_base: float, rough_variation: float) -> Dict[str, Path]:
    albedo_path = OUTPUT_DIR / f"{name}.png"
    normal_path = OUTPUT_DIR / f"{name}_normal.png"
    rough_path = OUTPUT_DIR / f"{name}_roughness.png"

    save_texture(albedo_path, albedo, blur_radius=0.0)
    height = grayscale_from_rgb(albedo)
    save_texture(normal_path, normal_from_height(height, strength=normal_strength), blur_radius=0.0)
    save_texture(rough_path, roughness_from_height(height, base=rough_base, variation=rough_variation), blur_radius=0.0)

    return {"albedo": albedo_path, "normal": normal_path, "roughness": rough_path}


def generate_textures(size: int = SIZE, seed: int = SEED) -> Tuple[Path, ...]:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(seed)

    sand_albedo = sand_texture(size, rng)
    grass_albedo = grass_texture(size, rng)
    dirt_albedo = dirt_texture(size, rng)
    rock_albedo = rock_texture(size, rng)

    # Slightly soften color maps for cleaner visual blending on large terrain patches.
    sand_albedo = np.asarray(Image.fromarray(sand_albedo, mode="RGB").filter(ImageFilter.GaussianBlur(radius=0.55)))
    grass_albedo = np.asarray(Image.fromarray(grass_albedo, mode="RGB").filter(ImageFilter.GaussianBlur(radius=0.25)))
    dirt_albedo = np.asarray(Image.fromarray(dirt_albedo, mode="RGB").filter(ImageFilter.GaussianBlur(radius=0.20)))
    rock_albedo = np.asarray(Image.fromarray(rock_albedo, mode="RGB").filter(ImageFilter.GaussianBlur(radius=0.15)))

    out = []
    sand_set = save_texture_set("terrain_sand_tile", sand_albedo, normal_strength=3.5, rough_base=0.72, rough_variation=0.14)
    grass_set = save_texture_set("terrain_grass_tile", grass_albedo, normal_strength=2.4, rough_base=0.68, rough_variation=0.18)
    dirt_set = save_texture_set("terrain_dirt_tile", dirt_albedo, normal_strength=3.0, rough_base=0.63, rough_variation=0.20)
    rock_set = save_texture_set("terrain_rock_cliff_tile", rock_albedo, normal_strength=4.8, rough_base=0.58, rough_variation=0.24)

    for tex_set in (sand_set, grass_set, dirt_set, rock_set):
        out.extend(tex_set.values())

    return tuple(out)


if __name__ == "__main__":
    generated = generate_textures()
    for tex in generated:
        print(f"generated: {tex.as_posix()}")
