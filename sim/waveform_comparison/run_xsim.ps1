param([string]$VivadoBin = "")
$ErrorActionPreference = 'Stop'
function Find-Tool([string]$Name) {
    if ($VivadoBin) { return Join-Path $VivadoBin $Name }
    return (Get-Command $Name -ErrorAction Stop).Source
}
$xvlog = Find-Tool 'xvlog.bat'
$xelab = Find-Tool 'xelab.bat'
$xsim = Find-Tool 'xsim.bat'
$runRoot = Join-Path $PSScriptRoot 'run'
New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
$rtl = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot '../../src/rtl') -Filter '*.v' | ForEach-Object FullName)
$sources = @((Join-Path $PSScriptRoot 'comparison_tb.sv'), (Join-Path $PSScriptRoot 'bufgce_model.v')) + $rtl
Push-Location $runRoot
try {
    & $xvlog --sv @sources
    if ($LASTEXITCODE -ne 0) { throw 'Compilation failed' }
    & $xelab comparison_tb -s comparison_snapshot -debug typical
    if ($LASTEXITCODE -ne 0) { throw 'Elaboration failed' }
    & $xsim comparison_snapshot -wdb comparison.wdb -tclbatch ../capture.tcl -log simulation.log
    if ($LASTEXITCODE -ne 0) { throw 'Simulation failed' }
    if (-not (Select-String -LiteralPath simulation.log -Pattern '^COMPARISON_PASS$' -Quiet)) { throw 'Comparison assertions did not pass' }
    Write-Output 'Verified: matching input, zero sleep clock edges, and 18.8331579 percent steady-cycle clock activity reduction.'
} finally { Pop-Location }
