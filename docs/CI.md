# GitHub CI and source delivery

The owner authorized this workflow separately from the earlier offline handoff.

- Pull requests to main, pushes to main and manual runs use `.github/workflows/ci.yml`.
- Windows Server 2022 jobs run the same offline suites under Windows PowerShell 5.1 and PowerShell 7. Every test uses synthetic fixtures/mocks, not devices, ADB downloads, private logs or AI providers.
- Each job audits the exact PR head or pushed commit, full Git history and checkout index. PR tests do not substitute a synthetic GitHub merge commit for the submitted source.
- A separate job builds the positive-list source ZIP, re-extracts it and repeats its audit. On main only, the verified source ZIP is uploaded as an Actions artifact with seven-day retention. No diagnostic archives, session files or test work directories are uploaded.
- The stable `CI` check passes only when both matrix jobs and the archive job succeed. Main requires this check and up-to-date branches, with force pushes and deletion disabled. Changes must use PRs after setup; do not bypass protection.
- The workflow token is read-only. Checkout credentials are not persisted. Only exact verified revisions of official checkout/upload-artifact actions are used. There is no pull_request_target execution, custom secret, release creation or automatic diagnostic upload.

Run the Windows test entry point locally with `./scripts/Run-CI.ps1`. It launches each suite in a fresh process of the current PowerShell engine and checks exit codes. The source artifact is not a signed release and does not claim real-device validation.

Only the exact workflow path is allowed by the privacy manifest. All other `.github` automation remains forbidden until separately reviewed. The exact approved public action references are listed in `scripts/Privacy.Core.ps1`; update and review them together with the workflow when upgrading dependencies. These public code hashes are not an exception for arbitrary hashes or private identifiers.
