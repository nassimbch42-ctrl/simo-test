# Diagnostic Rules

## Status semantics

| Status | Meaning |
|---|---|
| NORMAL | Available evidence is consistent with normal operation for the measured property. It is not a guarantee of perfect hardware. |
| ATTENTION | Evidence indicates a condition worth checking, but does not by itself prove a hardware failure. |
| ANOMALY_DETECTED | A concrete software-visible error condition was detected. |
| NOT_DETERMINED | Required telemetry was unavailable or insufficient. |
| NOT_SUPPORTED | The platform/device does not expose the requested capability through the current API. |

## Reliability rules

1. Never invent a measurement.
2. Never treat an unavailable sensor as 0.
3. Never call a device healthy solely because it exists.
4. Prefer multiple independent evidence sources.
5. Separate PnP/driver state from physical hardware condition.
6. Mark physical-only checks explicitly as requiring manual verification.
7. Active stress tests require explicit user initiation and safety thresholds.
