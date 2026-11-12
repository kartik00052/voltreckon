# Reliability and failure handling

**Principle:** financial records must be **correct or absent**, never silently wrong. A failed operation should be visible, retryable, and idempotent.

---

## 1. Reliability requirements

| Requirement | Target (MVP) | Mechanism |
|---|---|---|
| No lost CDR after a `2xx` response | 100% | Commit before responding; outbox in the same transaction |
| No duplicate financial record on retry | 100% | Idempotency keys + unique constraints |
| No unbalanced journal | 100% | Deferred constraint trigger |
| Recoverable failed jobs | 100% | Run records, checkpoints, restartable chunks |
| RPO | ≤ 15 minutes (PITR) | WAL archiving |
| RTO | ≤ 4 hours | Documented restore procedure |
| Ingestion availability | 99.5% monthly (MVP) | Single region, managed DB |
| Observable failures | 100% of async paths | Metrics, outbox lag, alerts |

These are design targets, not measured results.

---

## 2. Failure catalogue

| # | Failure | Detection | Impact | Response |
|---|---|---|---|---|
| F1 | Partner retries a CDR POST | Duplicate key / idempotency record | None if handled | Return original response |
| F2 | Same CDR via different payload serialisation | Content hash differs | Possible duplicate | Business-key unique constraint catches; hash mismatch logged |
| F3 | Credit CDR arrives before original | Missing `credit_reference_id` target | Quarantine | Retry after original; alert if stale |
| F4 | Rating job crashes mid-run | Run status `RUNNING` stale | Partial results | Resume from checkpoint; idempotent inserts |
| F5 | Tariff changed during a long run | Version pinned at start of each item | None | Each rating pins one version |
| F6 | Invoice issue request times out | Client retries | Duplicate invoice | Idempotency key + unique source reference |
| F7 | Sequence contention on invoice numbers | Lock wait / deadlock | Slow issue | Row lock with short transaction; retry |
| F8 | Ledger posting fails after invoice issued | Transaction rollback or outbox pending | Missing journal | Same transaction or outbox retry; alert |
| F9 | Outbox relay stops | Pending event count rises | Delayed side effects | Liveness check + alert; restart relay |
| F10 | Consumer processes event twice | Duplicate side effect | Double posting | Processed-event table / unique key |
| F11 | Reconciliation run overlaps another | Advisory lock contention | Rejected run | Return `409`; user retries after completion |
| F12 | Settlement run crashes after locking | Lock held until transaction ends | Blocked retries | Transaction-scoped advisory lock releases on rollback |
| F13 | Database failover | Connection errors | Brief unavailability | Retry with backoff; managed DB handles promotion |
| F14 | Disk full | Insert failures, alerts | Write outage | Alerts, retention, volume monitoring |
| F15 | Clock skew between nodes | Timestamp anomalies | Ordering issues | NTP; store server time; sequence numbers for ordering |
| F16 | Large CSV import | Timeout / memory | Partial import | Streamed, chunked, resumable with a batch ID |
| F17 | External IRP outage (Phase 2) | HTTP errors | Pending e-invoice | Retry queue; invoice remains valid internally |
| F18 | Poison event repeatedly failing | Retry exhaustion | Stuck side effect | Dead-letter view; manual replay after fix |

---

## 3. Idempotency

### 3.1 Inbound HTTP

- `Idempotency-Key` required on financial POSTs.
- Key scoped to `(partner_id, route, key)`.
- Store request hash, response status, response body hash, and expiry (for example, 24–72 hours).
- Replay with same key and same body → stored response.
- Same key with different body → `409 IDEMPOTENCY_KEY_REUSED`.
- Keys are never reused across different routes.

### 3.2 Database

Unique constraints are the final authority:

- `cdr (partner_pair_id, cdr_external_id)`
- `rating_result (cdr_id)` active
- `invoice_line (rating_result_id)`
- `journal_entry (source_type, source_id, entry_type)`
- `settlement_item (journal_line_id)`

The application checks first for a friendly response; the constraint prevents races.

### 3.3 Events

Consumers record `(consumer, event_id)` in `processed_event` (or rely on a natural unique key) before applying side effects, in the same transaction.

---

## 4. Retries

| Operation | Retry? | Policy |
|---|---|---|
| Client HTTP POST | Yes, with idempotency key | Exponential backoff, jitter |
| DB deadlock/serialization failure | Yes | Retry 3×, short delay |
| Outbox delivery | Yes | Exponential backoff, max attempts, alert |
| External adapter (IRP/UBC) | Yes | Only for idempotent operations; cap and dead-letter |
| Rating/reconciliation job | Yes | Restart from checkpoint, not blind full rerun |
| Settlement | No automatic retry after completion | Requires a new run, explicitly |

