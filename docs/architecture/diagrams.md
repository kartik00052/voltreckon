# Architecture diagrams

All diagrams describe the **intended** implementation. None implies shipped code.

---

## 1. C4 Level 1 — System context

```mermaid
flowchart TB
  CPO[CPO systems<br/>CSMS, billing, CSV exports]
  EMSP[eMSP systems<br/>billing, partner portal]
  FIN[Finance and operations users]
  IDP[Identity provider]
  IRP[IRP e-invoice platform<br/>Phase 2]
  UBC[UBC / Beckn network<br/>Phase 2]
  HUB[Roaming hub<br/>optional upstream]

  VR[VoltReckon<br/>reconciliation and settlement workbench]

  CPO -->|OCPI CDRs, tariffs, invoices| VR
  EMSP -->|partner invoices, CDRs, disputes| VR
  FIN -->|HTTPS API / UI| VR
  VR -->|invoice data, reconciliation, statements| CPO
  VR -->|reconciliation, credit notes, statements| EMSP
  VR -.->|JWT validation| IDP
  VR -.->|e-invoice payload| IRP
  VR -.->|transaction records| UBC
  HUB -.->|CDR exchange| CPO
  HUB -.->|CDR exchange| EMSP
```

**Boundary:** VoltReckon owns financial records. It does not own chargers, driver payments, or network routing.

---

## 2. C4 Level 2 — Containers

```mermaid
flowchart TB
  subgraph User[Users]
    BROWSER[Browser / API client]
  end
  subgraph Platform[VoltReckon platform]
    API[REST API<br/>Spring Boot 4.1 / Java 25]
    JOB[Scheduled jobs<br/>rating, reconciliation, settlement]
    DB[(PostgreSQL 18)]
    OBJ[(Object storage<br/>Phase 2)]
  end
  subgraph Ext[External]
    PARTNER[Partner systems]
    IDP[Identity provider]
    PROM[Prometheus / Grafana]
  end
  BROWSER -->|HTTPS + JWT| API
  PARTNER -->|HTTPS + OAuth2 client credentials| API
  API --> DB
  JOB --> DB
  API -.->|evidence files| OBJ
  API -.->|token validation| IDP
  API -->|metrics| PROM
```

MVP contains exactly one application container and one database container. Jobs run inside the application.

---

## 3. Module/component diagram

```mermaid
flowchart TB
  subgraph API_In[Inbound adapters]
    REST[REST controllers]
    CSV[CSV importers]
    SCHED[Schedulers]
  end
  subgraph Modules[Domain modules]
    PARTNER[partner]
    AGR[agreement]
    TAR[tariff]
    CDR[cdr]
    RAT[rating]
    INV[invoicing]
    REC[reconciliation]
    LED[ledger]
    SET[settlement]
    DIS[dispute]
    REP[reporting]
  end
  subgraph Platform[platform]
    MONEY[money]
    SEC[security]
    TAX[tax]
    AUD[audit]
    OUT[outbox]
    ERR[error]
  end
  subgraph Out[Outbound adapters]
    JPA[JPA repositories]
    OC[OCPI adapter]
    IRP[IRP adapter]
    ST[storage adapter]
  end
  REST --> Modules
  CSV --> CDR
  SCHED --> RAT
  SCHED --> REC
  SCHED --> SET
  Modules --> Platform
  Modules --> JPA
  JPA --> DB[(PostgreSQL)]
  CDR --> OC
  INV --> IRP
  DIS --> ST
```

---

## 4. Primary workflow — CDR to settlement

