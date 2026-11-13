# 04 — Data model

- **Status:** Draft
- **Owner:** VoltReckon maintainer
- **Last verified:** 2026-11-13
- **Applies to phases:** 0–10

This file names tables, columns, constraints, indexes, and owners. SQL lives only in Flyway
migrations under `backend/voltreckon-app/src/main/resources/db/migration`. A table without
an owner here is not part of the model.

## 1. Conventions and rules

- Table names are singular `snake_case`; columns are `snake_case`; booleans use `is_` or a
  positive name (`credit`), never a question.
- Entity IDs are `uuid` (UUIDv4). Append-only child rows may use `bigserial` for ordering.
- Instants are `timestamptz` in UTC. Business dates are `date` in Asia/Kolkata. Durations are
  integer seconds; energy is integer watt-hours; money is `bigint` minor units with
  `char(3)` ISO 4217 currency.
- Enumerations are `text` with a `CHECK` list, not PostgreSQL enum types; adding a value is a
  migration that replaces the constraint.
- JSON is `jsonb` only for bounded detail or vendor payloads, with a size check and a
  documented purpose. No unbounded JSON.
- Every table has `created_at timestamptz NOT NULL DEFAULT now()` unless the table is a
  vendor-managed outbox or a view.
- Soft delete is not used for financial rows. Status and effective dates carry lifecycle.

**DATA-001** Each table MUST have exactly one owning module; only that module writes it.
*Check:* the table map below; migration header; repository package review.

**DATA-002** A public entity ID MUST be `uuid` UUIDv4. `bigserial` MUST NOT appear in an API
response as the entity ID. *Check:* schema review; OpenAPI schema test.

**DATA-003** A cross-module foreign key MUST point only to a module that the owner is allowed
to depend on. `ledger`, `audit`, `platform`, and `reporting` MUST NOT have foreign keys to
domain tables; they use opaque UUID references. *Check:* migration review and the matrix in
section 5.

**DATA-004** A new table or column MUST be added by a forward-only migration, the owning
module spec, and this file in the same change. *Check:* review; `13-build-and-operations`
migration list.

**DATA-005** Financial rows MUST be append-only after issue or posting. The database MUST
enforce this with a trigger where the row is issued or posted. *Check:* trigger tests in
`billing`, `ledger`, `audit`.

**DATA-006** A journal MUST have at least two lines, no zero-value entry, and equal debits
and credits at commit. *Check:* deferred constraint trigger; `JournalBalanceIT`.

**DATA-007** At most one active rating result MAY exist per CDR; a re-rating supersedes the
previous row. *Check:* partial unique index; concurrency IT.

**DATA-008** At most one accepted credit CDR MAY reference an original CDR. *Check:* partial
unique index; credit IT.

**DATA-009** Invoice and credit-note numbers MUST be unique per issuer and financial year.
*Check:* partial unique index; numbering IT.

**DATA-010** A completed settlement MUST be unique per partner pair, period, and currency.
*Check:* partial unique index; settlement concurrency IT.

**DATA-011** An idempotency key MUST be unique per partner, route, and key; a conflicting
request hash MUST NOT create a second result. *Check:* unique index; idempotency IT.

**DATA-012** A raw OCPI payload, if stored, MUST be at most 64 KiB and MUST NOT contain
driver name, phone, email, card data, or bank credentials. *Check:* size check; ingestion
validation test.

## 2. Migration and ownership map

