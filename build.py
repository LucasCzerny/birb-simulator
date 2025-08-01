import os
import argparse
import subprocess

project_name = os.path.basename(os.getcwd())
parser = argparse.ArgumentParser(description=f"Build {project_name}")

parser = argparse.ArgumentParser(description="Build Odin project")

parser.add_argument("--debug", action="store_true", help="Do a debug build")
parser.add_argument("--run", action="store_true", help="Run the program after building")
parser.add_argument("--pre-build", default="", metavar="<path_to_script>", help="Path to a pre-build script (make sure it's executable)")

args = parser.parse_args()

bold = "\033[1m"
clear = "\033[0m"

if args.pre_build:
    print(f"{bold}Running pre-build script: {args.pre_build}{clear}")

    script_path = "./" + args.pre_build

    if not os.path.isfile(script_path):
        print(f"{bold}Pre-build script '{args.pre_build}' not found.{clear}")
        exit(1)

    try:
        subprocess.run([script_path], check=True)
    except subprocess.CalledProcessError as e:
        print(f"{bold}Pre-build script failed with exit code {e.returncode}{clear}")
        exit(e.returncode)
    except PermissionError:
        print(f"{bold}Permission denied for the pre-build script. Please run chmod +x on it.{clear}")
        exit(1)

command = [
    "odin",
    "run" if args.run else "build",
    "src",
    f"-out=build/{project_name}",
    "-vet",
    "-strict-style",
]

if args.debug:
    command.append("-debug")

has_shared_collection = os.path.isdir("shared")
if has_shared_collection:
    command.append("-collection:shared=shared")

if not os.path.exists("build"):
    os.makedirs("build")

try:
    print(f"{bold}Running compiler: {" ".join(command)}{clear}")
    subprocess.run(command, check=True)
except subprocess.CalledProcessError as e:
    print(f"{bold}Build failed with exit code {e.returncode}{clear}")
    exit(e.returncode)
