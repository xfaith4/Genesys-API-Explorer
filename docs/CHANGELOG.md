# Changelog

## 2025-12-19 — PR2 transport consolidation
- Centralized all script and UI HTTP calls through `Invoke-GCRequest` with retry/tracing.
- Added the OpsInsights Core manifest to surface shared exports for briefing outputs.
- Expanded Pester coverage for explicit exports and the mockable request executor.