| Migration | Phase | Owner | Tables or views |
|---|---|---|---|
| V001 | 0 | platform | schema `voltreckon`, extensions |
| V002 | 1 | platform | `event_publication`, `processed_event`, `idempotency_key`, `sequence_number` |
| V003 | 1 | partners | `partner`, `partner_role` |
| V004 | 1 | ingestion | `cdr`, `cdr_dimension`, `cdr_validation_issue` |
| V005 | 2 | partners | `partner_gstin`, `partner_agreement` |
| V006 | 2 | iam | `app_user`, `app_user_role` |
| V007 | 2 | tariff | `tax_rate`, `tariff`, `tariff_version`, `tariff_price_component`, `tariff_restriction`, `agreement_tariff_link` |
| V008 | 3 | rating | `rating_run`, `rating_result`, `rating_line`, `rating_variance` |
| V009 | 4 | ledger | `ledger_account`, `accounting_period`, `journal_entry`, `journal_line` |
| V010 | 4 | ledger | chart-of-accounts seed; no schema change |
| V011 | 5 | billing | `invoice`, `invoice_line`, `invoice_tax_line`, `credit_note` |
| V012 | 6 | reconciliation | `reconciliation_run`, `reconciliation_item`, `reconciliation_exception` |
| V013 | 7 | dispute | `dispute`, `dispute_evidence`, `dispute_event` |
| V014 | 8 | settlement | `settlement_run`, `settlement_item`, `settlement_statement` |
| V015 | 9 | audit | `audit_log`, `audit_checkpoint` |
| V016 | 9 | reporting | `rpt_*` read-only views |
| V017 | 10 | reconciliation | OCPI 2.3.0-ed2 invoice-reconciliation link |

`event_publication` is the Spring Modulith 2.1 schema. V002 pins it after generating the
schema in a scratch database; it is platform-owned and never hand-edited. Modulith schema
initialization is disabled.

## 3. Tables by module

### 3.1 platform

| Table | Columns and constraints |
|---|---|
| `event_publication` | Vendor-managed columns: `id uuid`, `listener_id text`, `event_type text`, `serialized_event text`, `publication_date timestamptz`, `completion_date timestamptz`. Index on `(completion_date, publication_date)`. Rows are deleted after completion and retention. |
| `processed_event` | `consumer text`, `event_id uuid`, `processed_at timestamptz`; primary key `(consumer, event_id)`. |
| `idempotency_key` | `id uuid PK`, `partner_ref uuid NOT NULL` (opaque, no FK), `route text`, `idem_key text`, `request_hash char(64)`, `response_status integer`, `response_body text`, `response_hash char(64)`, `created_at`, `expires_at`; unique `(partner_ref, route, idem_key)`; index `expires_at`. |
| `sequence_number` | `name text PK`, `next_value bigint NOT NULL CHECK (> 0)`, `updated_at`. Allocation is a single row update. |

### 3.2 partners

| Table | Columns and constraints |
|---|---|
| `partner` | `id uuid PK`; `country_code char(2)`; `party_id varchar(3)`; `legal_name text`; `display_name text`; `status text` in `ACTIVE`, `SUSPENDED`, `TERMINATED`; `created_at`, `updated_at`, `version bigint`; unique `(country_code, party_id)`. |
| `partner_role` | `partner_id uuid FK partner`, `role text` in `CPO`, `EMSP`; primary key `(partner_id, role)`. |
| `partner_gstin` | `id uuid PK`; `partner_id uuid FK`; `gstin varchar(15)`; `state_code char(2)`; `legal_name`; `is_primary boolean`; `valid_from date`, `valid_to date`; check GSTIN format and date range; unique `gstin`; partial unique `(partner_id) WHERE is_primary`. |
| `partner_agreement` | `id uuid PK`; `cpo_partner_id`, `emsp_partner_id` FKs; `agreement_ref`; `status` in `DRAFT`, `ACTIVE`, `TERMINATED`; `currency char(3)`; `settlement_cycle` in `MONTHLY`, `WEEKLY`, `ON_DEMAND`; `payment_terms_days integer`; `billing_period_basis` in `SESSION_START`, `SESSION_END`, `INVOICE_DATE`; `effective_from`, `effective_to`; `created_at`, `updated_at`, `version`; check parties differ and date range; exclusion constraint prevents overlapping active agreements for the same pair. |

### 3.3 iam

