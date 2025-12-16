# Genesys API Explorer → Ops Insights Console (Done Right Path)

This repo is being evolved from a Swagger-driven endpoint browser into an Ops-grade **Answers → Evidence → Drilldown → Action** workstation for Genesys Cloud.

## Non-negotiables
- **Read-only by default.** Mutating endpoints require explicit "armed" mode.
- **Reproducible outputs.** Every report can be re-run from a saved snapshot.
- **Rate-limit safe.** Central request executor; backoff on 429; no accidental "pull the universe".
- **Evidence packets.** Any headline metric can be drilled into the exact flows / data actions / conversations that produced it.
- **Leadership-ready exports.** Excel + HTML briefing bundle + JSON snapshot.

## Target architecture
### Core module: `GenesysCloud.OpsInsights`
UI-agnostic engine:
- Auth / profiles
- Request executor (retry/backoff/paging/rate limit)
- OpenAPI metadata loader (for discovery + validation)
- Cache + snapshots (JSONL now, SQLite plugin later)
- Insight Pack runner (curated analytics pipelines)

### UI app: `apps/OpsConsole`
WPF/WinUI/Web (choose later). The UI calls module functions; it never directly `Invoke-RestMethod`.

### Insight Packs: `insightpacks/*.json`
Versioned “dashboards as code”:
- Questions answered
- Required endpoints/scopes
- Pipeline steps (queries → joins → metrics → drilldowns)
- Thresholds + narrative templates

## Phased plan (PRs)
### PR 1 — Repo layout + module scaffold (this zip)
- Add `src/GenesysCloud.OpsInsights`
- Add pack schema + 2 example packs
- Add `tools/Build.ps1` + `tests` scaffolding

### PR 2 — Carve GUI into an entrypoint
- Move `GenesysCloudAPIExplorer.ps1` to `apps/OpsConsole`
- Wrap startup into `Start-GCAPIExplorer` (no auto-run on import)
- Replace inline REST calls with `Invoke-GCRequest`

### PR 3 — Auth, profiles, and a “real” transport
- `Connect-GCCloud` with profile support and token refresh hook
- request tracing (sanitized), correlation IDs
- deterministic paging and safe defaults

### PR 4 — First real Insight Packs (high impact)
- Queue/Division Smoke Detector
- Data Action Failure Hotspots
- Flow Health Regression

### PR 5 — Correlation engine + evidence packets
- Change correlation (audit/config change) → metric spikes
- One-click export bundle: XLSX + HTML + raw JSON snapshot

## Definition of Done (for v1)
- A director can open the app, pick a date range, and export a report that includes:
  - top-line metrics with thresholds
  - drilldown links to the underlying objects
  - a consistent narrative summary
  - and a reproducible snapshot file
