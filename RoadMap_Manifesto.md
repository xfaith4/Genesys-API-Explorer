## Roadmap Manifesto

Here’s the “done right” path if the goal is not “an API explorer,” but an Ops-grade Genesys Cloud intelligence workstation that lets an engineer answer hard questions fast and lets a director walk into a VP meeting with defensible, repeatable metrics.

### North Star: stop being an endpoint browser

Swagger-driven exploration is awesome, but the real product should be:

**Answers → Evidence → Drilldown → Action**

Meaning: you don’t start with `/api/v2/...`. You start with “What’s breaking?”, “What’s degrading?”, “What changed?”, “Where are we bleeding time/money?”, and the app assembles the supporting API calls behind the scenes.

That’s the difference between “useful” and “career-making.”

### Architecture that scales: Core engine + Insight Packs

#### 1. A real module boundary (Core)

Make a single module that is UI-agnostic:

- **Auth + profiles** (region/org/env, multi-tenant, token refresh)
- **Request executor** (rate-limit aware, retry/backoff, paging, concurrency control)
- **OpenAPI loader** (swagger parsing stays, but becomes metadata, not the product)
- **Query runner** (templated queries, job polling, caching, enrichment)
- **Data model** (normalized entities + join keys: `conversationId`, `flowId`, `userId`, `queueId`, `integrationId`, `actionId`)
- **Storage** (SQLite cache + “snapshot” runs so reports are reproducible)

UI becomes just a client of the Core.

#### 2. “Insight Packs” (the magic)

Create curated, versioned packs that define:

- **What question they answer** (e.g., “Flow performance regression”, “Data Action failure hotspots”, “API usage by client/app”, “Top operational errors by impact”)
- **What endpoints are required** (resolved from OpenAPI)
- **How to compute metrics** (PowerShell scriptblocks or a small rules DSL)
- **Thresholds** (warning/critical) + executive narrative templates
- **Drilldowns** (click a metric → show the exact conversations/flows/actions behind it)

Think: “Dashboards as code,” like Terraform but for Genesys insight.

### The metrics stack (what “done right” surfaces first)

You want four primary lenses, each with a “VP-ready top line” and “engineer drilldown”:

#### A. Conversation Quality & Failure

- Peak concurrency by division/queue
- Abandon rate / short calls / transfer loops / repeat callers (where supported)
- WebRTC disconnects, media failures, edge cases (correlated to time + release windows)
- Conversation timelines that automatically annotate: flow step, queue, agent, wrap-up, integration events

#### B. Architect Flow Health

- Flow outcomes: containment, fallback, error exits, loops, long prompts
- Latency proxies: step timing where measurable, or symptom metrics (timeouts, retries)
- Regression detection: “this flow’s failure/transfer rate changed after X date”
- “Top flows by customer impact” = volume × failure rate × time wasted

#### C. Data Actions & Integrations Reliability

- Failures by action, integration, contract, status code, error family
- Timeouts and retries (symptoms of downstream slowness)
- “Blast radius” view: which flows depend on which actions
- “Change correlation”: failures spike after credential rotation / contract change / release

#### D. API Usage & Platform Limits

- Usage by client ID/app, endpoint family, and time
- Rate limit pressure indicators (429s, retries, backoffs)
- “Cost-to-answer” tracking: how many API calls did this report take?
- Hard rule: the tool must not become the thing that causes throttling

#### E. Operational / Audit / Event Signals

Tap into whatever audit/diagnostic/event surfaces are available:

- What changed? Who changed it? When?
- Tie config changes to spikes in errors/failures/latency
- Even if this starts small, it becomes the truth layer for leadership conversations

### UX: “Ops console,” not “developer tool”

The UI should behave like an incident + analytics console:

- **Home page:** Health Summary (Red/Yellow/Green) with top contributors
- **Tabs:** Conversations | Flows | Data Actions | API Usage | Changes/Audit | Reports
- **Find the Why workflow:**
  1. Pick timeframe + scope (org/division/queue/flow)
  2. See top anomalies
  3. Click → auto-build the evidence packet (IDs, timelines, error samples)
  4. Export as a clean artifact

Exports must be first-class:

- Excel (for leadership comfort)
- HTML report bundle (portable + pretty)
- JSON snapshot (reproducible evidence)
- Optional: Elastic/Splunk output if your org uses it

### Engineering discipline: the boring parts that make it unstoppable

If you want this to be “done right,” you treat it like a product:

- **Safety & trust**
  - Default read-only mode
  - If an endpoint is mutating: requires explicit “armed mode” + confirmation
  - Store tokens in Windows Credential Manager / DPAPI-protected storage
  - Full request logging with redaction

