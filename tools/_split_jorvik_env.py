"""One-off helper: split environment nodes into jorvik_environment.tscn."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAIN = ROOT / "world/regions/jorvik/jorvik.tscn"
ENV = ROOT / "world/regions/jorvik/jorvik_environment.tscn"


def main() -> None:
    lines = MAIN.read_text(encoding="utf-8").splitlines(keepends=True)
    idx_hdr_end = next(i for i, l in enumerate(lines) if l.startswith("[sub_resource type=\"Gradient\""))
    # Environment uses sub_resources from Gradient through Environment_main (inclusive)
    idx_std_dg2jo = next(
        i for i, l in enumerate(lines) if l.startswith("[sub_resource type=\"StandardMaterial3D\" id=\"StandardMaterial3D_dg2jo\"]")
    )
    env_sub_lines = lines[idx_hdr_end:idx_std_dg2jo]
    idx_terrain = next(i for i, l in enumerate(lines) if l.startswith("[node name=\"Terrain3D\""))
    idx_player = next(i for i, l in enumerate(lines) if l.startswith("[node name=\"Player\""))
    env_node_lines = lines[idx_terrain:idx_player]
    ext_lines = lines[:idx_hdr_end]
    hdr = "".join(ext_lines)
    body = "".join(env_sub_lines + env_node_lines)
    out = (
        '[gd_scene format=4 uid="uid://c8jorvikenv1"]\n\n'
        + hdr
        + "\n"
        + body
    )
    ENV.write_text(out, encoding="utf-8")
    print("Wrote", ENV, "bytes", len(out))


if __name__ == "__main__":
    main()
