#!/usr/bin/env python3
"""Bounded rendering regression sweep; run profiles sequentially per SDK."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile


PROFILES = {
    "sdlgpu": ["sdl_gpu_lifetime", "integration", "paragraph_render", "text_colors_render", "atlas_trim_render", "tilemap_render", "tile_transform_render", "tiled_render", "ldtk_render", "render_diagnostics", "compressed_textures", "dds_loading", "float_targets", "float_textures", "sdl_gpu_mipmaps", "supplied_mipmaps", "sdl_gpu_targets", "texture_data", "coverage_atlas", "dirty_regions", "viewport", "camera_render", "drawing_state"],
    "sdlgpu-window": ["sdl3_fullscreen"],
    "core": ["dds_disabled", "ldtk", "tiled_zstd", "tiled_zstd_enabled", "tiled_project", "tiled_json", "tiled_templates", "tile_objects", "tiled", "tilemap", "atlas_animation", "text_layout", "input_mapping", "collisions", "camera_math", "paragraph_layout", "paragraph_unicode", "paragraph_interaction", "text_selection", "text_colors", "text_styles", "text_bidi"],
    "sdl": ["float_targets", "dds_loading", "compressed_textures", "supplied_mipmaps", "float_textures", "texture_data", "coverage_atlas", "render_diagnostics", "ldtk_render", "integration", "api_coverage", "dirty_regions", "collision_render", "viewport", "sdl_mipmap_capability", "camera_render", "drawing_state", "paragraph_render", "text_colors_render", "atlas_trim_render", "tilemap_render", "tiled_render", "tiled_sizing_text", "tile_transform_render"],
    "software": ["float_targets", "dds_loading", "compressed_textures", "supplied_mipmaps", "float_textures", "texture_data", "coverage_atlas", "render_diagnostics", "ldtk_render", "integration", "api_coverage", "dirty_regions", "collision_render", "viewport", "sdl_mipmap_capability", "camera_render", "drawing_state", "paragraph_render", "text_colors_render", "atlas_trim_render", "tilemap_render", "tiled_render", "tiled_sizing_text", "tile_transform_render"],
    "gl": ["float_targets", "dds_loading", "compressed_textures", "supplied_mipmaps", "float_textures", "texture_data", "coverage_atlas", "render_diagnostics", "ldtk_render", "integration", "api_coverage", "dirty_regions", "viewport", "gl_targets", "gl_mipmaps", "camera_render", "drawing_state", "paragraph_render", "text_colors_render", "atlas_trim_render", "tilemap_render", "tiled_render", "tiled_sizing_text", "tile_transform_render"],
    "d3d9": ["compressed_textures", "supplied_mipmaps", "float_textures", "texture_data", "coverage_atlas", "render_diagnostics", "ldtk_render", "d3d9_render", "d3d9_targets", "d3d9_mipmaps", "viewport", "camera_render", "drawing_state", "paragraph_render", "text_colors_render", "atlas_trim_render", "tilemap_render", "tiled_render", "tiled_sizing_text", "tile_transform_render"],
    "d3d11": ["float_targets", "dds_loading", "compressed_textures", "supplied_mipmaps", "float_textures", "texture_data", "coverage_atlas", "render_diagnostics", "ldtk_render", "d3d11_render", "d3d11_targets", "d3d11_mipmaps", "viewport", "camera_render", "drawing_state", "paragraph_render", "text_colors_render", "atlas_trim_render", "tilemap_render", "tiled_render", "tiled_sizing_text", "tile_transform_render"],
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("profile", choices=PROFILES, nargs="+")
    parser.add_argument("--sdk", type=Path, default=Path(__file__).resolve().parents[3])
    parser.add_argument("--debug", action="store_true")
    parser.add_argument("--run-timeout", type=int, default=60)
    parser.add_argument("--test", action="append", choices=sorted({t for suite in PROFILES.values() for t in suite}),
                        help="Run only selected tests within each profile; repeat for several tests")
    args = parser.parse_args()
    sdk = args.sdk.resolve()
    bmk = sdk / "bin" / ("bmk.exe" if os.name == "nt" else "bmk")
    output = Path(tempfile.mkdtemp(prefix="max2d-regressions-"))
    print(f"Logs and executables: {output}", flush=True)
    results = []
    for profile in args.profile:
        selected = [test for test in PROFILES[profile] if not args.test or test in args.test]
        if not selected:
            parser.error(f"No selected tests in profile {profile}")
        environment = os.environ.copy()
        if profile == "software":
            environment.update(SDL_VIDEODRIVER="dummy", SDL_RENDER_DRIVER="software")
        for test in selected:
            name = f"{profile}-{test}"
            executable = output / (name + (".exe" if os.name == "nt" else ""))
            command = [str(bmk), "makeapp"]
            if not args.debug:
                command.append("-r")
            if profile in ("gl", "d3d9", "d3d11", "sdlgpu", "sdlgpu-window"):
                command += ["-ud", "max2d_" + ("sdlgpu" if profile == "sdlgpu-window" else profile)]
            command += ["-o", str(executable), str(sdk / "mod/max2d.mod/tests" / (test + ".bmx"))]
            result = {"profile": profile, "test": test, "configuration": "debug" if args.debug else "release"}
            try:
                with (output / (name + "-build.log")).open("wb") as log:
                    subprocess.run(command, cwd=sdk, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=600)
                with (output / (name + "-run.log")).open("wb") as log:
                    run_command = [str(executable)]
                    if test in ("ldtk", "ldtk_render"):
                        run_command.append(str(sdk / "mod/max2d.mod/tests/data/ldtk"))
                    if test in ("tiled_zstd", "tiled_zstd_enabled", "tiled_project", "tiled_json", "tiled_templates", "tile_objects", "tiled", "tiled_render", "tiled_sizing_text"):
                        run_command.append(str(sdk / "mod/max2d.mod/tests/data/tiled"))
                    if test == "atlas_animation":
                        run_command.append(str(output / (name + "-package")))
                    subprocess.run(run_command, cwd=output, env=environment, stdout=log,
                                   stderr=subprocess.STDOUT, check=True, timeout=args.run_timeout)
                text = (output / (name + "-run.log")).read_text(errors="replace")
                if "passed" not in text.lower() or "FAILED:" in text:
                    raise RuntimeError("Missing success message or explicit failure; inspect run log")
                result["status"] = "PASS"
            except (OSError, subprocess.SubprocessError, RuntimeError) as error:
                result.update(status="FAIL", error=str(error))
            results.append(result)
            (output / "results.json").write_text(json.dumps(results, indent=2) + "\n")
            print(f"{name}: {result['status']}", flush=True)
            if result["status"] == "FAIL":
                print(result["error"], flush=True)
                return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
