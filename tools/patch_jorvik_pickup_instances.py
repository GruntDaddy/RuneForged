"""Rewire tutorial isle scenes to world/pickup wrapper scenes; strip duplicate pickup scripts/collision."""
from __future__ import annotations

import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]

# item_pickup_interactable.gd ExtResource ids used across tutorial scenes
_PICKUP_SCRIPT_IDS = r"9_8pv40|70_item_pickup|7_gpvjm"


def strip_pickup_children(text: str) -> str:
    """Remove script + item_id + optional quantity + root StaticBody3D subtree after pickup instance nodes."""
    pattern = re.compile(
        rf"\nscript = ExtResource\(\"({_PICKUP_SCRIPT_IDS})\"\)\n"
        r'(?:item_id = "[^"]+"\n)?'
        r"(?:quantity = \d+\n)?"
        r"\n?"
        r'\[node name="StaticBody3D" type="StaticBody3D"[^\]]+\]\n'
        r"(?:[^\n]*\n)*?"
        r'shape = SubResource\("[^"]+"\)\n',
        re.MULTILINE,
    )
    return pattern.sub("\n", text)


def patch_ext_resources_tutorial_isle(text: str) -> str:
    repl = {
        'path="res://entities/equipment/tools/hammer.tscn" id="8_rwr6f"': 'path="res://world/pickups/tool_hammer_pickup.tscn" id="8_rwr6f"',
        'path="res://entities/equipment/tools/pickaxe_bronze.tscn" id="10_3x6k3"': 'path="res://world/pickups/pickaxe_bronze_pickup.tscn" id="10_3x6k3"',
        'path="res://entities/equipment/tools/hatchet_bronze.tscn" id="11_ad2jt"': 'path="res://world/pickups/hatchet_bronze_pickup.tscn" id="11_ad2jt"',
        'path="res://entities/equipment/weapons/melee/1h_short_sword_bronze.tscn" id="12_tc0ig"': 'path="res://world/pickups/sword_1h_bronze_pickup.tscn" id="12_tc0ig"',
        'path="res://entities/equipment/weapons/melee/dagger_bronze.tscn" id="13_jms13"': 'path="res://world/pickups/dagger_bronze_pickup.tscn" id="13_jms13"',
        'path="res://entities/equipment/armor/helmet/full_helm_bronze.tscn" id="14_8jkdj"': 'path="res://world/pickups/armor_head_bronze_pickup.tscn" id="14_8jkdj"',
        'path="res://entities/equipment/armor/platebody/platebody_bronze.tscn" id="15_dbqg5"': 'path="res://world/pickups/armor_chest_bronze_pickup.tscn" id="15_dbqg5"',
        'path="res://entities/equipment/armor/platelegs/platelegs_bronze.tscn" id="16_ypcn4"': 'path="res://world/pickups/armor_legs_bronze_pickup.tscn" id="16_ypcn4"',
        'path="res://entities/equipment/accessories/quivers/quiver_common.tscn" id="18_euhjt"': 'path="res://world/pickups/quiver_common_pickup.tscn" id="18_euhjt"',
        'path="res://entities/equipment/weapons/ranged/bow_short_common.tscn" id="19_gluyn"': 'path="res://world/pickups/bow_short_common_pickup.tscn" id="19_gluyn"',
        'path="res://entities/equipment/weapons/ranged/arrow_bundle_bronze.tscn" id="20_gvq3c"': 'path="res://world/pickups/ammo_arrow_bronze_bundle_pickup.tscn" id="20_gvq3c"',
        'path="res://entities/equipment/weapons/ranged/arrow_bronze.tscn" id="21_mac2j"': 'path="res://world/pickups/ammo_arrow_bronze_pickup.tscn" id="21_mac2j"',
        'path="res://entities/equipment/weapons/ranged/arrow_bundle_iron.tscn" id="22_r30qo"': 'path="res://world/pickups/ammo_arrow_iron_bundle_pickup.tscn" id="22_r30qo"',
        'path="res://entities/equipment/weapons/ranged/arrow_iron.tscn" id="23_4uh62"': 'path="res://world/pickups/ammo_arrow_iron_pickup.tscn" id="23_4uh62"',
        'path="res://entities/equipment/weapons/ranged/arrow_common.tscn" id="24_71eoc"': 'path="res://world/pickups/ammo_arrow_common_pickup.tscn" id="24_71eoc"',
        'path="res://entities/equipment/weapons/ranged/arrow_bundle_common.tscn" id="25_lfcqd"': 'path="res://world/pickups/ammo_arrow_common_bundle_pickup.tscn" id="25_lfcqd"',
        'path="res://entities/equipment/accessories/backpacks/backpack_engineer.tscn" id="28_whsid"': 'path="res://world/pickups/backpack_large_pickup.tscn" id="28_whsid"',
    }
    for a, b in repl.items():
        text = text.replace(a, b)
    return text


