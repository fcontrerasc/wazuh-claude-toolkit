# win-packager.ps1 - check or install the MSI packaging prerequisites.
#
#   powershell -ExecutionPolicy Bypass -File win-packager.ps1 -Action check
#   powershell -ExecutionPolicy Bypass -File win-packager.ps1 -Action install -Asset C:\Users\wazuh\wix314.exe
#
# A file, not an inline -Command: quoting through ssh -> cmd -> powershell mangles
# inline scripts (they come back echoed, with exit code 0, which reads as success).
#
# Emits KEY=OK / KEY=MISS lines so the caller parses instead of guessing.

param(
    [ValidateSet("check", "install")][string]$Action = "check",
    [string]$Asset = "",
    # ~3GB download; only for debug-symbol PDBs, so it is opt-in.
    [switch]$Symbols
)

$ErrorActionPreference = 'Stop'

$wixBin  = Join-Path ${env:ProgramFiles(x86)} 'WiX Toolset v3.14\bin'
$wixZip  = 'C:\wix314'   # binaries-zip layout, no installer needed

function Find-Tool([string]$name) {
    foreach ($dir in @($wixBin, $wixZip, 'C:\cv2pdb')) {
        $p = Join-Path $dir $name
        if (Test-Path $p) { return $p }
    }
    $c = Get-Command $name -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    return $null
}

function Report([string]$key, $value) {
    if ($value) { Write-Output "$key=OK $value" } else { Write-Output "$key=MISS" }
}

if ($Action -eq "install" -and -not (Find-Tool 'candle.exe')) {
    if (-not $Asset -or -not (Test-Path $Asset)) { throw "asset not found: $Asset" }

    if ($Asset.ToLower().EndsWith(".zip")) {
        # Preferred: extraction needs no elevation, which an ssh session lacks.
        Expand-Archive -Force -LiteralPath $Asset -DestinationPath $wixZip
        Write-Output "installed=zip $wixZip"
    } else {
        # WiX bundle: /quiet still requires elevation and .NET Framework 3.5.
        $p = Start-Process -FilePath $Asset `
            -ArgumentList '/install', '/quiet', '/norestart' -Wait -PassThru
        Write-Output "installer_exit=$($p.ExitCode)"
        if ($p.ExitCode -eq 1602) { Write-Output "note=cancelled (needs elevation)" }
        if ($p.ExitCode -eq 1603) { Write-Output "note=fatal (often .NET 3.5 missing)" }
    }
}

if ($Action -eq "install" -and -not (Find-Tool 'cv2pdb.exe')) {
    # Same version CI pins. Extraction only: no elevation, no installer.
    $url = 'https://github.com/rainers/cv2pdb/releases/download/v0.52/cv2pdb-0.52.zip'
    $tmp = Join-Path $env:TEMP 'cv2pdb.zip'
    try {
        Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
        Expand-Archive -Force -LiteralPath $tmp -DestinationPath 'C:\cv2pdb'
        Write-Output "cv2pdb_installed=C:\cv2pdb"
    } catch {
        Write-Output "cv2pdb_install_failed=$($_.Exception.Message)"
    }
}

function Get-Mspdb32 {
    Get-ChildItem -Path "${env:ProgramFiles(x86)}\Microsoft Visual Studio" `
        -Recurse -Filter 'mspdb*.dll' -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '\\Host(x86|X86)\\x86\\' } |
        Select-Object -First 1
}

if ($Action -eq "install" -and $Symbols -and -not (Get-Mspdb32)) {
    # cv2pdb needs the 32-bit PDB writer to emit .pdb files. Same workload CI
    # installs; the winagent build is i686, hence the x86 host tools.
    $boot = Join-Path $env:TEMP 'vs_buildtools.exe'
    Write-Output "vsbuildtools=downloading"
    Invoke-WebRequest -Uri 'https://aka.ms/vs/17/release/vs_buildtools.exe' `
        -OutFile $boot -UseBasicParsing
    $p = Start-Process -FilePath $boot -Wait -PassThru -ArgumentList @(
        '--quiet', '--wait', '--norestart', '--nocache',
        '--add', 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64')
    # 3010 = success, reboot required; harmless here.
    Write-Output "vsbuildtools_exit=$($p.ExitCode)"
    if ($p.ExitCode -notin @(0, 3010)) {
        Write-Output "vsbuildtools_failed=exit $($p.ExitCode)"
    }
}

Report "candle"  (Find-Tool 'candle.exe')
Report "light"   (Find-Tool 'light.exe')
Report "cv2pdb"  (Find-Tool 'cv2pdb.exe')

Report "mspdb32" (Get-Mspdb32).FullName

$net = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' `
    -ErrorAction SilentlyContinue
Report "dotnet4" $net.Version

$net35 = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v3.5' `
    -ErrorAction SilentlyContinue
Report "dotnet35" $net35.Version
