$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$WorkspaceRoot = Resolve-Path (Join-Path $ProjectRoot "..")

$GodotWorkDir = Join-Path $WorkspaceRoot "godot_tmp"
$GodotMain = Join-Path $GodotWorkDir "Godot_v4.4.1-stable_win64.exe"
$GodotConsole = Join-Path $GodotWorkDir "Godot_v4.4.1-stable_win64_console.exe"

if (!(Test-Path $GodotConsole)) {
	New-Item -ItemType Directory -Force -Path $GodotWorkDir | Out-Null
	Copy-Item -LiteralPath "C:\Users\alex\Desktop\Godot_v4.4.1-stable_win64.exe" -Destination $GodotMain -Force
	Copy-Item -LiteralPath "C:\Users\alex\Downloads\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64_console.exe" -Destination $GodotConsole -Force
}

$GodotUserBase = Join-Path $WorkspaceRoot "godot_user"
New-Item -ItemType Directory -Force -Path (Join-Path $GodotUserBase "Roaming"), (Join-Path $GodotUserBase "Local") | Out-Null
$env:APPDATA = Join-Path $GodotUserBase "Roaming"
$env:LOCALAPPDATA = Join-Path $GodotUserBase "Local"

& $GodotConsole --headless --path $ProjectRoot "res://tests/smoke_full_flow.tscn"
$exitCode = $LASTEXITCODE

$resultPath = Join-Path $WorkspaceRoot "survivalfarm_smoke_result.txt"
if (Test-Path $resultPath) {
	Get-Content -LiteralPath $resultPath
}

exit $exitCode
