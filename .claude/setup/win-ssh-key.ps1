# win-ssh-key.ps1 - authorize a public key for passwordless vmx access, and
# report why sshd rejected it if it still does.
#
# Run on the Windows guest:
#   powershell -ExecutionPolicy Bypass -File C:\Users\wazuh\win-ssh-key.ps1 -Key "<ssh-ed25519 ...>"
#   powershell -ExecutionPolicy Bypass -File C:\Users\wazuh\win-ssh-key.ps1 -DiagnoseOnly
#
# Two Windows-specific traps this handles:
#   1. sshd's default sshd_config ends with `Match Group administrators` pointing
#      at C:\ProgramData\ssh\administrators_authorized_keys, so for a member of
#      Administrators the per-user file is ignored entirely.
#   2. Group membership must be tested by SID, not IsInRole(Administrator): under
#      UAC the latter is false in a non-elevated session even for an admin user,
#      which sends the key to the file sshd will not read.

param(
    [string]$Key,
    [switch]$DiagnoseOnly
)

$ErrorActionPreference = 'Stop'

# S-1-5-32-544 = BUILTIN\Administrators. Membership, not elevation.
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$adminSid = New-Object Security.Principal.SecurityIdentifier 'S-1-5-32-544'
$inAdmins = $identity.Groups -contains $adminSid

$adminFile = Join-Path $env:ProgramData 'ssh\administrators_authorized_keys'
$userFile  = Join-Path $env:USERPROFILE '.ssh\authorized_keys'
$target    = if ($inAdmins) { $adminFile } else { $userFile }

Write-Host "user            : $($identity.Name)"
Write-Host "in Administrators: $inAdmins"
Write-Host "sshd will read  : $target"
Write-Host ""

if (-not $DiagnoseOnly) {
    if (-not $Key) { throw "-Key is required unless -DiagnoseOnly is used" }

    New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null

    if ((Test-Path $target) -and (Select-String -Path $target -SimpleMatch $Key -Quiet)) {
        Write-Host "key already present in $target"
    } else {
        # ASCII, no BOM: sshd will not parse a UTF-16 or BOM-prefixed key file.
        $existing = if (Test-Path $target) { Get-Content $target -Raw } else { "" }
        $sep = if ($existing -and -not $existing.EndsWith("`n")) { "`r`n" } else { "" }
        [IO.File]::WriteAllText($target, $existing + $sep + $Key + "`r`n",
                                 (New-Object Text.ASCIIEncoding))
        Write-Host "key written to $target"
    }

    if ($inAdmins) {
        icacls $target /inheritance:r /grant 'Administrators:F' /grant 'SYSTEM:F' | Out-Null
    } else {
        icacls $target /inheritance:r /grant "$($identity.Name):F" /grant 'SYSTEM:F' | Out-Null
        # sshd also checks the .ssh directory and the profile above it.
        icacls (Split-Path $target) /inheritance:r /grant "$($identity.Name):F" /grant 'SYSTEM:F' | Out-Null
    }
}

Write-Host "--- files ---"
foreach ($f in @($adminFile, $userFile)) {
    if (Test-Path $f) {
        $enc = [IO.File]::ReadAllBytes($f)[0..1] -join ','
        Write-Host "$f  ($((Get-Item $f).Length) bytes, first bytes $enc)"
        icacls $f
        Write-Host "owner: $((Get-Acl $f).Owner)"
    } else {
        Write-Host "$f  (absent)"
    }
    Write-Host ""
}

Write-Host "--- sshd service ---"
Get-Service sshd | Select-Object Name, Status, StartType | Format-Table | Out-String | Write-Host

Write-Host "--- sshd_config AuthorizedKeysFile / Match ---"
$cfg = Join-Path $env:ProgramData 'ssh\sshd_config'
if (Test-Path $cfg) {
    Select-String -Path $cfg -Pattern 'AuthorizedKeysFile|^Match|PubkeyAuthentication' |
        ForEach-Object { Write-Host $_.Line }
}

Write-Host ""
Write-Host "--- last sshd auth events ---"
try {
    Get-WinEvent -LogName 'OpenSSH/Operational' -MaxEvents 20 -ErrorAction Stop |
        Where-Object { $_.Message -match 'refus|denied|Accepted|bad owner|bad permission|key' } |
        Select-Object -First 10 TimeCreated, Message |
        Format-List | Out-String | Write-Host
} catch {
    Write-Host "OpenSSH/Operational log unavailable: $($_.Exception.Message)"
}
