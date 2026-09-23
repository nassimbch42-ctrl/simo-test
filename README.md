# SIMO TEST

**Professional Windows PC diagnostics and hardware testing platform.**

SIMO TEST is designed for technicians who need evidence-based diagnostics for desktops and laptops.

## Diagnostic principle

SIMO TEST never converts missing telemetry into a false `NORMAL` result. Every module reports one of:

- `NORMAL`
- `ATTENTION`
- `ANOMALY_DETECTED`
- `NOT_DETERMINED`
- `NOT_SUPPORTED`

Software diagnostics cannot physically prove every fault. Intermittent connectors, dead pixels, key switches, speaker distortion and some board-level faults require physical verification.

## Current implementation

The first CLI release runs directly in elevated PowerShell and collects evidence from Windows CIM/WMI, PnP, storage, battery, networking, security and system APIs.

## Run

Open **PowerShell as Administrator**:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\powershell\SimoTest.ps1
```

Quick scan:

```powershell
.\powershell\SimoTest.ps1 -QuickScan
```

Full scan:

```powershell
.\powershell\SimoTest.ps1 -FullScan
```

## Safety

No destructive storage commands are executed by the diagnostic engine. No automatic maximum-load stress test is started. Active stress testing will be introduced as a separate, explicit, safety-gated subsystem.
