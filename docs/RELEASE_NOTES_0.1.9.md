# Finzy 0.1.9 – Release notes (for GitHub release)

### Store distribution

- **Google Play**: Switched to custom upload script for more reliable bundle attachment to internal testing releases.
- **Amazon**: Release notes now pulled from GitHub release and set for en-US before commit.
- **TestFlight**: Automated review info (demo account, test instructions) before Beta App Review.

### Fixes

- Google Play draft releases now correctly attach the app bundle.
- Amazon commit requires If-Match header and en-US recent changes.
- WinGet workflow pulls before push to avoid conflicts with other release jobs.
