#!/usr/bin/env python3
import os
import shutil
import subprocess
import sys


def is_macho(filepath):
    if not os.path.isfile(filepath) or os.path.islink(filepath):
        return False
    try:
        with open(filepath, "rb") as f:
            magic = f.read(4)
            return magic in [
                b"\xfe\xed\xfa\xce",
                b"\xce\xfa\xed\xfe",
                b"\xfe\xed\xfa\xcf",
                b"\xcf\xfa\xed\xfe",
                b"\xca\xfe\xba\xbe",
                b"\xbe\xba\xfe\xca",
            ]
    except Exception:
        return False


def resolve_app_path(path):
    if os.path.exists(path) and path.endswith(".app"):
        return path
    if os.path.isdir(path):
        for item in os.listdir(path):
            if item.endswith(".app"):
                return os.path.join(path, item)
    return path


def merge_apps(app_x64_in, app_arm64_in, app_out):
    app_x64 = resolve_app_path(app_x64_in)
    app_arm64 = resolve_app_path(app_arm64_in)

    print(f"Creating Universal bundle from:")
    print(f"  Intel (x86_64):        {app_x64}")
    print(f"  Apple Silicon (arm64): {app_arm64}")
    print(f"  Output (Universal):    {app_out}")

    if not os.path.exists(app_x64):
        print(f"Error: Intel .app not found at {app_x64} (input: {app_x64_in})")
        sys.exit(1)
    if not os.path.exists(app_arm64):
        print(
            f"Error: Apple Silicon .app not found at {app_arm64} (input: {app_arm64_in})"
        )
        sys.exit(1)

    if os.path.exists(app_out):
        shutil.rmtree(app_out)

    # 1. Base copy from arm64 bundle
    shutil.copytree(app_arm64, app_out, symlinks=True)

    # 2. Walk and merge all Mach-O binaries using lipo
    merged_count = 0
    for root, dirs, files in os.walk(app_out):
        for f in files:
            out_file = os.path.join(root, f)
            rel_path = os.path.relpath(out_file, app_out)
            x64_file = os.path.join(app_x64, rel_path)
            arm64_file = os.path.join(app_arm64, rel_path)

            if is_macho(out_file):
                if os.path.exists(x64_file) and is_macho(x64_file):
                    try:
                        subprocess.run(
                            [
                                "lipo",
                                "-create",
                                x64_file,
                                arm64_file,
                                "-output",
                                out_file,
                            ],
                            check=True,
                        )
                        merged_count += 1
                    except subprocess.CalledProcessError as e:
                        print(
                            f"Warning: lipo failed on {rel_path}, keeping ARM64 version: {e}"
                        )
                else:
                    print(
                        f"Note: {rel_path} only present/Mach-O in ARM64 bundle"
                    )

    print(
        f"Merged {merged_count} Mach-O binaries into Universal fat binaries."
    )

    # 3. Ensure all Mach-O files in MacOS/ have executable permissions
    macos_dir = os.path.join(app_out, "Contents", "MacOS")
    if os.path.isdir(macos_dir):
        for item in os.listdir(macos_dir):
            p = os.path.join(macos_dir, item)
            if is_macho(p):
                os.chmod(p, 0o755)

    # 4. Ad-hoc codesign the entire universal bundle
    print("Re-signing Universal app bundle...")
    subprocess.run(
        ["codesign", "--force", "--deep", "--sign", "-", app_out], check=True
    )

    # 5. Verify main executable has both architectures
    if os.path.isdir(macos_dir):
        for item in os.listdir(macos_dir):
            p = os.path.join(macos_dir, item)
            if is_macho(p):
                res = subprocess.run(
                    ["lipo", "-archs", p],
                    capture_output=True,
                    text=True,
                    check=True,
                )
                archs = res.stdout.strip()
                print(f"Verified {item} architectures: {archs}")
                if "x86_64" in archs and "arm64" in archs:
                    print(
                        f"Success: {item} is a verified Universal 2 binary!"
                    )
                else:
                    print(f"Warning: Expected x86_64 and arm64, got: {archs}")

    print("Universal .app successfully created!")


if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Usage: merge_universal.py <app_x64> <app_arm64> <app_out>")
        sys.exit(1)
    merge_apps(sys.argv[1], sys.argv[2], sys.argv[3])