| Table | Columns and constraints |
|---|---|
| `app_user` | `id uuid PK`; `partner_id uuid FK partner NULL`; `subject text NOT NULL UNIQUE`; `display_name text`; `status` in `ACTIVE`, `SUSPENDED`; `is_platform_admin boolean`; `created_at`, `updated_at`; check `partner_id IS NOT NULL OR is_platform_admin`. |
| `app_user_role` | `user_id uuid FK app_user`, `role text` in the role list from 09-security; primary key `(user_id, role)`. |

### 3.4 tariff

| Table | Columns and constraints |
|---|---|
| `tax_rate` | `id uuid PK`; `jurisdiction varchar(8)`; `service_code varchar(8)`; `tax_kind` in `GST`, `VAT`, `NONE`; `rate_bp integer CHECK 0..10000`; `description`; `effective_from date`, `effective_to date`; unique `(jurisdiction, service_code, tax_kind, effective_from)`; check date range. |
| `tariff` | `id uuid PK`; `owner_partner_id uuid FK partner`; `code text`; `name`; `created_at`; unique `(owner_partner_id, code)`. |
| `tariff_version` | `id uuid PK`; `tariff_id FK`; `version_no integer > 0`; `status` in `DRAFT`, `PUBLISHED`, `RETIRED`; `currency char(3)`; `effective_from timestamptz`, `effective_to timestamptz`; `content_hash char(64)`; `created_at`, `published_at`; unique `(tariff_id, version_no)`; exclusion constraint prevents overlapping published versions. |
| `tariff_price_component` | `id uuid PK`; `tariff_version_id FK`; `element_order integer >= 0`; `component_type` in `ENERGY`, `TIME`, `PARKING_TIME`, `FLAT`, `RESERVATION`; `price_minor bigint >= 0`; `step_size integer > 0`; `unit text`; `tax_rate_id uuid FK tax_rate`; unique `(tariff_version_id, element_order, component_type)`. |
| `tariff_restriction` | `id uuid PK`; `tariff_version_id FK`; `element_order integer >= 0`; `start_time time`, `end_time time`; `days_of_week smallint[]`; min/max duration, energy, power, current with non-negative checks; unique `(tariff_version_id, element_order)`. |
| `agreement_tariff_link` | `id uuid PK`; `agreement_id uuid FK partner_agreement`; `tariff_version_id uuid FK tariff_version`; `created_at`; unique `(agreement_id, tariff_version_id)`. Owned by tariff because tariff depends on partners. |

### 3.5 ingestion

| Table | Columns and constraints |
|---|---|
| `cdr` | `id uuid PK`; `cpo_partner_id`, `emsp_partner_id` FKs; `cdr_external_id text`; `session_external_id`; `token_uid text`; `token_type text`; `contract_id text`; `auth_method text`; `authorization_reference text`; `location_external_id`, `evse_external_id`, `connector_external_id`; `meter_id`; `start_date_time`, `end_date_time timestamptz`; `total_energy_wh bigint`; `total_time_seconds bigint`; `total_parking_time_seconds bigint`; `total_reservation_time_seconds bigint`; `total_cost_minor bigint`; `currency char(3)`; `tariff_ref text`; `credit boolean`; `credit_reference_external_id text`; `credit_reference_cdr_id uuid FK cdr`; `home_charging_compensation boolean`; `source` in `OCPI_JSON`, `CSV`, `MANUAL`; `source_last_updated timestamptz`; `raw_payload jsonb`; `payload_hash char(64)`; `ingest_status` in `ACCEPTED`, `QUARANTINED`; `quarantine_reason_code text`; `quarantine_detail text`; `ingested_at`; `created_by text`. |
| `cdr_dimension` | `id bigserial PK`; `cdr_id uuid FK cdr`; `dimension_type` in `ENERGY`, `TIME`, `PARKING_TIME`, `FLAT`, `RESERVATION`, `MAX_CURRENT`, `MAX_POWER`, `MIN_CURRENT`, `MIN_POWER`; `quantity numeric(18,4) >= 0`; `unit text`; `period_start`, `period_end timestamptz`; `created_at`; index `cdr_id`. |
| `cdr_validation_issue` | `id bigserial PK`; `cdr_id uuid FK cdr`; `issue_code text`; `severity` in `WARNING`, `ERROR`; `detail text`; `created_at`; index `cdr_id`. |