Never retry a non-idempotent operation that changes money without a key.

---

## 5. Transactional outbox

- Event row inserted in the same transaction as the state change.
- Relay polls pending rows with `FOR UPDATE SKIP LOCKED`.
- Delivery is at-least-once; consumers are idempotent.
- Publication status: `PENDING`, `COMPLETED`, `FAILED`.
- Metrics: pending count, oldest pending age, failure count.
- Alert if oldest pending age exceeds a threshold (for example, 5 minutes).
- Manual replay tool for dead-letter events (Phase 2 admin API).

---

## 6. Jobs and checkpoints

Long jobs use a run record:

| Field | Purpose |
|---|---|
| `run_id` | ULID |
| `type` | `RATING`, `RECONCILIATION`, `SETTLEMENT`, `EXPORT` |
| `status` | `PENDING`, `RUNNING`, `COMPLETED`, `FAILED`, `CANCELLED` |
| `cursor` | Last processed key |
| `processed_count`, `failed_count` | Progress |
| `started_at`, `finished_at` | Timing |
| `error` | Last error summary |

Rules:

- Chunk size bounded (for example, 500 CDRs).
- Each chunk commits independently and updates the cursor.
- A stale `RUNNING` run (heartbeat older than N minutes) can be resumed.
- Cancellation is cooperative between chunks.

---

## 7. Concurrency control

| Concern | Mechanism |
|---|---|
| Duplicate CDR | Unique constraint + `ON CONFLICT` handling |
| Invoice number | `SELECT ... FOR UPDATE` on the sequence row |
| Settlement per partner/period | `pg_advisory_xact_lock(hash(partner_pair, period))` |
| Reconciliation overlap | Advisory lock per partner/period |
| Period close | Row lock on `accounting_period`; reject postings after |
| Optimistic edits | `version` column on mutable aggregates (partner, tariff metadata, dispute) |
| Reporting reads | Read Committed; long exports use a repeatable-read snapshot |

Isolation: default `READ COMMITTED`; use `REPEATABLE READ` for multi-statement reconciliation reads where a consistent snapshot matters. Avoid `SERIALIZABLE` unless a specific invariant demands it.

---

## 8. Backups and recovery

- Daily full backup plus continuous WAL archiving (PITR) via the managed database.
- Backups encrypted; restore tested quarterly.
- Migration rollback strategy: forward-only migrations; destructive changes use expand/contract.
- Evidence files (Phase 2): object storage versioning and lifecycle rules.
- Recovery runbook: [operations/01-runbook.md](../operations/01-runbook.md).

**Restore drill checklist:** restore to a scratch instance, run Flyway validation, verify row counts for key tables, run trial balance query, compare a sample invoice, then discard.

---

## 9. Monitoring and alerting

### Metrics

| Metric | Alert condition |
|---|---|
| `cdr_ingest_total{result}` | Failure ratio > 5% for 10 min |
| `cdr_duplicate_total` | Sudden spike (possible partner bug) |
| `rating_failed_total` | > 1% of run |
| `reconciliation_exception_open` | Backlog above threshold |
| `outbox_pending_age_seconds` | > 300 |
| `journal_post_failed_total` | > 0 |
| `settlement_run_failed_total` | > 0 |
| `http_server_errors_total` | > 1% for 10 min |
| DB connections, replication lag, disk | Standard thresholds |

### Health endpoints

- `/actuator/health/liveness` — process alive.
- `/actuator/health/readiness` — DB reachable, migrations applied, outbox relay healthy.
- Do not expose detailed health data publicly.

### Logs

Structured JSON with `correlation_id`, `partner_id`, `run_id`. No PII, tokens, or payload bodies.

---

## 10. Graceful degradation

| Dependency down | Behaviour |
|---|---|
| Database | API returns `503`; no writes accepted; readiness fails |
| Outbox relay | API continues; side effects delayed; alert |
| IRP (Phase 2) | Invoices issued internally; e-invoice queued |
| UBC (Phase 2) | Core workflows unaffected (feature-flagged) |
| Object storage (Phase 2) | Dispute evidence upload rejects; disputes still openable with metadata |

The core CDR → rating → invoice → ledger path has no dependency outside PostgreSQL in the MVP.

---

## 11. Data integrity checks

Scheduled (daily) checks that alert rather than auto-fix:

- Journal entries where debits ≠ credits (should be impossible).
- Invoices whose line sums ≠ header totals.
- Rating results whose lines sum ≠ subtotal.
- Settlement statements whose items sum ≠ net amount.
- CDRs with a credit reference that is not `credit=true`.
- Duplicate active rating results per CDR.
- Orphaned outbox events older than a threshold.
- Posted entries in a closed period.

Results are written to a `integrity_check_result` table (Phase 2) or emitted as metrics/log alerts (MVP).
