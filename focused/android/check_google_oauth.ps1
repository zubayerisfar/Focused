$ErrorActionPreference = 'Stop'
$androidDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $androidDir

$servicesPath = Join-Path $androidDir 'app\google-services.json'
if (-not (Test-Path $servicesPath)) {
    throw 'android/app/google-services.json was not found.'
}

$json = Get-Content $servicesPath -Raw | ConvertFrom-Json
$packageName = 'com.example.focused'
$androidClient = $json.client | Where-Object {
    $_.client_info.android_client_info.package_name -eq $packageName
} | Select-Object -First 1

if (-not $androidClient) {
    Write-Host "ERROR: google-services.json has no Android client for $packageName" -ForegroundColor Red
    exit 1
}

$registered = @(
    $androidClient.oauth_client |
        Where-Object { $_.client_type -eq 1 -and $_.android_info.certificate_hash } |
        ForEach-Object { $_.android_info.certificate_hash.ToUpperInvariant() }
)
$webClient = $androidClient.oauth_client | Where-Object { $_.client_type -eq 3 } | Select-Object -First 1

Write-Host "Package: $packageName"
Write-Host "Web OAuth client present: $([bool]$webClient)"
Write-Host 'Android SHA-1 hashes currently present in google-services.json:'
if ($registered.Count -eq 0) {
    Write-Host '  (none)' -ForegroundColor Yellow
} else {
    $registered | ForEach-Object { Write-Host "  $_" }
}

Write-Host ''
Write-Host 'Reading signingReport...'
$report = & .\gradlew.bat :app:signingReport 2>&1
if ($LASTEXITCODE -ne 0) {
    $report | Write-Host
    throw 'Gradle signingReport failed.'
}

$shaLines = [regex]::Matches(($report -join "`n"), 'SHA1:\s*([A-Fa-f0-9:]+)')
$signingHashes = @($shaLines | ForEach-Object {
    $_.Groups[1].Value.Replace(':', '').ToUpperInvariant()
} | Select-Object -Unique)

Write-Host 'SHA-1 hashes produced by this machine/build configuration:'
if ($signingHashes.Count -eq 0) {
    Write-Host '  No SHA-1 values found in signingReport.' -ForegroundColor Yellow
} else {
    foreach ($hash in $signingHashes) {
        $match = $registered -contains $hash
        $status = if ($match) { 'REGISTERED' } else { 'MISSING FROM JSON/FIREBASE' }
        $color = if ($match) { 'Green' } else { 'Yellow' }
        Write-Host "  $hash  [$status]" -ForegroundColor $color
    }
}

Write-Host ''
Write-Host 'For every debug/release certificate you actually use, register SHA-1 AND SHA-256 in Firebase Project Settings, then download a fresh google-services.json.'
