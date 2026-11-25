import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser(description="Validate package hashes and run Lua 5.4 regressions; no game launch")
parser.add_argument("--lua", default="lua", help="Path to a Lua 5.4 interpreter")
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
payload = root / "payload"
src = payload / "ue4ss/Mods/GonFishMods/Scripts"
manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8-sig"))
for entry in manifest["Files"]:
    target = (payload / entry["Path"]).resolve()
    if not target.is_relative_to(payload.resolve()):
        raise RuntimeError("Manifest path escapes payload")
    if hashlib.sha256(target.read_bytes()).hexdigest() != entry["SHA256"]:
        raise RuntimeError("Hash mismatch: " + entry["Path"])
print("Package SHA256 checks PASS", flush=True)
def run(*arguments):
    subprocess.run([args.lua, *map(str, arguments)], check=True, cwd=root)
run("-e", 'assert(_VERSION == "Lua 5.4", "Lua 5.4 required")')
for path in sorted(payload.rglob("*.lua")):
    run("-e", "assert(loadfile(arg[0])); os.exit(0)", path)
run(root / "tests/MovementControlsRegression.lua", src / "PlayerMovement.lua", "1")
run(root / "tests/MovementAckRegression.lua", src / "PlayerMovement.lua", "1")
run(root / "tests/ChatControlFilterRegression.lua", src)
run(root / "tests/NetworkRegression.lua", src)
run(root / "tests/PublicEditionRegression.lua", src)
run(root / "tests/RemoteGamblingRegression.lua", src)
run(root / "tests/PerkSpeedRegression.lua", src / "ForceEnablePerks.lua")
# The actual loader discovers settings.lua from the same directory as modules in this harness.
with tempfile.TemporaryDirectory(prefix="gfm-loader-") as temp:
    import shutil
    stage = Path(temp)
    for path in src.glob("*.lua"):
        shutil.copy2(path, stage / path.name)
    shutil.copy2(src.parent / "settings.lua", stage / "settings.lua")
    run(root / "tests/LoaderIntegration.lua", stage, stage / "main.lua")
print("All offline checks PASS. Steam networking and game physics remain unverified.")
