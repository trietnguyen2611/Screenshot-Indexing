#!/usr/bin/env python3
import os
import shutil
import subprocess
import sys


def is_macho(filepath):
    """Check if file is a valid Mach-O binary using macOS native lipo tool."""
    if not os.path.isfile(filepath) or os.path.islink(filepath):
        return False
    try:
        res = subprocess.run(
            ["lipo", "-info", filepath], capture_output=True, text=True
        )
        return res.returncode == 0
    except Exception:
        return False


def resolve_app_path(path):
    """Find the actual app folder containing Contents/."""
    if os.path.isdir(os.path.join(path, "Contents")):
        return path
    if os.path.isdir(path):
        for item in os.listdir(path):
            sub = os.path.join(path, item)
            if item.endswith(".app") and os.path.isdir(
                os.path.join(sub, "Contents")
            ):
                return sub
            if os.path.isdir(os.path.join(sub, "Contents")):
                return sub
    return path


def merge_apps(app_x64_in, app_arm64_in, app_out):
    app_x64 = resolve_app_path(app_x64_in)
    app_arm64 = resolve_app_path(app_arm64_in)

    print("==================================================")
    print("Creating Universal 2 App Bundle:")
    print(f"  Intel source (x86_64):        {app_x64}")
    print(f"  Apple Silicon source (arm64): {app_arm64}")
    print(f"  Output destination:           {app_out}")
    print("==================================================")

    if not os.path.isdir(os.path.join(app_x64, "Contents")):
        print(f"Error: Intel bundle invalid at '{app_x64}'")
        sys.exit(1)
    if not os.path.isdir(os.path.join(app_arm64, "Contents")):
        print(f"Error: Apple Silicon bundle invalid at '{app_arm64}'")
        sys.exit(1)

    if os.path.exists(app_out):
        shutil.rmtree(app_out)

    # 1. Base copy from Apple Silicon bundle
    print("Copying base application structure from Apple Silicon build...")
    shutil.copytree(app_arm64, app_out, symlinks=True)

    # 2. Walk and merge all Mach-O binaries using lipo
    merged_count = 0
    skipped_count = 0

    for root, dirs, files in os.walk(app_out):
        for f in files:
            out_file = os.path.join(root, f)
            if os.path.islink(out_file):
                continue

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
                            capture_output=True,
                        )
                        # Ensure executable permissions
                        os.chmod(out_file, 0o755)
                        merged_count += 1
                        print(f"  [Universal Merged] {rel_path}")
                    except subprocess.CalledProcessError as e:
                        print(
                            f"  [Warning] lipo failed on {rel_path}: {e.stderr.decode() if isinstance(e.stderr, bytes) else e.stderr}"
                        )
                else:
                    print(f"  [Single Arch] {rel_path} (kept from ARM64)")
                    skipped_count += 1

    print(
        f"\nSuccessfully merged {merged_count} Mach-O binaries into Universal 2 fat binaries."
    )

    # 3. Clean all extended attributes / quarantine marks
    print("Clearing extended attributes (xattr)...")
    subprocess.run(["xattr", "-cr", app_out], check=False)

    # 4. Ad-hoc codesign the entire universal bundle
    print("Ad-hoc codesigning Universal bundle...")
    codesign_res = subprocess.run(
        ["codesign", "--force", "--deep", "--sign", "-", app_out],
        capture_output=True,
        text=True,
    )
    if codesign_res.returncode != 0:
        print(f"Codesign output: {codesign_res.stdout}")
        print(f"Codesign error: {codesign_res.stderr}")
        print("Retrying codesign without --deep on internal components...")
        for root, dirs, files in os.walk(app_out):
            for f in files:
                p = os.path.join(root, f)
                if is_macho(p):
                    subprocess.run(
                        ["codesign", "--force", "--sign", "-", p], check=False
                    )
        subprocess.run(
            ["codesign", "--force", "--sign", "-", app_out], check=True
        )

    # 5. Verify main executable has both architectures
    macos_dir = os.path.join(app_out, "Contents", "MacOS")
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
                print(f"\n==================================================")
                print(f"Verified executable: {item}")
                print(f"Architectures:       {archs}")
                print(f"==================================================")
                if "x86_64" in archs and "arm64" in archs:
                    print("SUCCESS: Verified Universal 2 application created!")
                else:
                    print(
                        f"Notice: Main executable architecture status: {archs}"
                    )

    print("Universal packaging complete!")


if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Usage: merge_universal.py <app_x64> <app_arm64> <app_out>")
        sys.exit(1)
    merge_apps(sys.argv[1], sys.argv[2], sys.argv[3])
