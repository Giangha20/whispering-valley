# Whispering Valley — Build, Test & Export Script (Godot 4.7.2)
param(
    [string]$GodotExe = "C:\Users\giang\Downloads\Compressed\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe",
    [switch]$ExportWeb,
    [switch]$ExportWindows
)

$ErrorActionPreference = "Stop"
$ProjectDir = Split-Path -Parent $PSScriptRoot

Write-Host "1. Importing assets & checking project..."
& $GodotExe --headless --path $ProjectDir --import --quit

Write-Host "2. Running full automated Unit + Integration + Scene test suite..."
& $GodotExe --headless --path $ProjectDir --scene "res://tests/TestScene.tscn"
if ($LASTEXITCODE -ne 0) {
    throw "Test suite failed with exit code $LASTEXITCODE!"
}

$TemplateDir = Join-Path $env:APPDATA "Godot\export_templates\4.7.2.stable"
if ($ExportWeb -or $ExportWindows) {
    if (-not (Test-Path $TemplateDir)) {
        Write-Warning "Godot 4.7.2 export templates not found at: $TemplateDir"
        Write-Warning "Install official Godot 4.7.2 Export Templates via Godot Editor -> Editor -> Manage Export Templates to build Web/Windows binaries."
        exit 1
    }
}

if ($ExportWeb) {
    Write-Host "3a. Exporting Web HTML5 build -> builds/web/index.html"
    New-Item -ItemType Directory -Force -Path (Join-Path $ProjectDir "builds/web") | Out-Null
    & $GodotExe --headless --path $ProjectDir --export-release "Web" (Join-Path $ProjectDir "builds/web/index.html")
}

if ($ExportWindows) {
    Write-Host "3b. Exporting Windows Desktop build -> builds/windows/WhisperingValley.exe"
    New-Item -ItemType Directory -Force -Path (Join-Path $ProjectDir "builds/windows") | Out-Null
    & $GodotExe --headless --path $ProjectDir --export-release "Windows Desktop" (Join-Path $ProjectDir "builds/windows/WhisperingValley.exe")
}

Write-Host "All checks passed!"
