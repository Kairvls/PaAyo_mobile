# Wireless-debug helper for this PC (not the old jc-suan ADB path).
param(
  [Parameter(Mandatory = $true)]
  [string]$PhoneEndpoint,
  [string]$PairEndpoint,
  [string]$PairCode
)

$adb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"
if (-not (Test-Path $adb)) {
  Write-Error "ADB not found at $adb"
  exit 1
}

if ($PairEndpoint -and $PairCode) {
  Write-Host "Pairing $PairEndpoint ..."
  & $adb pair $PairEndpoint $PairCode
}

Write-Host "Connecting $PhoneEndpoint ..."
& $adb connect $PhoneEndpoint
& $adb devices -l