```mermaid
sequenceDiagram
  autonumber
  participant P as Partner system
  participant A as API
  participant C as cdr
  participant R as rating
  participant I as invoicing
  participant L as ledger
  participant X as reconciliation
  participant S as settlement
  participant D as DB
  participant U as Finance user

  P->>A: POST /api/v1/cdrs (Idempotency-Key)
  A->>C: IngestCdr command
  C->>D: insert cdr (immutable) + outbox
  C-->>A: 201 or 200 duplicate
  A-->>P: result

  U->>A: POST /api/v1/rating-runs
  A->>R: RunRating
  R->>D: read cdr, tariff_version, agreement
  R->>D: insert rating_result + lines + variance
  R-->>A: run summary

  U->>A: POST /api/v1/invoices
  A->>I: DraftInvoice
  I->>D: insert invoice + lines + tax lines (draft)
  U->>A: POST /api/v1/invoices/{id}/issue
  I->>D: lock, assign number, mark issued
  I->>L: post journal (same transaction or outbox)
  L->>D: insert journal_entry + lines
  I-->>A: issued invoice

  U->>A: POST /api/v1/reconciliation-runs
  A->>X: Reconcile(partner invoice)
  X->>D: match lines, insert exceptions
  X-->>A: summary

  U->>A: POST /api/v1/settlement-runs
  A->>S: Settle(partner, period)
  S->>D: advisory lock, net items, insert statement
  S->>L: post settlement journal
  S-->>A: statement
```

---

## 5. Event flow (transactional outbox)

```mermaid
sequenceDiagram
  participant M as Module (producer)
  participant DB as PostgreSQL
  participant Relay as Outbox relay
  participant H as Module (consumer)
  M->>DB: BEGIN
  M->>DB: write state
  M->>DB: insert outbox_event
  M->>DB: COMMIT
  Relay->>DB: poll pending events
  Relay->>H: deliver event (at-least-once)
  H->>DB: check processed_event / unique key
  H->>DB: apply side effect + mark processed
  Relay->>DB: mark publication complete
```

Failure handling: a consumer failure leaves the publication incomplete and retried with backoff; exhausted retries surface on a dead-letter view and alert.

---

## 6. Entity relationship — core MVP

```mermaid
erDiagram
  PARTNER ||--o{ APP_USER : has
  PARTNER ||--o{ PARTNER_GSTIN : has
  PARTNER ||--o{ PARTNER_AGREEMENT : cpo_or_emsp
  PARTNER_AGREEMENT }o--o{ TARIFF_VERSION : links
  TARIFF ||--o{ TARIFF_VERSION : versions
  TARIFF_VERSION ||--o{ TARIFF_PRICE_COMPONENT : contains
  TARIFF_VERSION ||--o{ TARIFF_RESTRICTION : restricts
  CDR }o--|| PARTNER : belongs_to
  CDR ||--o{ CDR_DIMENSION : details
  CDR ||--o{ CDR_VALIDATION_ISSUE : may_have
  CDR ||--o{ RATING_RESULT : rated_as
  RATING_RUN ||--o{ RATING_RESULT : produces
  RATING_RESULT ||--o{ RATING_LINE : splits
  RATING_RESULT ||--o{ RATING_VARIANCE : compares
  INVOICE ||--o{ INVOICE_LINE : contains
  INVOICE ||--o{ INVOICE_TAX_LINE : taxed_by
  INVOICE_LINE }o--|| RATING_RESULT : bills
  INVOICE ||--o{ CREDIT_NOTE : credited_by
  LEDGER_ACCOUNT ||--o{ JOURNAL_LINE : posted_to
  JOURNAL_ENTRY ||--o{ JOURNAL_LINE : contains
  RECONCILIATION_RUN ||--o{ RECONCILIATION_ITEM : contains
  RECONCILIATION_ITEM ||--o{ RECONCILIATION_EXCEPTION : raises
  SETTLEMENT_RUN ||--o{ SETTLEMENT_ITEM : contains
  SETTLEMENT_RUN ||--o{ SETTLEMENT_STATEMENT : produces
  DISPUTE ||--o{ DISPUTE_EVIDENCE : has
  DISPUTE ||--o{ DISPUTE_EVENT : logs
```

Full column-level definition: [schema.sql](../database/schema.sql).

---

## 7. State machines

### 7.1 Invoice

```mermaid
stateDiagram-v2
  [*] --> DRAFT
  DRAFT --> ISSUED: issue (assign number, post journal)
  DRAFT --> CANCELLED: discard draft
  ISSUED --> PARTIALLY_CREDITED: credit note
  ISSUED --> FULLY_CREDITED: credit note
  PARTIALLY_CREDITED --> FULLY_CREDITED: further credit
  ISSUED --> PAID: settlement matched (Phase 2 bank data)
  PARTIALLY_CREDITED --> PAID: settlement
  FULLY_CREDITED --> CLOSED
  CANCELLED --> [*]
  CLOSED --> [*]
```

