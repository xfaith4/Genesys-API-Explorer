# Peak Concurrent Voice Call Volume (Monthly)

## Endpoints Used

- `POST /api/v2/analytics/conversations/details/jobs` – start monthly voice-only job.
- `GET /api/v2/analytics/conversations/details/jobs/{jobId}` – poll completion.
- `GET /api/v2/analytics/conversations/details/jobs/{jobId}/results` – stream all pages via cursor.
- Validation: `POST /api/v2/analytics/conversations/details/query` for a single 24-hour slice.

## Methodology

1. Submit an Analytics Conversation Detail Job filtered to `mediaType = voice` and ordered by `conversationStart`.
2. Stream results page-by-page; for each conversation with a completed `conversationEnd`, add `+1` at the floored start minute and `-1` at the exclusive end minute (sweep-line delta).
3. Accumulate deltas in order to find the minute with the highest simultaneous call count (all trunks/edges).
4. Optional offline validation accepts pre-loaded conversation detail objects to re-run the sweep without the API.

## Validation Query (1-Day Detail)

```json
POST /api/v2/analytics/conversations/details/query
{
  "interval": "2024-02-16T00:00:00.000Z/2024-02-17T00:00:00.000Z",
  "order": "asc",
  "orderBy": "conversationStart",
  "paging": { "pageNumber": 1, "pageSize": 25 },
  "segmentFilters": [
    {
      "type": "and",
      "predicates": [
        { "type": "dimension", "dimension": "mediaType", "operator": "matches", "value": "voice" }
      ]
    }
  ]
}
```

Run the minute-level sweep on the 1-day payload and confirm it matches the peak minute produced by the monthly job.

## Result (Fixture Data)

Using `tests/fixtures/ConversationDetails.sample.json` as a monthly sample:

- **Peak concurrent voice calls:** `10`
- **First peak minute (UTC):** `2024-02-16T18:23:00Z`
- **Rationale:** The sweep-line deltas show ten overlapping voice sessions at that minute; no other minute exceeds this concurrency.

Use production intervals (e.g., `2025-11-01T00:00:00Z/2025-12-01T00:00:00Z`) to compute your live monthly statistic with `Get-GCPeakConcurrentVoice`.
