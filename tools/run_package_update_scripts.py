#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3

import os
import subprocess
import sys
from pathlib import Path


def find_package_scripts(package_name=None):
    """Find all package-specific update scripts"""
    scripts = []
    pkgs_root = Path("pkgs")

    # Walk through all package directories
    for package_dir in pkgs_root.rglob("*"):
        if package_dir.is_dir():
            # If package_name is specified, only look for that package
            if package_name and package_dir.name != package_name:
                continue

            # Look for update script in each package directory
            update_script = package_dir / "myupdate.py"
            if update_script.exists():
                scripts.append((package_dir.name, str(update_script)))

    return scripts


def run_package_script(script_path):
    """Run a specific package update script"""
    try:
        print(f"Running package update script: {script_path}")
        result = subprocess.run([sys.executable, script_path], text=True)

        if result.returncode != 0:
            print(
                f"Error running script {script_path} (exit code: {result.returncode})"
            )
            return False

        print(f"Successfully ran script {script_path}")
        return True

    except Exception as e:
        print(f"Exception occurred while running {script_path}: {e}")
        return False


def main():
    # Check if we're running in scripts-only mode
    scripts_only = "--scripts-only" in sys.argv
    args = [arg for arg in sys.argv if arg != "--scripts-only"]

    # Check if a specific package was requested
    package_name = None
    if len(args) > 1:
        package_name = args[1]

    if scripts_only:
        if package_name:
            print(f"Running update scripts for package: {package_name}")
        else:
            print("Running update scripts for all packages...")
    else:
        if package_name:
            print(f"Starting global package update script for package: {package_name}")
        else:
            print("Starting global package update script for all packages...")

    # Find package-specific scripts
    package_scripts = find_package_scripts(package_name)

    if not package_scripts:
        if package_name:
            print(f"No update script found for package '{package_name}'")
        else:
            print("No package update scripts found")
    else:
        for package_name, script_path in package_scripts:
            print(
                f"Found update script for package '{package_name}' at '{script_path}'"
            )
            # Run the package's myupdate.py script
            run_package_script(script_path)


if __name__ == "__main__":
    main()
