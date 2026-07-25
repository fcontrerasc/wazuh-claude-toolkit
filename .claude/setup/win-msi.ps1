# win-msi.ps1 - winagent stage 2: turn the stage-1 zip into an MSI.
#
#   powershell -ExecutionPolicy Bypass -File win-msi.ps1 `
#       -Zip C:\wz\wazuh-agent_5.0.0-0_windows_abc1234.zip -MsiName wazuh-agent_....msi
#
# Mirrors .github/workflows/5_builderpackage_agent-windows.yml. A file rather than
# an inline -Command: quoting through ssh -> cmd -> powershell mangles inline
# scripts, which come back echoed with exit code 0 and read as success.

param(
    [Parameter(Mandatory = $true)][string]$Zip,
    [Parameter(Mandatory = $true)][string]$MsiName,
    [string]$WorkDir = 'C:\wz\stage2',
    [string]$WixBin = ''
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $Zip)) { throw "zip not found: $Zip" }

if ($WixBin -eq '') {
    foreach ($c in @((Join-Path ${env:ProgramFiles(x86)} 'WiX Toolset v3.14\bin'),
                     'C:\wix314')) {
        if (Test-Path (Join-Path $c 'candle.exe')) { $WixBin = $c; break }
    }
}
if ($WixBin -eq '') { throw "WiX not found - run: vmx provision <instance>" }

# cv2pdb is invoked by name from the source tree, so it must be reachable on PATH.
if (Test-Path 'C:\cv2pdb\cv2pdb.exe') { $env:PATH = "C:\cv2pdb;$env:PATH" }

# cv2pdb loads the Microsoft PDB writer at runtime; the winagent build is i686, so
# it needs the 32-bit mspdb*.dll (Hostx86\x86) on PATH, not merely installed.
$mspdbDir = (Get-ChildItem -Path "${env:ProgramFiles(x86)}\Microsoft Visual Studio" `
    -Recurse -Filter 'mspdb*.dll' -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match '\\Host(x86|X86)\\x86\\' } |
    Select-Object -First 1).Directory.FullName
if ($mspdbDir) {
    $env:PATH = "$mspdbDir;$env:PATH"
    Write-Output "pdb_writer=$mspdbDir"
}

New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
Get-ChildItem -Path $WorkDir -Force | Remove-Item -Recurse -Force
Expand-Archive -LiteralPath $Zip -DestinationPath $WorkDir -Force

# The zip holds one top-level directory (the worktree name).
$root = Get-ChildItem -Path $WorkDir -Directory | Select-Object -First 1
if (-not $root) { throw "no source directory inside $Zip" }
$win32 = Join-Path $root.FullName 'src\win32'
if (-not (Test-Path $win32)) { throw "missing src\win32 in $($root.FullName)" }

Write-Output "source=$($root.FullName)"
Write-Output "exe_count=$((Get-ChildItem (Join-Path $root.FullName 'src\build\bin') -Filter *.exe -ErrorAction SilentlyContinue).Count)"

# The generation script lives in packages/windows/ and is expected in src/win32/.
$gen = Join-Path $win32 'generate_wazuh_msi.ps1'
Copy-Item (Join-Path $root.FullName 'packages\windows\generate_wazuh_msi.ps1') `
    $win32 -Force

# ExtractDebugSymbols (:138) runs before BuildWazuhMsi (:139). cv2pdb needs the
# 32-bit mspdb*.dll to write PDBs; without it no .pdb exists, Compress-Archive gets
# an empty -Path, and that parameter-binding error is *terminating* - it kills the
# script before the MSI is built and no ErrorActionPreference can stop it. So when
# the PDB writer is absent, comment the call out in this copy, the same way CI
# comments out signtool.
$mspdb = Get-ChildItem -Path "${env:ProgramFiles(x86)}\Microsoft Visual Studio" `
    -Recurse -Filter 'mspdb*.dll' -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match '\\Host(x86|X86)\\x86\\' } |
    Select-Object -First 1
if (-not $mspdb) {
    (Get-Content $gen) -replace '^ExtractDebugSymbols$', '#ExtractDebugSymbols' |
        Set-Content $gen
    Write-Output "symbols_skipped=no 32-bit mspdb*.dll (install VS Build Tools VC.Tools.x86.x64 for symbols)"
}

# Same edits CI makes: no signing, and no interactive pause in a batch run.
$bat = Join-Path $win32 'wazuh-installer-build-msi.bat'
if (Test-Path $bat) {
    (Get-Content $bat) -replace 'signtool', '::signtool' -replace 'pause', '::pause' |
        Set-Content $bat
}

Push-Location $win32
try {
    # generate_wazuh_msi.ps1 runs ExtractDebugSymbols unconditionally (:138) before
    # BuildWazuhMsi (:139). Without the 32-bit mspdb*.dll, cv2pdb writes no .pdb and
    # its Compress-Archive gets an empty -Path; under 'Stop' that aborts before the
    # MSI is ever built. Symbols are optional, the package is not.
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & .\generate_wazuh_msi.ps1 -MSI_NAME $MsiName -SIGN no -WIX_TOOLS_PATH $WixBin
    $ErrorActionPreference = $prev
    $msi = Get-ChildItem -Path . -Filter $MsiName -ErrorAction SilentlyContinue
    if ($msi) {
        Write-Output "msi=$($msi.FullName)"
        Write-Output "msi_bytes=$($msi.Length)"
    } else {
        Write-Output "msi=MISS"
    }
    $sym = Get-ChildItem -Path . -Filter '*debug-symbols*.zip' -ErrorAction SilentlyContinue
    if ($sym) { Write-Output "symbols=$($sym.FullName)" } else { Write-Output "symbols=MISS" }
} finally {
    Pop-Location
}