`cdr` checks: `end_date_time >= start_date_time`; non-credit `total_cost_minor >= 0`;
credit requires `credit_reference_external_id` or `credit_reference_cdr_id`; credit is not
self-referencing; `octet_length(raw_payload::text) <= 65536`; unique
`(cpo_partner_id, emsp_partner_id, cdr_external_id)`; partial unique
`credit_reference_cdr_id WHERE credit`.

### 3.6 rating

| Table | Columns and constraints |
|---|---|
| `rating_run` | `id uuid PK`; `cpo_partner_id`, `emsp_partner_id` FKs; `period_start date`, `period_end date`; `status` in `PENDING`, `RUNNING`, `COMPLETED`, `FAILED`; `cursor_value text`; `processed_count`, `failed_count integer >= 0`; `started_at`, `finished_at`; `error_summary`; `created_by`; `created_at`; check period. |
| `rating_result` | `id uuid PK`; `rating_run_id FK`; `cdr_id FK`; `cpo_partner_id`, `emsp_partner_id` FKs; `agreement_id FK partner_agreement`; `tariff_version_id FK tariff_version`; `status` in `ACTIVE`, `SUPERSEDED`; `currency char(3)`; `energy_wh bigint`; `subtotal_minor`, `tax_minor`, `total_minor`, `declared_total_minor`, `variance_minor bigint`; `input_hash char(64)`; `computed_at`; check totals and variance; partial unique `cdr_id WHERE status = 'ACTIVE'`. |
| `rating_line` | `id uuid PK`; `rating_result_id FK`; `line_no integer > 0`; `component_type`; `description`; `quantity numeric(18,4) >= 0`; `unit`; `unit_price_minor bigint`; `amount_minor bigint`; `tax_rate_id FK tax_rate`; `tax_minor bigint`; unique `(rating_result_id, line_no)`. |
| `rating_variance` | `id uuid PK`; `rating_result_id FK`; `variance_type` in `NONE`, `AMOUNT`, `ENERGY`, `CURRENCY`, `MISSING_TARIFF`, `MISSING_AGREEMENT`; `declared_minor`, `rated_minor`, `delta_minor bigint`; `tolerance_minor bigint`; `detail jsonb`; `created_at`; index result. |

### 3.7 ledger

| Table | Columns and constraints |
|---|---|
| `ledger_account` | `id uuid PK`; `code text UNIQUE`; `name`; `account_type` in `ASSET`, `LIABILITY`, `EQUITY`, `REVENUE`, `EXPENSE`; `currency char(3) NULL`; `owner_ref uuid NULL` (opaque, no FK); `is_active boolean`; `created_at`. |
| `accounting_period` | `id uuid PK`; `period_code varchar(7) UNIQUE` (`YYYY-MM`); `start_date`, `end_date date`; `status` in `OPEN`, `CLOSED`, `LOCKED`; `closed_at`, `closed_by`; `created_at`; check date range. |
| `journal_entry` | `id uuid PK`; `entry_no bigint GENERATED ALWAYS AS IDENTITY UNIQUE`; `entity_ref uuid NOT NULL` (opaque, no FK); `accounting_period_id FK`; `source_type` in `INVOICE`, `CREDIT_NOTE`, `SETTLEMENT`, `ADJUSTMENT`; `source_id uuid`; `entry_type` in `STANDARD`, `REVERSAL`; `reverses_entry_id uuid FK journal_entry`; `currency char(3)`; `description`; `posted_at`; `created_by`; check reversal shape; unique `(entity_ref, source_type, source_id, entry_type)`. |
| `journal_line` | `id bigserial PK`; `journal_entry_id FK`; `line_no integer > 0`; `account_id FK ledger_account`; `debit_minor bigint >= 0`; `credit_minor bigint >= 0`; `partner_ref uuid NULL` (opaque, no FK); `memo`; check exactly one side is positive; unique `(journal_entry_id, line_no)`. |

