[CmdletBinding()]
param(
    [switch]$IncludeAndroidUat
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot

function Invoke-M2Gate {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][scriptblock]$Command
    )

    Write-Host "== $Name =="
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$Name failed with exit code $LASTEXITCODE"
    }
}

Push-Location $repoRoot
try {
    Invoke-M2Gate 'Spring AI 2 platform' { python tool/verify_spring_ai_2_backend_platform.py }
    Invoke-M2Gate 'M2-11 privacy and lifecycle' { dart tool/verify_m2_11_custom_scene_gates.dart }
    Invoke-M2Gate 'M2-12 automatable matrix' { dart tool/verify_m2_12_release_matrix.dart }

    Push-Location 'backend'
    try {
        Invoke-M2Gate 'Backend full Maven test' { bash mvnw clean test }
    }
    finally {
        Pop-Location
    }

    Push-Location 'mobile'
    try {
        Invoke-M2Gate 'Mobile analyze' { flutter analyze }
        Invoke-M2Gate 'Mobile format' { dart format --output=none --set-exit-if-changed lib test integration_test }
        Invoke-M2Gate 'Mobile full Flutter test' { flutter test }
    }
    finally {
        Pop-Location
    }

    if ($IncludeAndroidUat) {
        $devices = & adb devices
        $onlineDevices = $devices | Where-Object { $_ -match '\sdevice$' }
        if ($onlineDevices.Count -eq 0) {
            throw 'Android UAT requested but no online adb device is attached.'
        }
        Write-Host 'Android device present. Execute M2-12 manual risk UAT; do not infer TalkBack listening or touch-exploration evidence.'
    }
}
finally {
    Pop-Location
}
