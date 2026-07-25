# assets

Third-party installers `vmx` pushes to guests. **Binaries are not committed** —
this file records what to fetch and where it goes.

`vmx` reads them from the path in `assets_dir` (`.claude/vmx.toml`), by default:

```
~/.local/share/vmx/assets/
```

| File | Where from | Used by |
|---|---|---|
| `wix314-binaries.zip` *(preferred)* | <https://github.com/wixtoolset/wix3/releases/download/wix3141rtm/wix314-binaries.zip> | `vmx provision agent-win11-arm` |
| `wix314.exe` *(fallback)* | <https://github.com/wixtoolset/wix3/releases/download/wix3141rtm/wix314.exe> | same |

The binaries zip is preferred: extracting it needs no elevation, which an ssh
session does not have, and no .NET Framework 3.5. The `.exe` bundle works too — it
installed cleanly over ssh on the Windows ARM VM with `installer_exit=0`.

Fetched inside the guest, so nothing to place here:

| Tool | Source | Notes |
|---|---|---|
| `cv2pdb.exe` 0.52 | GitHub release, downloaded by `win-packager.ps1` | debug symbols; same version CI pins |
| VS Build Tools `VC.Tools.x86.x64` | `aka.ms/vs/17/release/vs_buildtools.exe`, via `vmx provision --symbols` | ~3GB; supplies the 32-bit `mspdb*.dll` that cv2pdb needs to write PDBs |