`journal_entry` and `journal_line` have append-only triggers. A deferred constraint trigger
checks at commit: at least two lines, total debit equals total credit, and total debit is not
zero.

### 3.8 billing

| Table | Columns and constraints |
|---|---|
| `invoice` | `id uuid PK`; `invoice_no text NULL`; `issuer_partner_id`, `recipient_partner_id` FKs; `status` in `DRAFT`, `ISSUED`, `CANCELLED`, `PARTIALLY_CREDITED`, `FULLY_CREDITED`, `CLOSED`; `currency char(3)`; `subtotal_minor`, `tax_minor`, `total_minor bigint >= 0`; `period_start`, `period_end`, `issue_date`, `due_date date`; `place_of_supply_state char(2)`; `gstin_issuer`, `gstin_recipient varchar(15)`; `financial_year varchar(7)`; `e_invoice_status` in `NOT_REQUIRED`, `PENDING`, `REGISTERED`, `FAILED`; `irn char(64) NULL`, `ack_no text`, `ack_date date`, `qr_payload_hash char(64)`; `settlement_hold boolean NOT NULL DEFAULT false`, `hold_reason_code text NULL`, `hold_set_at timestamptz NULL`; `created_at`, `updated_at`, `issued_at`; checks totals, parties differ, period; partial unique invoice number. |
| `invoice_line` | `id uuid PK`; `invoice_id FK`; `line_no integer > 0`; `rating_result_id uuid FK rating_result UNIQUE`; `description`; `hsn_sac varchar(8)`; `quantity numeric(18,4) >= 0`; `unit`; `unit_price_minor`; `taxable_amount_minor >= 0`; `tax_minor >= 0`; `total_minor >= 0`; check taxable + tax = total; unique `(invoice_id, line_no)`. |
| `invoice_tax_line` | `id bigserial PK`; `invoice_id FK`; `tax_rate_id FK tax_rate`; `tax_kind` in `CGST`, `SGST`, `IGST`, `CESS`; `rate_bp integer 0..10000`; `taxable_amount_minor >= 0`; `tax_amount_minor >= 0`; index invoice. |
| `credit_note` | `id uuid PK`; `credit_note_no text NULL`; `invoice_id FK`; `status` in `DRAFT`, `ISSUED`; `currency char(3)`; `subtotal_minor`, `tax_minor`, `total_minor >= 0`; `reason_code`; `reason_detail`; `financial_year`; `irn char(64) NULL`; `created_at`, `issued_at`; check totals; partial unique number per invoice. |

Issued invoice financial columns and issued credit-note financial columns are immutable by
trigger. Deleting an issued document is rejected. The settlement-hold columns are the only
issued-invoice columns a dispute may change, and only through `billing`'s public hold
commands. Credit note totals must not exceed the remaining creditable amount of the invoice;
the service enforces the rule and the integration test proves it.

### 3.9 reconciliation