def patch_ext_resources_tutorial_isle_gear(text: str) -> str:
    repl = {
        'path="res://entities/equipment/accessories/backpacks/backpack_engineer.tscn" id="26_w8lkd"': 'path="res://world/pickups/backpack_large_pickup.tscn" id="26_w8lkd"',
        'path="res://entities/equipment/weapons/melee/dagger_bronze.tscn" id="45_txrpn"': 'path="res://world/pickups/dagger_bronze_pickup.tscn" id="45_txrpn"',
        'path="res://entities/equipment/tools/pickaxe_bronze.tscn" id="46_n5r66"': 'path="res://world/pickups/pickaxe_bronze_pickup.tscn" id="46_n5r66"',
        'path="res://entities/equipment/armor/helmet/full_helm_bronze.tscn" id="60_0jevs"': 'path="res://world/pickups/armor_head_bronze_pickup.tscn" id="60_0jevs"',
        'path="res://entities/equipment/armor/platebody/platebody_bronze.tscn" id="61_q4s3i"': 'path="res://world/pickups/armor_chest_bronze_pickup.tscn" id="61_q4s3i"',
        'path="res://entities/equipment/armor/platelegs/platelegs_bronze.tscn" id="62_txrpn"': 'path="res://world/pickups/armor_legs_bronze_pickup.tscn" id="62_txrpn"',
        'path="res://entities/equipment/tools/hatchet_bronze.tscn" id="63_n5r66"': 'path="res://world/pickups/hatchet_bronze_pickup.tscn" id="63_n5r66"',
        'path="res://entities/equipment/tools/hammer.tscn" id="64_s80k1"': 'path="res://world/pickups/tool_hammer_pickup.tscn" id="64_s80k1"',
        'path="res://entities/equipment/accessories/quivers/quiver_common.tscn" id="68_4b6nw"': 'path="res://world/pickups/quiver_common_pickup.tscn" id="68_4b6nw"',
        'path="res://entities/equipment/weapons/melee/1h_short_sword_bronze.tscn" id="69_3vu1e"': 'path="res://world/pickups/sword_1h_bronze_pickup.tscn" id="69_3vu1e"',
        'path="res://entities/equipment/weapons/ranged/bow_short_common.tscn" id="70_bq618"': 'path="res://world/pickups/bow_short_common_pickup.tscn" id="70_bq618"',
        'path="res://entities/equipment/weapons/ranged/arrow_bundle_bronze.tscn" id="74_v8n0v"': 'path="res://world/pickups/ammo_arrow_bronze_bundle_pickup.tscn" id="74_v8n0v"',
        'path="res://entities/equipment/weapons/ranged/arrow_bronze.tscn" id="75_3nag6"': 'path="res://world/pickups/ammo_arrow_bronze_pickup.tscn" id="75_3nag6"',
        'path="res://entities/equipment/weapons/ranged/arrow_bundle_iron.tscn" id="76_ado1i"': 'path="res://world/pickups/ammo_arrow_iron_bundle_pickup.tscn" id="76_ado1i"',
        'path="res://entities/equipment/weapons/ranged/arrow_iron.tscn" id="77_6kivj"': 'path="res://world/pickups/ammo_arrow_iron_pickup.tscn" id="77_6kivj"',
        'path="res://entities/equipment/weapons/ranged/arrow_common.tscn" id="78_7spe6"': 'path="res://world/pickups/ammo_arrow_common_pickup.tscn" id="78_7spe6"',
        'path="res://entities/equipment/weapons/ranged/arrow_bundle_common.tscn" id="79_hloqf"': 'path="res://world/pickups/ammo_arrow_common_bundle_pickup.tscn" id="79_hloqf"',
    }
    for a, b in repl.items():
        text = text.replace(a, b)
    return text


