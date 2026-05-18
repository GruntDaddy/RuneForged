"""Split world/regions/jorvik/jorvik.tscn into instanced sub-scenes.

Writes:
  jorvik_environment.tscn   (terrain, grass, ocean, sky env, day/night, sun)
  jorvik_harvestables.tscn  (Props/Harvestables subtree, re-parented to scene root)
  jorvik_materials.tscn     (bars, nuggets, stone/wood props lane)
  jorvik_gear.tscn          (weapon rack lane + armor / smelter / ranged row)

Overwrites jorvik.tscn with instances + trimmed node tree.

Run from repo root: python tools/split_jorvik.py
"""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAIN = ROOT / "world/regions/jorvik/jorvik.tscn"
ENV = ROOT / "world/regions/jorvik/jorvik_environment.tscn"
HARV = ROOT / "world/regions/jorvik/jorvik_harvestables.tscn"
MAT = ROOT / "world/regions/jorvik/jorvik_materials.tscn"
GEAR = ROOT / "world/regions/jorvik/jorvik_gear.tscn"

UID_ENV = "uid://c8jorvikenv1"
UID_HARV = "uid://c8jorvikharv1"
UID_MAT = "uid://c8jorvik_mat1"
UID_GEAR = "uid://c8jorvik_gear1"


def _find(lines: list[str], prefix: str) -> int:
    for i, line in enumerate(lines):
        if line.startswith(prefix):
            return i
    raise ValueError(f"missing line starting with {prefix!r}")


def _transform_harvest(lines: list[str]) -> list[str]:
    out: list[str] = []
    for line in lines:
        if line.startswith('[node name="Harvestables"'):
            line = line.replace(' parent="Props"', "", 1)
        elif 'parent="Props/Harvestables/' in line:
            line = line.replace('parent="Props/Harvestables/', 'parent="', 1)
        out.append(line)
    return out


def main() -> None:
    text = MAIN.read_text(encoding="utf-8")
    lines = text.splitlines(keepends=True)

    idx_gradient = _find(lines, '[sub_resource type="Gradient"')
    idx_dg2jo = _find(lines, '[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_dg2jo"')
    idx_tutorial_root = _find(lines, '[node name="Jorvik"')
    idx_terrain = _find(lines, '[node name="Terrain3D"')
    idx_player = _find(lines, '[node name="Player"')
    idx_shield = _find(lines, '[node name="Shield_Bronze"')
    idx_weaponrack = _find(lines, '[node name="WeaponRack"')
    idx_buildings = _find(lines, '[node name="Buildings"')
    idx_props = _find(lines, '[node name="Props"')
    idx_harvest = _find(lines, '[node name="Harvestables"')
    idx_fullhelm = _find(lines, '[node name="FullHelmBronze"')

    scene_header = lines[0]
    ext_lines = lines[1:idx_gradient]
    env_subs = lines[idx_gradient:idx_dg2jo]
    props_subs = lines[idx_dg2jo:idx_tutorial_root]
    env_body_nodes = lines[idx_terrain:idx_player]
    wrap_env = '[node name="JorvikEnvironment" type="Node3D" unique_id=999000001]\n'

    env_doc = (
        f'[gd_scene format=4 uid="{UID_ENV}"]\n\n'
        + "".join(ext_lines)
        + "".join(env_subs)
        + wrap_env
        + "".join(env_body_nodes)
    )
    ENV.write_text(env_doc, encoding="utf-8")

    harvest_lines = _transform_harvest(lines[idx_harvest:idx_fullhelm])
    harv_doc = (
        f'[gd_scene format=4 uid="{UID_HARV}"]\n\n'
        + "".join(ext_lines)
        + "".join(props_subs)
        + "".join(harvest_lines)
    )
    HARV.write_text(harv_doc, encoding="utf-8")

    material_nodes = lines[idx_shield:idx_weaponrack]
    wrap_mat = '[node name="JorvikMaterials" type="Node3D" unique_id=999000002]\n'
    mat_doc = (
        f'[gd_scene format=4 uid="{UID_MAT}"]\n\n'
        + "".join(ext_lines)
        + "".join(props_subs)
        + wrap_mat
        + "".join(material_nodes)
    )
    MAT.write_text(mat_doc, encoding="utf-8")

    gear_nodes = lines[idx_weaponrack:idx_buildings] + lines[idx_fullhelm:]
    wrap_gear = '[node name="JorvikGear" type="Node3D" unique_id=999000003]\n'
    gear_doc = (
        f'[gd_scene format=4 uid="{UID_GEAR}"]\n\n'
        + "".join(ext_lines)
        + "".join(props_subs)
        + wrap_gear
        + "".join(gear_nodes)
    )
    GEAR.write_text(gear_doc, encoding="utf-8")

    new_ext = [
        f'[ext_resource type="PackedScene" uid="{UID_ENV}" path="res://world/regions/jorvik/jorvik_environment.tscn" id="jorvik_env_inst"]\n',
        f'[ext_resource type="PackedScene" uid="{UID_HARV}" path="res://world/regions/jorvik/jorvik_harvestables.tscn" id="jorvik_harv_inst"]\n',
        f'[ext_resource type="PackedScene" uid="{UID_MAT}" path="res://world/regions/jorvik/jorvik_materials.tscn" id="jorvik_mat_inst"]\n',
        f'[ext_resource type="PackedScene" uid="{UID_GEAR}" path="res://world/regions/jorvik/jorvik_gear.tscn" id="jorvik_gear_inst"]\n',
    ]
    instances_under_root = [
        '[node name="Environment" parent="." instance=ExtResource("jorvik_env_inst")]\n',
        '[node name="JorvikMaterials" parent="." instance=ExtResource("jorvik_mat_inst")]\n',
        '[node name="JorvikGear" parent="." instance=ExtResource("jorvik_gear_inst")]\n',
    ]
    harvest_under_props = (
        '[node name="Harvestables" parent="Props" instance=ExtResource("jorvik_harv_inst")]\n'
    )

    main_parts: list[str] = []
    main_parts.append(scene_header)
    main_parts.extend(ext_lines)
    main_parts.extend(new_ext)
    main_parts.extend(props_subs)
    main_parts.append(lines[idx_tutorial_root])
    main_parts.extend(instances_under_root)
    main_parts.extend(lines[idx_player:idx_shield])
    main_parts.extend(lines[idx_buildings : idx_props + 1])
    main_parts.append(harvest_under_props)
    main_parts.extend(lines[idx_props + 1 : idx_harvest])
    main_body = "".join(main_parts)
    main_body = main_body.replace(
        "day_night_controller_path = NodePath(\"../DayNightCycle\")",
        'day_night_controller_path = NodePath("../Environment/DayNightCycle")',
    )

    MAIN.write_text(main_body, encoding="utf-8")
    print("Wrote", ENV.name, HARV.name, MAT.name, GEAR.name, "and updated", MAIN.name)


if __name__ == "__main__":
    main()