| Table | Columns and constraints |
|---|---|
| `reconciliation_run` | `id uuid PK`; `cpo_partner_id`, `emsp_partner_id` FKs; `partner_invoice_ref text`; `source_file_name`, `source_hash char(64)`; `period_start`, `period_end date`; `status` in `PENDING`, `RUNNING`, `COMPLETED`, `FAILED`; `total_lines`, `matched_lines`, `exception_lines integer >= 0`; `started_at`, `finished_at`; `created_by`; check period. |
| `reconciliation_item` | `id uuid PK`; `reconciliation_run_id FK`; `invoice_line_ref text`; `cdr_id uuid FK cdr NULL`; `invoice_line_id uuid FK invoice_line NULL`; `declared_amount_minor bigint`; `rated_amount_minor bigint NULL`; `status` in `UNMATCHED`, `MATCHED`, `AMOUNT_MISMATCH`, `MISSING_CDR`, `MISSING_INVOICE_LINE`, `RESOLVED`; unique `(run_id, invoice_line_ref)`. |
| `reconciliation_exception` | `id uuid PK`; `item_id FK`; `exception_type` in `MISSING_CDR`, `MISSING_INVOICE_LINE`, `AMOUNT_MISMATCH`, `DUPLICATE_LINE`, `CREDIT_MISMATCH`, `CURRENCY_MISMATCH`; `severity` in `WARNING`, `ERROR`; `status` in `OPEN`, `RESOLVED`, `WAIVED`; `resolution_code`, `resolution_note`, `resolved_by`, `resolved_at`; `detail jsonb`; check resolved rows have a code, actor, and time. |

### 3.10 dispute

| Table | Columns and constraints |
|---|---|
| `dispute` | `id uuid PK`; `cpo_partner_id`, `emsp_partner_id` FKs; `subject_type` in `CDR`, `RATING_RESULT`, `INVOICE`, `RECONCILIATION_EXCEPTION`, `SETTLEMENT`; `subject_id uuid NOT NULL`; `status` in `OPEN`, `UNDER_REVIEW`, `ACCEPTED`, `REJECTED`, `RESOLVED`, `WITHDRAWN`, `CLOSED`; `reason_code`; `description`; `opened_by`, `opened_at`; `resolved_at`, `resolution_code`; `closed_at`; `updated_at`, `version`; index `(status, opened_at)`. |
| `dispute_evidence` | `id uuid PK`; `dispute_id FK`; `evidence_type`; `storage_key`; `file_name`; `file_size_bytes bigint >= 0`; `content_hash char(64)`; `added_by`, `added_at`; index dispute. |
| `dispute_event` | `id bigserial PK`; `dispute_id FK`; `from_status`, `to_status`; `actor`; `reason`; `occurred_at`; index `(dispute_id, occurred_at)`. |

`dispute.subject_id` is validated through the public query API only for subject types owned
by a module that `dispute` may depend on (`CDR`, `RATING_RESULT`, `INVOICE`). A
`RECONCILIATION_EXCEPTION` or `SETTLEMENT` subject is an opaque UUID supplied by the caller;
the dispute records the reference and does not read the owning table. There is no
cross-module foreign key to reconciliation or settlement, and no financial effect follows
from an unverified subject.

### 3.11 settlement

| Table | Columns and constraints |
|---|---|
| `settlement_run` | `id uuid PK`; `cpo_partner_id`, `emsp_partner_id` FKs; `period_start`, `period_end date`; `currency char(3)`; `status` in `DRAFT`, `LOCKED`, `COMPLETED`, `FAILED`; `net_amount_minor bigint NULL`; `created_by`, `created_at`, `completed_at`; check period; partial unique `(cpo, emsp, period_start, period_end, currency) WHERE status = 'COMPLETED'`. |
| `settlement_item` | `id uuid PK`; `settlement_run_id FK`; `journal_line_id bigint FK journal_line`; `direction` in `PAYABLE`, `RECEIVABLE`; `amount_minor bigint > 0`; unique `journal_line_id`. |
| `settlement_statement` | `id uuid PK`; `settlement_run_id uuid UNIQUE FK`; `statement_no text UNIQUE`; `content_hash char(64)`; `issued_at`; `created_at`. |

### 3.12 audit