def insert_shield_ext_main(text: str) -> str:
    needle = '[ext_resource type="PackedScene" uid="uid://cwiegunolb0ge" path="res://world/pickups/backpack_small_pickup.tscn" id="29_0jevs"]\n'
    insert = needle + '[ext_resource type="PackedScene" path="res://world/pickups/shield_bronze_pickup.tscn" id="30_shield_pickup"]\n'
    if "30_shield_pickup" in text:
        return text
    return text.replace(needle, insert)


def insert_shield_ext_gear(text: str) -> str:
    needle = '[ext_resource type="PackedScene" uid="uid://cwiegunolb0ge" path="res://world/pickups/backpack_small_pickup.tscn" id="26_c5h0b"]\n'
    insert = needle + '[ext_resource type="PackedScene" path="res://world/pickups/shield_bronze_pickup.tscn" id="80_shield_pickup"]\n'
    if "80_shield_pickup" in text:
        return text
    return text.replace(needle, insert)


def replace_shield_block_main(text: str) -> str:
    old = r'\[node name="Shield_Bronze" type="Node3D" parent="TutorialIsleGear" unique_id=180006820\][\s\S]*?\[node name="Backpack_Large"'
    new = (
        '[node name="Shield_Bronze" parent="TutorialIsleGear" unique_id=180006820 instance=ExtResource("30_shield_pickup")]\n'
        "transform = Transform3D(0.9809028, -0.11814359, 0.15450668, 0.0028403942, 0.8029955, 0.59597826, -0.1944792, -0.58415765, 0.7879962, 203.20865, 10.309912, 390.1378)\n"
        "\n"
        '[node name="Backpack_Large"'
    )
    return re.sub(old, new, text, count=1)


def replace_shield_block_gear(text: str) -> str:
    old = r'\[node name="Shield_Bronze" type="Node3D" parent="\." unique_id=1774684574\][\s\S]*?\[node name="Backpack_Large"'
    new = (
        '[node name="Shield_Bronze" parent="." unique_id=1774684574 instance=ExtResource("80_shield_pickup")]\n'
        "transform = Transform3D(0.9809028, -0.11814359, 0.15450668, 0.0028403942, 0.8029955, 0.59597826, -0.1944792, -0.58415765, 0.7879962, 203.20865, 10.309912, 390.1378)\n"
        "\n"
        '[node name="Backpack_Large"'
    )
    return re.sub(old, new, text, count=1)