MVP stops at `ISSUED`/crediting; `PAID` is informational and driven by reconciliation, not payment execution.

### 7.2 Reconciliation item

```mermaid
stateDiagram-v2
  [*] --> UNMATCHED
  UNMATCHED --> MATCHED: exact key + amount
  UNMATCHED --> AMOUNT_MISMATCH: key found, amount differs
  UNMATCHED --> MISSING_CDR: no CDR
  UNMATCHED --> MISSING_INVOICE_LINE: CDR not on invoice
  AMOUNT_MISMATCH --> RESOLVED: accept tolerance or adjust
  MISSING_CDR --> RESOLVED: provide CDR
  MISSING_INVOICE_LINE --> RESOLVED: add line
  MATCHED --> [*]
  RESOLVED --> [*]
```

### 7.3 Dispute

```mermaid
stateDiagram-v2
  [*] --> OPEN
  OPEN --> UNDER_REVIEW
  UNDER_REVIEW --> ACCEPTED
  UNDER_REVIEW --> REJECTED
  ACCEPTED --> RESOLVED: credit note / adjustment
  REJECTED --> CLOSED
  RESOLVED --> CLOSED
  OPEN --> WITHDRAWN
  WITHDRAWN --> CLOSED
```

### 7.4 Settlement run

```mermaid
stateDiagram-v2
  [*] --> DRAFT
  DRAFT --> LOCKED
  LOCKED --> COMPLETED
  LOCKED --> FAILED
  FAILED --> LOCKED: retry
  COMPLETED --> [*]
```

---

## 8. Rating detail flow

```mermaid
flowchart TD
  A[Load CDR] --> B{Credit CDR?}
  B -->|yes| C[Load original CDR + rating]
  B -->|no| D[Find active agreement]
  C --> D
  D --> E[Find tariff version effective at session time]
  E --> F[Evaluate restrictions]
  F --> G{Applicable element?}
  G -->|no| H[RatingFailed: NO_ELEMENT]
  G -->|yes| I[Compute components]
  I --> J[Apply tax rules]
  J --> K[Sum and compare to declared total]
  K --> L[Write rating result, lines, variance]
  L --> M[Emit RatingCompleted]
```

---

## 9. Deployment — MVP and production

### 9.1 Local development

```mermaid
flowchart LR
  DEV[Developer machine] -->|docker compose| PG[(postgres:18)]
  DEV -->|mvn spring-boot:run| APP[VoltReckon :8080]
  APP --> PG
```

### 9.2 Small production

```mermaid
flowchart TB
  LB[Reverse proxy / TLS] --> APP[VoltReckon container]
  APP --> PG[(Managed PostgreSQL<br/>backups + PITR)]
  APP --> OBS[Logs / metrics]
  BACKUP[Backup job] --> PG
```

### 9.3 Growth (Phase 2+)

```mermaid
flowchart TB
  LB[Load balancer] --> APP1[App instance 1]
  LB --> APP2[App instance 2]
  APP1 --> PG[(PostgreSQL primary)]
  APP2 --> PG
  PG --> REPL[(Read replica)]
  APP1 --> OBJ[(Object storage)]
  APP2 --> OBJ
  APP1 --> OTEL[OpenTelemetry collector]
  APP2 --> OTEL
```

No Kubernetes requirement. Multiple app instances are safe because the app is stateless and locking is in PostgreSQL.

---

## 10. Data flow for tax and ledger

```mermaid
flowchart LR
  CDR[CDR energy/time] --> RATING[Rated components]
  TAX[Versioned tax rule] --> RATING
  RATING --> LINE[Invoice line + tax line]
  LINE --> INV[Issued invoice]
  INV --> JE[Journal entry]
  JE --> JL[Journal lines]
  JL --> TB[Trial balance]
  INV --> RECON[Reconciliation]
  RECON --> SET[Settlement statement]
```
