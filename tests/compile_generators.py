"""Compile fixtures left by generators_integration.lua; no project builds or restore."""
from pathlib import Path
import re
import shutil
import subprocess
import sys

root = Path(sys.argv[1]).resolve()
sources = sorted(root.rglob("*.cs"))
assert sources, "Run generators_integration.lua with NVIM_GENERATOR_TEST_ROOT first"

if shutil.which("dotnet"):
    sdks = subprocess.check_output(["dotnet", "--list-sdks"], text=True).splitlines()
    assert sdks, "No .NET SDK installed"
    version, base = re.fullmatch(r"(\S+) \[(.+)]", sdks[-1]).groups()
    sdk = Path(base) / version
    refs = list((Path(base).parent / "packs/Microsoft.NETCore.App.Ref").glob("*/ref/net*"))
    assert refs, "No .NET reference assemblies installed"
    refs.sort(key=lambda p: tuple(map(int, re.findall(r"\d+", str(p.relative_to(Path(base).parent))))))
    response = root / "compile.rsp"
    lines = ["-nologo", "-target:library", "-langversion:11", "-warnaserror+", f'-out:"{root / "Generated.dll"}"']
    lines += [f'-reference:"{p}"' for p in sorted(refs[-1].glob("*.dll"))]
    lines += [f'"{p}"' for p in sources]
    response.write_text("\n".join(lines) + "\n")
    subprocess.run(["dotnet", str(sdk / "Roslyn/bincore/csc.dll"), f"@{response}"], check=True)
    print(f"PASS: C# compiler, {len(sources)} files (including the modifier matrix), C# 11")
else:
    print("SKIP: C# compilation (dotnet SDK is not installed)")

if shutil.which("g++"):
    cpp = root / "cpp"
    subprocess.run(["g++", "-std=c++20", "-Wall", "-Wextra", "-Werror", "-fsyntax-only",
                    str(cpp / "compile.cpp"), str(cpp / "Player.cpp"),
                    str(cpp / "Engine/src/Math/BothStruct.cpp")], check=True)
    print("PASS: C++ compiler, templates and abstract interface")
    probe = subprocess.run(["g++", "-std=c++20", "-x", "c++", "-fsyntax-only", "-"],
                           input="#include <gtest/gtest.h>\n", text=True,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if probe.returncode == 0:
        subprocess.run(["g++", "-std=c++20", "-Wall", "-Wextra", "-Werror", "-fsyntax-only",
                        str(cpp / "WorldTest.cpp"),
                        str(root / "config/Tests/impl/Unit/ConfiguredTest.cc"),
                        str(root / "commands/Types/Native_testTest.cpp")], check=True)
        print("PASS: GoogleTest templates (default, configured split and Ex command)")
    else:
        print("SKIP: GoogleTest compilation (GoogleTest headers are not installed)")
else:
    print("SKIP: C++ compilation (g++ is not installed)")