| Table | Columns and constraints |
|---|---|
| `audit_log` | `id uuid PK`; `sequence bigint GENERATED ALWAYS AS IDENTITY UNIQUE`; `occurred_at`; `actor_type` in `USER`, `PARTNER_API`, `SYSTEM`, `PLATFORM_ADMIN`; `actor_id text`; `partner_ref uuid NULL` (opaque, no FK); `action text`; `entity_type text`; `entity_id text`; `correlation_id text`; `before_hash char(64)`; `after_hash char(64)`; `prev_hash char(64) NOT NULL`; `record_hash char(64) NOT NULL`; `detail jsonb`; indexes on `(partner_ref, occurred_at)` and `(entity_type, entity_id)`. Append-only trigger. |
| `audit_checkpoint` | `id uuid PK`; `up_to_sequence bigint UNIQUE`; `record_hash char(64)`; `created_at`; used to verify a chain without rescanning everything. |

## 4. Immutability and triggers

- `journal_entry`, `journal_line`, `audit_log`, and issued `invoice`/`credit_note` rows reject
  update or delete through triggers, except status-only transitions allowed by the owning
  module.
- `cdr` is immutable after acceptance; a correction is a new credit or a new CDR with a new
  external ID. Quarantined CDRs may move to `ACCEPTED` only by the revalidation command.
- `rating_result` rows are immutable; re-rating inserts a new row and marks the prior row
  `SUPERSEDED`.
- `settlement_statement` is immutable; a failed or superseded run is a new run.
- Triggers use the `voltreckon` schema and are created in the owning migration. They are
  tested in integration tests, not assumed.

## 5. Cross-module foreign-key matrix

| Owner | May reference | Must not reference |
|---|---|---|
| `partners` | none (except its own tables) | any domain module |
| `iam` | `partners` | `tariff`, `ingestion`, `rating`, `billing`, `ledger` |
| `tariff` | `partners` | `ingestion`, `rating`, `billing`, `ledger` |
| `ingestion` | `partners` | `tariff`, `rating`, `billing`, `ledger` |
| `rating` | `partners`, `tariff`, `ingestion` | `billing`, `ledger` |
| `billing` | `partners`, `tariff`, `rating`, `ledger` (command only; no FK to ledger) | `reconciliation`, `settlement` |
| `reconciliation` | `partners`, `ingestion`, `billing` | `ledger`, `settlement` |
| `settlement` | `partners`, `billing`, `ledger`, `reconciliation` | `dispute` |
| `dispute` | `partners`, `ingestion`, `rating`, `billing`; generic subject | `reconciliation` table |
| `ledger` | none; opaque `entity_ref` and `partner_ref` UUIDs | every domain table |
| `audit` | none; opaque `partner_ref` | every domain table |
| `platform` | none; opaque `partner_ref` | every domain table |
| `reporting` | read-only `rpt_*` views | writes of any kind |

## 6. Indexes and retention

Required indexes: CDR pair/start time and ingested time; rating result pair/computed time;
invoice issuer/status and recipient/status; journal entry period and entity/posted time;
journal line entry, account, and partner; reconciliation exception status/created time;
settlement run pair/period; dispute status/opened time; audit partner/time and entity.
Indexes are added in the same migration as the table.

Retention defaults are configuration, not hard-coded: `idempotency_key` 48 hours after
expiry; `processed_event` 90 days; completed `event_publication` 7 days; raw CDR payload 24
months; financial documents and audit records follow the tax/legal retention review. No
application delete is allowed for issued financial rows. Partitioning and archival are T2.

## 7. Acceptance scenarios

```gherkin
Scenario: Duplicate CDR is idempotent
  Given an accepted CDR for a partner pair
  When the same external CDR arrives with the same payload hash
  Then the stored CDR is returned
  And no second CDR row exists

Scenario: Issued invoice is immutable
  Given an issued invoice
  When an update changes its total
  Then the database trigger rejects the update
  And the error code is IMMUTABLE_RECORD

Scenario: Journal balance is deferred to commit
  Given a journal with two lines
  When the lines are inserted in one transaction
  Then the deferred check passes only if debits equal credits
  And an unbalanced journal fails the transaction

Scenario: Cross-module boundary is visible in schema review
  Given a proposed ledger foreign key to partner
  When the migration is reviewed
  Then it is rejected because ledger has no domain foreign keys
```
