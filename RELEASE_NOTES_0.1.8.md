# Finzy 0.1.8

## Release notes (for GitHub release)

### Store distribution improvements

- **TestFlight**: Automated Beta App Review submission with demo account and test instructions. Review info is now set automatically from `.github/testflight-instructions.yaml` before each submission.
- **Google Play**: Release notes are now pulled from the GitHub release body and uploaded with each build to the internal testing track.
- **Amazon Appstore**: Fixed APK replace flow (ETag handling) and improved error handling for upload failures.

### CI/CD updates

- Apple TestFlight upload moved to a dedicated `upload-apple.yml` workflow (runs on release publish).
- Workflow fixes for manual runs and multi-repo contexts.

---

*Paste the content above into the release description when creating the 0.1.8 release on GitHub.*
