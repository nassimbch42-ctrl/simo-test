# SIMO TEST Roadmap

## Phase 1 — Windows diagnostic CLI
- [x] Structured status model
- [x] Administrator detection
- [x] CPU / RAM / GPU inventory
- [x] Storage inventory and Windows physical-disk health when exposed
- [x] Battery detection
- [x] Motherboard / BIOS
- [x] PnP / drivers
- [x] Network adapters
- [x] Windows / Defender
- [x] TPM / Secure Boot / BitLocker state
- [x] Display / input / audio / camera inventory
- [x] Thermal telemetry when ACPI exposes it

## Phase 2 — Deep hardware evidence
- [ ] NVMe health-log decoding
- [ ] ATA SMART attribute decoding
- [ ] GPU sensor backend
- [ ] CPU package/core temperature backend
- [ ] Fan RPM backend
- [ ] WHEA error correlation
- [ ] Event-log correlation engine
- [ ] Memory diagnostics integration

## Phase 3 — Explicit stress tests
- [ ] CPU stress with abort thresholds
- [ ] RAM test
- [ ] GPU/VRAM test
- [ ] Storage read-only test
- [ ] Thermal stability test
- [ ] Safety interlocks

## Phase 4 — Desktop GUI
- [ ] Native Windows UI
- [ ] Live sensor dashboard
- [ ] Diagnostic history
- [ ] Technician workflow
- [ ] Export/reporting
