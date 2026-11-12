# Operations runbook

**Scope:** local development operations for the blueprint, plus the production procedures the MVP is designed for.

**Reality check:** the application does not exist yet. Commands that depend on `backend/` are marked **after M1**. The PostgreSQL commands work with the compose file in this repository.

---

## 1. Local environment

### 1.1 Prerequisites

| Tool | Version | Check |
|---|---|---|
| Docker Desktop / engine | Current | `docker --version` |
| Docker Compose | v2+ | `docker compose version` |
| JDK | 25 | `java -version` (after M1) |
| Maven | 3.9+ | `mvn -version` (after M1) |
| `make` | Optional | `make --version` |

On Windows, run PowerShell commands from the repository root. `make` requires WSL, Git Bash, or Chocolatey; the equivalent `docker compose` commands are always provided.

### 1.2 Start PostgreSQL

```powershell
Copy-Item .env.example .env
docker compose up -d postgres
docker compose ps
```

Wait for `healthy`, then connect:

```powershell
docker compose exec postgres psql -U voltreckon -d voltreckon
```

### 1.3 Apply the design schema manually (optional)

The application applies Flyway migrations after M1. To inspect the blueprint schema directly:

```powershell
Get-Content docs/database/schema.sql | docker compose exec -T postgres psql -U voltreckon -d voltreckon
```

This creates the `voltreckon` schema and tables. It is not a substitute for migrations in a real environment.

### 1.4 Stop and reset

```powershell
docker compose down
```

Destructive reset (deletes the volume):

```powershell
docker compose down -v
```

### 1.5 Run the application (after M1)

```powershell
Set-Location backend
mvn spring-boot:run
```

```powershell
curl.exe http://localhost:8080/actuator/health
```

Stop with `Ctrl+C`.

---

## 2. Configuration

| Variable | Default | Production guidance |
|---|---|---|
| `POSTGRES_DB` | `voltreckon` | Managed database name |
| `POSTGRES_USER` | `voltreckon` | Least-privilege application user |
| `POSTGRES_PASSWORD` | `voltreckon_local_only` | Secret manager; never commit |
| `POSTGRES_PORT` | `5432` | Not exposed publicly |
| `SPRING_PROFILES_ACTIVE` | `local` | `prod` |
| `JWT_ISSUER_URI` | — | IdP issuer |
| `JWT_AUDIENCE` | — | API audience |
| `INTEGRATION_IRP_ENABLED` | `false` | `true` only after sandbox sign-off |
| `INTEGRATION_UBC_ENABLED` | `false` | Experimental only |

Rules:

- No production secret has a default.
- Configuration is typed (`@ConfigurationProperties`), validated at startup.
- Feature flags default off.

---

## 3. Database migrations

- Flyway runs as a release step, not on application startup in production.
- Migration user has DDL rights; application user does not.
- Back up before destructive changes.
- Use expand/contract for breaking changes.

Commands (after M1):

```powershell
mvn -pl backend flyway:info
mvn -pl backend flyway:migrate
mvn -pl backend flyway:validate
```

**Never** run `flyway:clean` against a shared or production database.

---

## 4. Routine checks

### 4.1 Health

```powershell
curl.exe -s http://localhost:8080/actuator/health | ConvertFrom-Json
```

Expected: `status = UP`, database component `UP`.

### 4.2 Metrics

```powershell
curl.exe -s http://localhost:8080/actuator/prometheus
```

Watch:

- `cdr_ingest_total{result="failed"}`
- `outbox_pending_age_seconds`
- `rating_failed_total`
- `reconciliation_exception_open`
- `settlement_run_failed_total`
- `http_server_errors_total`

### 4.3 Database size and connections

```sql
SELECT pg_size_pretty(pg_database_size(current_database()));

SELECT state, count(*)
  FROM pg_stat_activity
 WHERE datname = current_database()
 GROUP BY state;
```

### 4.4 Outbox backlog

```sql
SELECT count(*) AS pending,
       min(created_at) AS oldest,
       now() - min(created_at) AS age
  FROM outbox_event
 WHERE publication_status = 'PENDING';
```

Alert if `age > 5 minutes`.

### 4.5 Trial balance

```sql
SELECT entity_partner_id,
       sum(total_debit_minor) AS debits,
       sum(total_credit_minor) AS credits,
       sum(balance_minor) AS net
  FROM v_trial_balance
 GROUP BY entity_partner_id;
```

Debits must equal credits; net must be zero for a balanced set of books.

---

## 5. Backup and restore

### 5.1 Production

- Managed PostgreSQL with automated daily backups and PITR (WAL).
- Encrypted backups in a separate account/project.
- Quarterly restore drill.

### 5.2 Local backup

```powershell
docker compose exec -T postgres pg_dump -U voltreckon -d voltreckon -Fc > .\voltreckon.dump
```

### 5.3 Local restore

```powershell
docker compose exec -T postgres pg_restore -U voltreckon -d voltreckon --clean --if-exists < .\voltreckon.dump
```

### 5.4 Restore drill checklist

1. Restore to a scratch instance, never over production.
2. Run Flyway `validate`.
3. Verify row counts for `cdr`, `invoice`, `journal_entry`, `journal_line`.
4. Run the trial balance query; confirm debits = credits.
5. Spot-check one invoice and its journal.
6. Record the time taken and compare to RTO.

---

## 6. Incident procedures

### 6.1 Ingestion failure spike

