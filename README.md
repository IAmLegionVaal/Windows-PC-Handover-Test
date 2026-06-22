# Windows PC Handover Test

> **Testing note:** This was tested by me to be working. User experience may vary.

Included: `Test-WindowsPCHandover.ps1`

```powershell
.\Test-WindowsPCHandover.ps1
.\Test-WindowsPCHandover.ps1 -MinimumFreeSpacePercent 20
```

Creates CSV, JSON and HTML checks for Windows, hardware, storage, devices, protection, network, activation and updates.

Reports: `C:\Users\Public\Documents\WindowsPCHandoverReports`

Exit codes: `0` passed, `1` fatal error, `2` warnings or failed checks.

Review results before handover. MIT License.