- **Performance and rate limits**
  - Global rate-limit manager
  - Paging helpers that never accidentally pull the entire universe
  - Background job polling standardized (analytics jobs)
  - Aggressive caching + TTL rules + snapshot runs

- **Testability**
  - Pester tests for:
    - OpenAPI parsing
    - Pagination correctness
    - Retry/backoff logic
    - Metric computations for each Insight Pack
  - Mock transport layer so tests don’t require live Genesys

- **Release management**
  - CI that lint/tests the module
  - Signed module releases (internal trust matters)
  - Versioned Insight Packs + changelog (“what this report means changed” is a real risk)

### A realistic “done right” roadmap

Here’s a clean pathway that doesn’t collapse under ambition:

1. **Phase 1: Foundation** (2–3 evenings)
   - Carve out Core module
   - Implement auth “properly” + profiles
   - Add executor: paging/retry/backoff/rate-limit
   - Add SQLite cache + “snapshot run” concept
2. **Phase 2: First Insight Packs** (high value, low complexity)
   - Queue/Division smoke detector report
   - Data Action failure hotspot report
   - Flow health regression report (top flows by impact)
   - Export pipeline (Excel + HTML)
3. **Phase 3: Correlation engine** (the “wow” factor)
   - Correlate failures ↔ config changes ↔ release windows ↔ downstream availability
   - Evidence packets: one-click bundle for an incident
4. **Phase 4: Director-grade reporting**
   - Weekly/monthly exec report pack:
     - “Reliability,” “Customer experience,” “Agent experience,” “Automation effectiveness,” “Cost pressure”
   - Narrative templates so the report reads like a tight briefing, not a data dump
5. **Phase 5: Distribution and adoption**
   - MSIX / packaged EXE, auto-update channel internally
   - “Run scheduled reports” mode for managers
   - “Engineer mode” stays interactive

### The blunt truth

Swagger makes it possible to call everything.
But “done right” means curated insight > raw capability.

Your differentiator isn’t that you can hit every endpoint.
It’s that you can take a director from “We feel like we’re having issues” to:

- Here’s what broke
- Here’s when it started
- Here’s the blast radius
- Here’s the evidence
- Here’s the fix target
- Here’s the ROI story

If you want, next message I’ll lay out a concrete repo structure (folders, module layout, exported function list, Insight Pack schema) that matches this vision and is still very PowerShell-native.

## PR roadmap

### PR 2 — Single source of truth: move transport + toolkit into Core

Right now you have overlapping logic spread across:

- `Scripts/GenesysCloud.ConversationToolkit/*.psm1`
- `Scripts/*.ps1` (timeline, smoke drill, reports)
- the big GUI script `GenesysCloudAPIExplorer.ps1`

**Done right rule:** The UI never calls `Invoke-RestMethod` directly. Everything funnels through one request executor: `Invoke-GCRequest`.

PR2 is:

- Move the 8 toolkit functions into `src/GenesysCloud.OpsInsights/Public`
- Make the module export explicit functions only
- Make rate-limit safety a hard default (429/5xx backoff, paging guards, request tracing with redaction)

**Result:** every future feature rides the same safe transport.

### PR 3 — Fix the biggest “product smell”: GUI auto-runs

`GenesysCloudAPIExplorer.ps1` currently ends with:

```
$Window.ShowDialog() (auto-launch)
```

That’s fine for a script but it’s poison for a module.

PR3 is:

- Move GUI into `apps/OpsConsole/`
- Wrap startup into one entrypoint (`Start-GCAPIExplorer` or rename to `Start-GCOpsConsole`)
- Move XAML/resources into `apps/OpsConsole/Resources/`
- Keep state in `$script:` scope inside the UI module, not global

**Result:** `Import-Module` becomes safe, predictable, testable.

### PR 4 — The first real “answers-first” experience: Insight Packs

Swagger browsing stays (engineers love it), but it stops being the star.

The app’s home becomes:

- Health summary (R/Y/G)
- “Top Anomalies” (queues, flows, actions, API pressure)
- Click → evidence packet (conversations/flow steps/errors)

We ship 3 packs first (high value, low complexity):

- Queue Smoke Detector (triage)
- Data Action Failure Hotspots (blast radius + trends)
- Flow Health Regression (before/after change windows)

Each pack produces:

- Metrics + thresholds
- Drilldown object lists
- Export bundle (Excel + HTML + JSON snapshot)

### PR 5 — Director-grade correlation and “briefing exports”

This is the VP-justification layer:

- “What changed?” correlation (audit/config change → spikes)
- Release window correlation
- Downstream dependency correlation (flow → data action → integration)
- One-click briefing pack export (clean narrative + evidence appendix)

This is where the tool becomes legendary.
