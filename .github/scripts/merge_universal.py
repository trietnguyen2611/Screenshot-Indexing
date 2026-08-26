#!/usr/bin/env python3
import os
import shutil
import subprocess
import sys


def get_archs(path):
    """Return set of Mach-O architectures in a file, or empty set if not Mach-O."""
    if not os.path.isfile(path) or os.path.islink(path):
        return set()
    try:
        res = subprocess.run(
            ["lipo", "-archs", path], capture_output=True, text=True
        )
        if res.returncode == 0 and res.stdout.strip():
            return set(res.stdout.strip().split())
    except Exception:
        pass
    return set()


def is_macho(filepath):
    return len(get_archs(filepath)) > 0


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


def find_main_executable(app_path):
    """Find the main Mach-O executable inside a .app bundle."""
    macos_dir = os.path.join(app_path, "Contents", "MacOS")
    if not os.path.isdir(macos_dir):
        return None
    for item in os.listdir(macos_dir):
        p = os.path.join(macos_dir, item)
        if os.path.isfile(p) and not os.path.islink(p) and is_macho(p):
            return p
    return None


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

    # 0. Validate that the two builds have different architectures
    x64_main = find_main_executable(app_x64)
    arm64_main = find_main_executable(app_arm64)

    if x64_main and arm64_main:
        x64_archs = get_archs(x64_main)
        arm64_archs = get_archs(arm64_main)
        print(f"  Intel build main executable archs:          {x64_archs}")
        print(f"  Apple Silicon build main executable archs:  {arm64_archs}")

        if x64_archs and arm64_archs and x64_archs == arm64_archs:
            print(
                f"\nERROR: Both builds have identical architectures ({x64_archs})!"
            )
            print(
                "This usually means the Intel build ran on an ARM64 runner."
            )
            print(
                "The resulting 'universal' binary would only support one architecture."
            )
            sys.exit(1)

        if x64_archs and "x86_64" not in x64_archs:
            print(
                f"\nWARNING: Intel build does not contain x86_64 arch (has: {x64_archs})"
            )
        if arm64_archs and "arm64" not in arm64_archs:
            print(
                f"\nWARNING: ARM64 build does not contain arm64 arch (has: {arm64_archs})"
            )
    else:
        print("WARNING: Could not locate main executable to validate architectures.")

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

            if not os.path.exists(x64_file) or not os.path.exists(arm64_file):
                continue

            archs_x64 = get_archs(x64_file)
            archs_arm64 = get_archs(arm64_file)

            if not archs_x64 and not archs_arm64:
                continue

            # If already universal in either build
            if "x86_64" in archs_arm64 and "arm64" in archs_arm64:
                os.chmod(out_file, 0o755)
                continue
            if "x86_64" in archs_x64 and "arm64" in archs_x64:
                shutil.copy2(x64_file, out_file)
                os.chmod(out_file, 0o755)
                continue

            # If architectures are identical, no merging needed
            if archs_x64 == archs_arm64:
                os.chmod(out_file, 0o755)
                continue

            # Perform lipo merge via safe temporary file
            temp_out = out_file + ".tmp_fat"
            try:
                cmd = [
                    "lipo",
                    "-create",
                    x64_file,
                    arm64_file,
                    "-output",
                    temp_out,
                ]
                res = subprocess.run(cmd, capture_output=True, text=True)
                if res.returncode == 0:
                    os.replace(temp_out, out_file)
                    os.chmod(out_file, 0o755)
                    merged_count += 1
                    print(f"  [Universal Merged] {rel_path}")
                else:
                    print(f"  [lipo note] {rel_path}: {res.stderr.strip()}")
                    skipped_count += 1
            except Exception as e:
                print(f"  [lipo error] {rel_path}: {e}")
                skipped_count += 1
            finally:
                if os.path.exists(temp_out):
                    try:
                        os.remove(temp_out)
                    except OSError:
                        pass

    print(
        f"\nSuccessfully merged {merged_count} Mach-O binaries into Universal 2 fat binaries."
    )

    # 3. Clean all extended attributes / quarantine marks
    print("Clearing extended attributes (xattr)...")
    subprocess.run(["xattr", "-cr", app_out], check=False)

    # 4. Ad-hoc codesign the entire universal bundle
    print("Ad-hoc codesigning Universal bundle...")
    subprocess.run(
        ["codesign", "--force", "--deep", "--sign", "-", app_out], check=False
    )

    # 5. Verify main executable
    macos_dir = os.path.join(app_out, "Contents", "MacOS")
    if os.path.isdir(macos_dir):
        for item in os.listdir(macos_dir):
            p = os.path.join(macos_dir, item)
            archs = get_archs(p)
            if archs:
                print(f"\n==================================================")
                print(f"Verified executable: {item}")
                print(f"Architectures:       {' '.join(sorted(archs))}")
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