def patch_materials_ext(text: str) -> str:
    repl = {
        'path="res://entities/props/static/copper_bar.tscn" id="20_3vu1e"': 'path="res://world/pickups/ingot_copper_pickup.tscn" id="20_3vu1e"',
        'path="res://entities/props/static/copper_nuggets.tscn" id="23_fq2qr"': 'path="res://world/pickups/ore_copper_pickup.tscn" id="23_fq2qr"',
        'path="res://entities/props/static/iron_bar.tscn" id="27_rx877"': 'path="res://world/pickups/ingot_iron_pickup.tscn" id="27_rx877"',
        'path="res://entities/props/static/iron_nuggets.tscn" id="28_my7f7"': 'path="res://world/pickups/ore_iron_pickup.tscn" id="28_my7f7"',
        'path="res://entities/props/static/silver_bar.tscn" id="29_ts002"': 'path="res://world/pickups/ingot_silver_pickup.tscn" id="29_ts002"',
        'path="res://entities/props/static/silver_nuggets.tscn" id="30_dr1td"': 'path="res://world/pickups/ore_silver_pickup.tscn" id="30_dr1td"',
        'path="res://assets/kaykit/resources/Stone_Brick.gltf" id="58_86282"': 'path="res://world/pickups/stone_block_pickup.tscn" id="58_86282"',
        'path="res://assets/kaykit/items/log_split.gltf" id="35_3nag6"': 'path="res://world/pickups/logs_pickup.tscn" id="35_3nag6"',
        'path="res://assets/kaykit/resources/Wood_Plank_C.gltf" id="66_t2imw"': 'path="res://world/pickups/wood_planks_pickup.tscn" id="66_t2imw"',
        'path="res://assets/kaykit/resources/Wood_Plank_B.gltf" id="67_81cpb"': 'path="res://world/pickups/wood_planks_pickup.tscn" id="67_81cpb"',
        'path="res://assets/kaykit/resources/Wood_Plank_A.gltf" id="68_kgvtc"': 'path="res://world/pickups/wood_planks_pickup.tscn" id="68_kgvtc"',
    }
    for a, b in repl.items():
        text = text.replace(a, b)
    return text


def patch_props_scene(text: str) -> str:
    text = text.replace(
        'path="res://entities/equipment/tools/hatchet_basic.tscn" id="6_4g0lo"',
        'path="res://world/pickups/hatchet_basic_pickup.tscn" id="6_4g0lo"',
    )
    text = text.replace(
        'path="res://assets/kaykit/items/torch.gltf" id="8_tvnjf"',
        'path="res://world/pickups/tool_torch_pickup.tscn" id="8_tvnjf"',
    )
    text = text.replace(
        'path="res://assets/kaykit/items/torch_burnt.gltf" id="9_i2gn1"',
        'path="res://world/pickups/tool_torch_burnt_pickup.tscn" id="9_i2gn1"',
    )
    return text


def main() -> None:
    main_isle = REPO / "world/regions/tutorial_isle/tutorial_isle.tscn"
    t = main_isle.read_text(encoding="utf-8")
    t = patch_ext_resources_tutorial_isle(t)
    t = insert_shield_ext_main(t)
    t = replace_shield_block_main(t)
    t = strip_pickup_children(t)
    main_isle.write_text(t, encoding="utf-8")
    print("Patched", main_isle.relative_to(REPO))

    gear = REPO / "world/regions/tutorial_isle/tutorial_isle_gear.tscn"
    t2 = gear.read_text(encoding="utf-8")
    t2 = patch_ext_resources_tutorial_isle_gear(t2)
    t2 = insert_shield_ext_gear(t2)
    t2 = replace_shield_block_gear(t2)
    t2 = strip_pickup_children(t2)
    gear.write_text(t2, encoding="utf-8")
    print("Patched", gear.relative_to(REPO))

    mats = REPO / "world/regions/tutorial_isle/tutorial_isle_materials.tscn"
    t3 = mats.read_text(encoding="utf-8")
    t3 = patch_materials_ext(t3)
    t3 = strip_pickup_children(t3)
    mats.write_text(t3, encoding="utf-8")
    print("Patched", mats.relative_to(REPO))

    props = REPO / "world/regions/tutorial_isle/tutorial_isle_props.tscn"
    t4 = props.read_text(encoding="utf-8")
    t4 = patch_props_scene(t4)
    t4 = strip_pickup_children(t4)
    props.write_text(t4, encoding="utf-8")
    print("Patched", props.relative_to(REPO))


if __name__ == "__main__":
    main()
