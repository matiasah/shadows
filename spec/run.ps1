param(
    [string]$RocksTree = (Join-Path $env:LOCALAPPDATA "LuaRocks-love"),
    [string[]]$Specs = @("spec")
)

$ErrorActionPreference = "Stop"
$love = Get-Command lovec -ErrorAction SilentlyContinue
if (-not $love) {
    $love = Get-Command love -ErrorAction Stop
}
$RocksTree = (Resolve-Path -LiteralPath $RocksTree).Path
foreach ($module in @("share\lua\5.1\busted\runner.lua", "lib\lua\5.1\lfs.dll",
    "lib\lua\5.1\system\core.dll", "lib\lua\5.1\term\core.dll")) {
    if (-not (Test-Path -LiteralPath (Join-Path $RocksTree $module) -PathType Leaf)) {
        throw "Missing $module in $RocksTree. See BUSTED.md for the matching x64 LuaJIT installation."
    }
}

$repository = Split-Path -Parent $PSScriptRoot
$application = Join-Path ([System.IO.Path]::GetTempPath()) ("shadows-tests-" + [guid]::NewGuid())
$previousLuaPath = $env:LUA_PATH
$previousLuaCPath = $env:LUA_CPATH
New-Item -ItemType Directory -Path $application | Out-Null
try {
    Copy-Item -LiteralPath (Join-Path $repository "src") -Destination $application -Recurse
    Copy-Item -LiteralPath $PSScriptRoot -Destination (Join-Path $application "spec") -Recurse
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "busted-love\main.lua") `
        -Destination (Join-Path $application "main.lua")
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "busted-love\conf.lua") `
        -Destination (Join-Path $application "conf.lua")

    $env:LUA_PATH = "$RocksTree\share\lua\5.1\?.lua;$RocksTree\share\lua\5.1\?\init.lua;;"
    $env:LUA_CPATH = "$RocksTree\lib\lua\5.1\?.dll"
    Push-Location -LiteralPath $application
    try {
        & $love.Source $application @Specs
        $result = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }
}
finally {
    $env:LUA_PATH = $previousLuaPath
    $env:LUA_CPATH = $previousLuaCPath
    Remove-Item -LiteralPath $application -Recurse -Force
}
exit $result
