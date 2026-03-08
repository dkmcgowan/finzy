# WinGet Manifests for Finzy

These manifests allow Finzy to be installed via [Windows Package Manager (winget)](https://learn.microsoft.com/en-us/windows/package-manager/):

```powershell
winget install dkmcgowan.finzy
```

## Structure

Manifests follow the [winget-pkgs](https://github.com/microsoft/winget-pkgs) layout:

```
winget/manifests/d/dkmcgowan/finzy/<version>/
  dkmcgowan.finzy.yaml
  dkmcgowan.finzy.locale.en-US.yaml
  dkmcgowan.finzy.installer.yaml
```

The `0.1.4` folder is the template. New versions are created automatically on release by the Update WinGet Manifests workflow.

## Submitting to winget-pkgs

The manifests must be submitted to the [microsoft/winget-pkgs](https://github.com/microsoft/winget-pkgs) repository. Two options:

### Option 1: Using wingetcreate (recommended)

1. Install: `winget install wingetcreate`
2. Submit the manifests (from project root):
   ```powershell
   wingetcreate submit --token <GitHub_PAT> winget/manifests/d/dkmcgowan/finzy/
   ```
   Or for updates to an existing package:
   ```powershell
   wingetcreate update dkmcgowan.finzy --url https://github.com/dkmcgowan/finzy/releases/latest/download/finzy-windows-installer.exe --token <GitHub_PAT>
   ```

### Option 2: Manual PR

1. Fork and clone [microsoft/winget-pkgs](https://github.com/microsoft/winget-pkgs)
2. Copy the `winget/manifests/d/dkmcgowan/` folder into `manifests/d/` of winget-pkgs
3. Validate: `winget validate manifests/d/dkmcgowan/finzy/<version>`
4. Submit a pull request

## Updating for new releases

The **Update WinGet Manifests** workflow runs automatically when a release is published. It creates a new version folder with updated manifests and commits to the repo.

To update manually, run `scripts/update-winget.ps1` (optionally with `-Version 0.1.5`).
