# Busted with LOVE on Windows (x64)

This guide prepares [Busted](https://lunarmodules.github.io/busted/) for the
LuaJIT runtime shipped with 64-bit [LOVE](https://love2d.org/), then runs the
Shadows specs inside LOVE. It can be followed on another Windows machine;
no files from love-theme-gui are required.

The reference toolchain is LOVE 11.5 x64, LuaJIT `2.1.1700008891`,
LuaRocks 3.13.0, Busted 2.3.0-1, and MSVC x64. For another LOVE version,
use its matching LuaJIT sources and verify its native-module ABI again.

## Overview

Busted's Lua modules are portable, but dependencies such as LuaFileSystem,
LuaSystem, and LuaTerm include native DLLs. All of these must agree:

| Requirement | Target |
| --- | --- |
| Architecture | x64 for LOVE, LuaJIT, and native modules |
| Lua API | Lua 5.1, implemented by LuaJIT |
| Imported runtime | LOVE's `lua51.dll`, not standard Lua's `lua5.1.dll` |

A 64-bit standard Lua 5.1 installation is not interchangeable with LOVE's
LuaJIT. Renaming DLLs does not fix that. LuaRocks' own architecture also does
not establish the architecture or runtime linkage of the rocks it installs.

Keep LOVE unchanged. Build a matching LuaJIT development prefix and install
Busted into a separate per-user rocks tree. Projects using the same verified
LOVE runtime can share this tree without reinstalling anything.

## 1. Prerequisites

Install or extract:

1. **LOVE Windows x64**, from the [official downloads](https://love2d.org/).
   Keep `love.exe`, `lovec.exe`, `lua51.dll`, and supporting DLLs together.
2. **Visual Studio Build Tools**, from
   [Microsoft](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio),
   with **Desktop development with C++**, the MSVC x64/x86 tools, and a Windows SDK.
   The full Visual Studio IDE is not required.
3. **LuaRocks standalone Windows x64**, from the
   [official releases](https://luarocks.github.io/luarocks/releases/).
   The reference archive is
   [luarocks-3.13.0-windows-64.zip](https://luarocks.github.io/luarocks/releases/luarocks-3.13.0-windows-64.zip).
   Put `luarocks.exe` in `%LOCALAPPDATA%\Programs\LuaRocks`, or adjust the paths below.
   Avoid the legacy `win32.zip` bundle with its own standard Lua interpreter.
4. **Git for Windows** and **7-Zip's `7z.exe`** on `PATH`, for downloading and
   unpacking source rocks. Installing their GUI applications alone may not
   expose their command-line executables.

If a binary cannot find a Microsoft runtime DLL, install the appropriate
**x64 Visual C++ Redistributable** from Microsoft. Older LOVE distributions
may need an older runtime than a recent MSVC compiler. Runtime DLLs bundled
with official LOVE can also be placed beside the standalone LuaJIT executable.
Do not obtain replacement DLLs from third-party DLL sites.

Open an **x64 Native Tools Command Prompt** for Visual Studio, then start:

```bat
powershell -NoProfile
```

The child PowerShell inherits `PATH`, `INCLUDE`, and `LIB`. Check:

```powershell
Get-Command cl.exe, link.exe, nmake.exe, dumpbin.exe, git.exe, 7z.exe
$env:VSCMD_ARG_TGT_ARCH
```

The target must be `x64`. Running `vcvars64.bat` in a separate child process
cannot initialize an existing parent PowerShell; compiler setup and builds
must share the initialized environment.

The following setup blocks belong to the same session. They may instead be
saved together in a temporary `.ps1` file and launched from that environment:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\setup-love-busted.ps1"
```

The execution-policy option affects only the new process.

## 2. Paths and matching sources

Adjust `$LoveHome` to your actual LOVE installation:

```powershell
$ErrorActionPreference = "Stop"
$LoveHome = "C:\Program Files\LOVE"
$LuaJitRoot = Join-Path $env:LOCALAPPDATA "Programs\LuaJIT-love"
$LuaRocks = Join-Path $env:LOCALAPPDATA "Programs\LuaRocks\luarocks.exe"
$RocksTree = Join-Path $env:LOCALAPPDATA "LuaRocks-love"
$Work = Join-Path $env:TEMP ("love-busted-setup-" + [guid]::NewGuid())

Get-Item -LiteralPath (Join-Path $LoveHome "love.exe"), (Join-Path $LoveHome "lua51.dll"), $LuaRocks
& (Join-Path $LoveHome "lovec.exe") --version
& $LuaRocks --version
New-Item -ItemType Directory -Path $Work | Out-Null
```

Use fresh development and rocks directories if an existing installation
targets another runtime. Administrator privileges are normally needed for
Build Tools, not for these per-user directories.

Obtain the [LOVE megasource tag](https://github.com/love2d/megasource/tags)
matching the installed LOVE release. For **LOVE 11.5**:

```powershell
$archive = Join-Path $Work "megasource-11.5.zip"
Invoke-WebRequest -Uri "https://github.com/love2d/megasource/archive/refs/tags/11.5.zip" -OutFile $archive
Expand-Archive -LiteralPath $archive -DestinationPath $Work
$LuaJitSource = Join-Path $Work "megasource-11.5\libs\LuaJIT"
Get-Content -LiteralPath (Join-Path $LuaJitSource ".relver")
```

For this release, `.relver` is `1700008891`. Preserve it: LuaJIT uses it for
version metadata when building without Git metadata. Other releases may
have different source layouts. Do not substitute LuaJIT's newest branch.
Only LuaJIT needs building, not the whole LOVE megasource project.

## 3. Build the LuaJIT development prefix

In the initialized x64 environment, build the default dynamic release target;
do not use `static`, `debug`, or `nogc64` for this reference setup:

```powershell
Push-Location -LiteralPath (Join-Path $LuaJitSource "src")
try {
    & $env:ComSpec /d /c "msvcbuild.bat"
    if ($LASTEXITCODE -ne 0) { throw "LuaJIT build failed." }
    Get-Item -LiteralPath ".\luajit.exe", ".\lua51.dll", ".\lua51.lib"
}
finally {
    Pop-Location
}
```

Expect `Successfully built LuaJIT for Windows/x64`. Install the interpreter,
headers, generated import library, supporting modules, and license, but use
**LOVE's actual DLL** beside the interpreter:

```powershell
foreach ($directory in @("bin", "include", "lib", "share\lua\5.1")) {
    New-Item -ItemType Directory -Path (Join-Path $LuaJitRoot $directory) -Force | Out-Null
}
$sourceBin = Join-Path $LuaJitSource "src"
Copy-Item -LiteralPath (Join-Path $sourceBin "luajit.exe") -Destination (Join-Path $LuaJitRoot "bin\luajit.exe")
Copy-Item -LiteralPath (Join-Path $LoveHome "lua51.dll") -Destination (Join-Path $LuaJitRoot "bin\lua51.dll")
Copy-Item -LiteralPath (Join-Path $sourceBin "lua51.lib") -Destination (Join-Path $LuaJitRoot "lib\lua51.lib")
foreach ($header in @("lua.h", "lauxlib.h", "lualib.h", "luaconf.h", "luajit.h", "lua.hpp")) {
    Copy-Item -LiteralPath (Join-Path $sourceBin $header) -Destination (Join-Path $LuaJitRoot "include")
}
Copy-Item -LiteralPath (Join-Path $sourceBin "jit") -Destination (Join-Path $LuaJitRoot "share\lua\5.1") -Recurse
Copy-Item -LiteralPath (Join-Path $LuaJitSource "COPYRIGHT") -Destination $LuaJitRoot

& (Join-Path $LuaJitRoot "bin\luajit.exe") -e "print(jit.version, jit.arch); assert(jit.arch == 'x64')"
if ($LASTEXITCODE -ne 0) { throw "The matching LuaJIT interpreter could not run." }
```

Expect `LuaJIT 2.1.1700008891` and `x64`. Nothing is written into LOVE's
installation. Its DLL alone is not a development installation: native rocks
also require matching headers and `lua51.lib`.

## 4. Install and verify Busted

Still in the MSVC-initialized session:

```powershell
& $LuaRocks --lua-dir $LuaJitRoot --lua-version 5.1 --tree $RocksTree install busted 2.3.0-1 --deps-mode one LUALIB=lua51.lib
if ($LASTEXITCODE -ne 0) { throw "Busted installation failed." }
```

- `--lua-dir` chooses the matching development prefix.
- `--lua-version 5.1` is correct for LuaJIT.
- `--tree` isolates the rocks from standard Lua installations.
- `--deps-mode one` restricts dependency lookup to that tree.
- `LUALIB=lua51.lib` selects the LuaJIT import-library name.
- Pinning Busted reproduces the reference version; newer versions need verification.

Isolation does not repair incompatible DLLs already inside the chosen tree,
and a binary rock's x64 label does not prove its Lua runtime linkage.
Inspect native modules:

```powershell
dumpbin /headers "$LuaJitRoot\bin\luajit.exe" | Select-String "machine"
foreach ($module in @("lfs.dll", "system\core.dll", "term\core.dll")) {
    $dll = Join-Path $RocksTree ("lib\lua\5.1\" + $module)
    dumpbin /headers $dll | Select-String "machine"
    dumpbin /dependents $dll
}
$original = Get-FileHash -LiteralPath (Join-Path $LoveHome "lua51.dll")
$copy = Get-FileHash -LiteralPath (Join-Path $LuaJitRoot "bin\lua51.dll")
if ($original.Hash -ne $copy.Hash) { throw "The LuaJIT DLL does not match LOVE." }
```

Expect x64 (`8664`) headers and imports of `lua51.dll`, **not** `lua5.1.dll`.
If a rock imports the wrong runtime, build it from source with the same flags,
for example replacing `install busted 2.3.0-1` with `build luafilesystem`,
then inspect the imports again.

Actually load the installed modules:

```powershell
$env:LUA_PATH = "$RocksTree\share\lua\5.1\?.lua;$RocksTree\share\lua\5.1\?\init.lua;$LuaJitRoot\share\lua\5.1\?.lua;;"
$env:LUA_CPATH = "$RocksTree\lib\lua\5.1\?.dll"
& (Join-Path $LuaJitRoot "bin\luajit.exe") -e "assert(jit.arch == 'x64'); require('lfs'); require('system.core'); require('term.core'); require('busted.runner'); print('Busted and native modules loaded')"
if ($LASTEXITCODE -ne 0) { throw "Native module verification failed." }
& "$RocksTree\bin\busted.bat" --version
if ($LASTEXITCODE -ne 0) { throw "The Busted wrapper could not run." }
```

`LUA_CPATH` deliberately has no `;;` fallback to unrelated native modules.
These environment assignments affect only this session and its children.
Once verified, retain the installed prefixes; the temporary source/build
directory is no longer needed.

## 5. Run the Shadows suite inside LOVE

From this repository's root:

```powershell
$env:PATH = "$LoveHome;$env:PATH"
powershell -NoProfile -ExecutionPolicy Bypass -File spec\run.ps1
```

The launcher defaults to `%LOCALAPPDATA%\LuaRocks-love`. MSVC is needed to
build native dependencies, not to run installed tests. In a new terminal,
only ensure the intended `lovec` or `love` is on `PATH`.

Select another rocks tree or a focused spec:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File spec\run.ps1 -RocksTree "D:\Tools\LuaRocks-love"
powershell -NoProfile -ExecutionPolicy Bypass -File spec\run.ps1 -Specs spec\love\Lighting_spec.lua
powershell -NoProfile -ExecutionPolicy Bypass -File spec\run.ps1 -Specs spec\Transform_spec.lua
```

From an existing PowerShell session, `-Specs` also accepts an array:

```powershell
& .\spec\run.ps1 -Specs @("spec\DPI_spec.lua", "spec\PenumbraSettings_spec.lua")
```

VS Code's **Run Busted tests** task runs the complete suite.

### How the bridge works

Do not use `busted --lua love`: Busted expects an interpreter that accepts
a Lua script, whereas LOVE expects a game directory.

1. [spec/run.ps1](spec/run.ps1) copies `src/` and `spec/` into a temporary game,
   installs the test bootstrap/configuration as its entry points, and sets
   isolated Lua module paths.
2. It sets the OS working directory to that game, because native
   LuaFileSystem discovery does not use LOVE's virtual filesystem.
3. [spec/busted-love/main.lua](spec/busted-love/main.lua) runs
   `require("busted.runner")({ standalone = false })` from `love.load`,
   after LOVE initializes graphics.
4. Busted discovers native `*_spec.lua` files. Failures/errors produce a
   nonzero exit status; success exits with zero.
5. The launcher restores its environment and deletes the temporary game.

The library and demos are unchanged. This is a separate test application,
configured by [spec/busted-love/conf.lua](spec/busted-love/conf.lua), not a
headless graphics runner.

### Coverage and screenshots

The suite includes the existing DPI and penumbra-settings specs, hierarchical
transform and equal-height queue tests, plus real graphics checks for:

- A visible projected shadow on the first world update.
- Stationary/color-only shadow-cache reuse and changed output tint.
- Exact pixel equality between moved-body incremental updates and forced rebuilds.
- Soft-shadow source-radius updates and the zero-radius hard-shadow path.

The first-update render is saved **before its pixel assertions**, including
on an assertion failure, to:

```text
%APPDATA%\LOVE\shadows-tests\screenshots\first-update-shadow.png
```

Inspect it alongside Busted's measured assertions. It is separate from the
interactive demos' `shadows` save directory. There is no baseline-update mode;
rendering tests compare numeric thresholds or same-run rebuilt pixels.
Keep the existing demo `--capture --verify` checks as supplemental end-to-end
validation; see [README.md](README.md#demos).

### Standalone unit tests

With the module paths from section 4, these specs can also run without LOVE:

```powershell
& "$RocksTree\bin\busted.bat" spec\DPI_spec.lua spec\PenumbraSettings_spec.lua spec\Transform_spec.lua spec\PriorityQueue_spec.lua
```

Do not run bare `busted` under a standalone interpreter: it also discovers
`spec/love/`, which requires initialized graphics. Use the LOVE launcher for
the complete suite.

## Writing specs

Use ordinary Busted `describe`, `it`, `before_each`, and `after_each` functions.
Put focused non-rendering tests in `spec/` and runtime-dependent tests in
`spec/love/`. Save and restore globals, module substitutions, and graphics
state with lifecycle hooks so failed assertions do not contaminate later tests.
Keep LuaDoc annotations complete, including test callbacks and helpers.

Add focused cases for new/fixed behavior rather than duplicating entire demo
scenarios. A rendering regression should measure actual pixels or cache work,
not merely confirm that calling a draw method succeeds.

## Troubleshooting

| Symptom | Action |
| --- | --- |
| `%1 is not a valid Win32 application` | Check x64 architecture for every native module and dependency. |
| Crash while loading a rock | Inspect imports for standard Lua's `lua5.1.dll`, mismatched LuaJIT files, or incompatible binaries already in the tree. |
| Missing `cl`, `link`, `nmake`, or SDK headers | Install the C++ workload/SDK and reopen the x64 Native Tools environment. |
| Source download/unpacking fails | Check LuaRocks' named missing tool, Git/7-Zip availability, and network/proxy configuration. |
| `LNK1112` machine-type conflict | Do not mix x86 objects/libraries with x64 builds; rebuild from fresh output. |
| Missing `lua51.lib` or headers | Check the development-prefix layout, `--lua-dir`, and `LUALIB=lua51.lib`. |
| LuaRocks selects standard Lua | Use the explicit executable, `--lua-dir`, `--lua-version 5.1`, and `--tree`; inspect conflicting LuaRocks configuration. |
| Missing `busted.runner`, `lfs`, `system.core`, or `term.core` | Verify installation and paths in the selected tree; do not copy modules from an unrelated Lua runtime. |
| `Cannot load game at path ...\bin\busted` | Use the LOVE bootstrap, not `busted --lua love`. |
| Missing specs or library modules | Run the launcher from this checkout; its assembled game's OS and LOVE directories must agree. |
| `lovec`/`love` not found or wrong version | Put the intended LOVE directory first on `PATH`; inspect `Get-Command lovec, love`. |
| Graphics/shader allocation fails | Rendering specs require a working LOVE graphics environment, including the library's floating-point canvas support. |

When upgrading LOVE, recheck LuaJIT version, architecture, and DLL linkage;
rebuild native rocks in a fresh matching tree and rerun the suite before
discarding the previous working installation.