1. Check `cdr_ingest_total{result}` and application logs by `correlation_id`.
2. Inspect `cdr_validation_issue` for the dominant code.
3. If partner-side: contact the partner, do not relax validation silently.
4. If our bug: roll back the deployment if the failure started with it.
5. Replay the failed batch with the original `Idempotency-Key` once fixed.

### 6.2 Outbox backlog

1. Check relay health and logs.
2. Inspect `outbox_event` for repeated `last_error`.
3. Fix the consumer; replay pending events.
4. Do not delete pending events to clear the alert.

### 6.3 Duplicate billing suspected

1. Query `rating_result` and `invoice_line` for the CDR.
2. Check `cdr` for a credit without a matching original.
3. If a duplicate invoice was issued: issue a credit note (never edit).
4. Record the incident and add a regression test.

### 6.4 Unbalanced journal alert

This should be impossible due to the deferred trigger. If it occurs:

1. Stop writes (maintenance mode).
2. Find entries where debits ≠ credits using SQL.
3. Do not "fix" by editing; create a correcting entry or restore from backup.
4. Investigate how the trigger was bypassed (superuser, disabled trigger, direct load).
5. Write a post-incident review and a test.

### 6.5 Settlement contention

1. Check for a long-running settlement transaction holding the advisory lock.
2. Inspect `pg_locks` and `pg_stat_activity`.
3. Terminate only the specific backend if it is stuck.
4. Re-run settlement; verify no double settlement.

### 6.6 Security incident

1. Revoke the affected credentials/tokens.
2. Suspend the partner if necessary.
3. Preserve audit logs and relevant DB snapshots.
4. Assess personal-data impact (DPDP).
5. Notify per policy and law.
6. Post-incident review.

---

## 7. Deployment

### 7.1 Small production

1. Build the image.
2. Run Flyway migrations with the migration role.
3. Start the new container.
4. Check readiness.
5. Shift traffic.
6. Keep the previous image for rollback.

### 7.2 Rollback

- Application: redeploy the previous image.
- Database: forward-fix preferred. Restore from PITR only for data corruption, and accept data loss to the restore point.
- Feature flags: disable the integration/feature that caused the problem before rolling back the whole app.

### 7.3 Zero-downtime rules

- Migrations must be backward compatible with the previous app version.
- Add columns as nullable or with safe defaults; backfill separately.
- Do not drop or rename columns in the same release as the code change.

---

## 8. Monitoring and alerting (targets)

| Alert | Threshold | Action |
|---|---|---|
| Ingestion failure ratio | > 5% for 10 min | Follow 6.1 |
| Outbox oldest pending | > 5 min | Follow 6.2 |
| Rating failures | > 1% of a run | Inspect tariff/agreement data |
| Open reconciliation exceptions | > agreed backlog | Staff review |
| Settlement failures | > 0 | Inspect immediately |
| HTTP 5xx ratio | > 1% for 10 min | Check DB and app logs |
| DB connections | > 80% of pool | Investigate leaks |
| Disk usage | > 80% | Expand or archive |
| Replication lag | > 30 s | Check managed DB status |

---

## 9. Data retention and privacy operations

- Financial records: retain per statutory and contractual requirements.
- Operational logs: retain 30–90 days.
- Idempotency keys: expire after 24–72 hours.
- Processed events: purge after 30 days.
- Completed outbox events: archive/purge after 30 days.
- Personal data: minimise at ingestion; support access/correction requests per DPDP.
- Evidence files (Phase 2): private storage, access logging, retention policy.

---

## 10. Common SQL snippets

```sql
-- CDRs ingested in the last 24 hours
SELECT count(*) FROM cdr WHERE ingested_at > now() - interval '24 hours';

-- Quarantined CDRs by issue
SELECT issue_code, count(*)
  FROM cdr_validation_issue
 GROUP BY issue_code
 ORDER BY count(*) DESC;

-- Open exceptions by type
SELECT exception_type, count(*)
  FROM reconciliation_exception
 WHERE status = 'OPEN'
 GROUP BY exception_type;

-- Invoice totals for a period
SELECT status, count(*), sum(total_minor)
  FROM invoice
 WHERE issue_date >= DATE '2026-11-01'
   AND issue_date <  DATE '2026-12-01'
 GROUP BY status;

-- Journal entries for a source
SELECT je.*
  FROM journal_entry je
 WHERE je.source_type = 'INVOICE'
   AND je.source_id = '00000000-0000-0000-0000-000000000000';

-- Advisory locks currently held
SELECT pid, locktype, mode, granted, objid
  FROM pg_locks
 WHERE locktype = 'advisory';
```

---

## 11. On-call checklist (first 10 minutes)

1. Confirm the alert is real (not a stale dashboard).
2. Check `/actuator/health` and the database.
3. Identify the blast radius: ingestion, rating, invoicing, ledger, settlement.
4. Check recent deployments and feature-flag changes.
5. Preserve logs and snapshots before changing anything.
6. Mitigate: disable the failing feature, roll back, or pause jobs.
7. Communicate status and next update time.
8. After recovery: write the timeline, root cause, and follow-up issues.

---

## 12. Known operational limitations

- No production deployment exists yet.
- No automated backup job in the local compose file (manual `pg_dump`).
- No alerting wired in the MVP; metrics endpoints only.
- No evidence file storage until Phase 2.
- No multi-region failover.
- UBC/IRP integrations are not implemented.
