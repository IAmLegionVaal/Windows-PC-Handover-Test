# Windows PC Handover Test

> **Testing note:** This was tested by me to be working. User experience may vary.

## One-click use

1. Download and extract the repository.
2. Double-click `Run-OneClick.bat`.
3. The tool runs the full handover assessment directly—there is no menu and it does not change Windows settings.
4. Review the exit code and open `C:\Users\Public\Documents\WindowsPCHandoverReports`.

Included: `Test-WindowsPCHandover.ps1`

## PowerShell usage

```powershell
.\Test-WindowsPCHandover.ps1
.\Test-WindowsPCHandover.ps1 -MinimumFreeSpacePercent 20
```

Creates CSV, JSON and HTML checks for Windows, hardware, storage, devices, protection, network, activation and updates.

Exit codes: `0` passed, `1` fatal error, `2` warnings or failed checks.

Review results before handover. MIT License.
