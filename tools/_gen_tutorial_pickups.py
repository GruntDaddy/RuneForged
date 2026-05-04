"""One-off generator for world/pickups wrapper scenes (run from repo root)."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "world" / "pickups"


def write_scene(
    filename: str,
    item_id: str,
    visual: str,
    node_name: str,
    quantity: int | None = None,
    visual_transform: str = "Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0)",
) -> None:
    qty_line = f"quantity = {quantity}\n" if quantity is not None else ""
    content = f"""[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://world/item_pickup_interactable.gd" id="1_pickup_script"]
[ext_resource type="PackedScene" path="{visual}" id="2_visual"]

[sub_resource type="CapsuleShape3D" id="CapsuleShape3D_pickup"]
radius = 0.28
height = 0.8

[node name="{node_name}" type="Node3D"]
script = ExtResource("1_pickup_script")
item_id = "{item_id}"
{qty_line}[node name="Visual" parent="." instance=ExtResource("2_visual")]
transform = {visual_transform}

[node name="StaticBody3D" type="StaticBody3D" parent="."]
collision_layer = 2

[node name="CollisionShape3D" type="CollisionShape3D" parent="StaticBody3D"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.4, 0)
shape = SubResource("CapsuleShape3D_pickup")
"""
    path = ROOT / filename
    path.write_text(content, encoding="utf-8")
    print("Wrote", path.relative_to(ROOT.parent.parent))


def main() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    scenes: list[tuple[str, str, str, str, int | None]] = [
        ("tool_hammer_pickup.tscn", "tool_hammer", "res://entities/equipment/tools/hammer.tscn", "ToolHammerPickup", None),
        ("pickaxe_bronze_pickup.tscn", "pickaxe_bronze", "res://entities/equipment/tools/pickaxe_bronze.tscn", "PickaxeBronzePickup", None),
        ("hatchet_bronze_pickup.tscn", "hatchet_bronze", "res://entities/equipment/tools/hatchet_bronze.tscn", "HatchetBronzePickup", None),
        ("hatchet_basic_pickup.tscn", "hatchet_basic", "res://entities/equipment/tools/hatchet_basic.tscn", "HatchetBasicPickup", None),
        ("sword_1h_bronze_pickup.tscn", "sword_1h_bronze", "res://entities/equipment/weapons/melee/1h_short_sword_bronze.tscn", "Sword1hBronzePickup", None),
        ("dagger_bronze_pickup.tscn", "dagger_bronze", "res://entities/equipment/weapons/melee/dagger_bronze.tscn", "DaggerBronzePickup", None),
        ("armor_head_bronze_pickup.tscn", "armor_head_bronze", "res://entities/equipment/armor/helmet/full_helm_bronze.tscn", "ArmorHeadBronzePickup", None),
        ("armor_chest_bronze_pickup.tscn", "armor_chest_bronze", "res://entities/equipment/armor/platebody/platebody_bronze.tscn", "ArmorChestBronzePickup", None),
        ("armor_legs_bronze_pickup.tscn", "armor_legs_bronze", "res://entities/equipment/armor/platelegs/platelegs_bronze.tscn", "ArmorLegsBronzePickup", None),
        ("shield_bronze_pickup.tscn", "shield_bronze", "res://entities/equipment/shields/shield_bronze.tscn", "ShieldBronzePickup", None),
        ("quiver_common_pickup.tscn", "quiver_common", "res://entities/equipment/accessories/quivers/quiver_common.tscn", "QuiverCommonPickup", None),
        ("bow_short_common_pickup.tscn", "bow_short_common", "res://entities/equipment/weapons/ranged/bow_short_common.tscn", "BowShortCommonPickup", None),
        ("ammo_arrow_bronze_pickup.tscn", "ammo_arrow_bronze", "res://entities/equipment/weapons/ranged/arrow_bronze.tscn", "AmmoArrowBronzePickup", None),
        ("ammo_arrow_bronze_bundle_pickup.tscn", "ammo_arrow_bronze", "res://entities/equipment/weapons/ranged/arrow_bundle_bronze.tscn", "AmmoArrowBronzeBundlePickup", 20),
        ("ammo_arrow_iron_pickup.tscn", "ammo_arrow_iron", "res://entities/equipment/weapons/ranged/arrow_iron.tscn", "AmmoArrowIronPickup", None),
        ("ammo_arrow_iron_bundle_pickup.tscn", "ammo_arrow_iron", "res://entities/equipment/weapons/ranged/arrow_bundle_iron.tscn", "AmmoArrowIronBundlePickup", 20),
        ("ammo_arrow_common_pickup.tscn", "ammo_arrow_common", "res://entities/equipment/weapons/ranged/arrow_common.tscn", "AmmoArrowCommonPickup", None),
        ("ammo_arrow_common_bundle_pickup.tscn", "ammo_arrow_common", "res://entities/equipment/weapons/ranged/arrow_bundle_common.tscn", "AmmoArrowCommonBundlePickup", 20),
        ("ingot_copper_pickup.tscn", "ingot_copper", "res://entities/props/static/copper_bar.tscn", "IngotCopperPickup", None),
        ("ore_copper_pickup.tscn", "ore_copper", "res://entities/props/static/copper_nuggets.tscn", "OreCopperPickup", None),
        ("ingot_iron_pickup.tscn", "ingot_iron", "res://entities/props/static/iron_bar.tscn", "IngotIronPickup", None),
        ("ore_iron_pickup.tscn", "ore_iron", "res://entities/props/static/iron_nuggets.tscn", "OreIronPickup", None),
        ("ingot_silver_pickup.tscn", "ingot_silver", "res://entities/props/static/silver_bar.tscn", "IngotSilverPickup", None),
        ("ore_silver_pickup.tscn", "ore_silver", "res://entities/props/static/silver_nuggets.tscn", "OreSilverPickup", None),
        ("tool_torch_pickup.tscn", "tool_torch", "res://assets/kaykit/items/torch.gltf", "ToolTorchPickup", None),
        ("tool_torch_burnt_pickup.tscn", "tool_torch_burnt", "res://assets/kaykit/items/torch_burnt.gltf", "ToolTorchBurntPickup", None),
        ("stone_block_pickup.tscn", "stone_block", "res://assets/kaykit/resources/Stone_Brick.gltf", "StoneBlockPickup", None),
        ("logs_pickup.tscn", "logs", "res://assets/kaykit/items/log_split.gltf", "LogsPickup", None),
        ("wood_planks_pickup.tscn", "wood_planks", "res://assets/kaykit/resources/Wood_Plank_B.gltf", "WoodPlanksPickup", None),
    ]
    for fn, iid, vis, nm, qty in scenes:
        write_scene(fn, iid, vis, nm, qty)


if __name__ == "__main__":
    main()
