-- VoltReckon MVP schema
-- Target: PostgreSQL 18
-- Status: design DDL for blueprint v0.1. Not yet applied by an application.
--
-- Conventions
--   * One schema: voltreckon. Tables are prefixed by module where ambiguity helps.
--   * Money: BIGINT minor units + ISO-4217 currency (varchar(3), validated).
--   * Identifiers: UUIDv4 via gen_random_uuid(); invoice numbers use a locked sequence.
--   * Timestamps: timestamptz, stored in UTC.
--   * Append-only tables: cdr, journal_entry, journal_line, audit_log.
--   * No FLOAT/REAL/DOUBLE anywhere.
--
-- Requires: CREATE EXTENSION btree_gist (for exclusion constraints).
-- Run as a migration role, not the application role.

CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE SCHEMA IF NOT EXISTS voltreckon;
SET search_path TO voltreckon, public;

-- ============================================================
-- Platform helpers
-- ============================================================

CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION forbid_delete() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION '% is append-only; deletes are not permitted', TG_TABLE_NAME;
END;
$$;

-- ============================================================
-- Module: partner
-- ============================================================

CREATE TABLE partner (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  legal_name    text NOT NULL,
  display_name  text,
  status        text NOT NULL DEFAULT 'ACTIVE'
                CHECK (status IN ('ACTIVE', 'SUSPENDED')),
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  version       bigint NOT NULL DEFAULT 0
);

CREATE TRIGGER partner_set_updated_at
BEFORE UPDATE ON partner
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE partner_role (
  partner_id uuid NOT NULL REFERENCES partner(id),
  role       text NOT NULL CHECK (role IN ('CPO', 'EMSP')),
  PRIMARY KEY (partner_id, role)
);

CREATE TABLE partner_gstin (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id  uuid NOT NULL REFERENCES partner(id),
  gstin       varchar(15) NOT NULL,
  state_code  char(2) NOT NULL,
  legal_name  text,
  is_primary  boolean NOT NULL DEFAULT false,
  valid_from  date,
  valid_to    date,
  created_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT partner_gstin_format CHECK (gstin ~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$'),
  CONSTRAINT partner_gstin_valid_range CHECK (valid_to IS NULL OR valid_from IS NULL OR valid_to >= valid_from),
  UNIQUE (gstin),
  UNIQUE (partner_id, gstin)
);

CREATE UNIQUE INDEX partner_gstin_one_primary
  ON partner_gstin (partner_id) WHERE is_primary;

CREATE TABLE app_user (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id   uuid NOT NULL REFERENCES partner(id),
  subject      text NOT NULL,
  display_name text,
  status       text NOT NULL DEFAULT 'ACTIVE'
               CHECK (status IN ('ACTIVE', 'DISABLED')),
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (subject)
);

CREATE TABLE app_user_role (
  user_id uuid NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  role    text NOT NULL
          CHECK (role IN ('FINANCE_USER', 'FINANCE_ADMIN', 'ROAMING_MANAGER', 'PLATFORM_ADMIN')),
  PRIMARY KEY (user_id, role)
);

-- ============================================================
-- Module: tax (implemented in platform, consumed by invoicing)
-- ============================================================

CREATE TABLE tax_rate (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  jurisdiction   varchar(8) NOT NULL,          -- e.g. 'IN'
  service_code   varchar(8) NOT NULL,          -- e.g. '998714'
  tax_kind       text NOT NULL DEFAULT 'GST' CHECK (tax_kind IN ('GST', 'VAT', 'NONE')),
  rate_bp        integer NOT NULL CHECK (rate_bp BETWEEN 0 AND 10000),
  description    text,
  effective_from date NOT NULL,
  effective_to   date,
  created_at     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT tax_rate_valid_range CHECK (effective_to IS NULL OR effective_to >= effective_from),
  UNIQUE (jurisdiction, service_code, tax_kind, effective_from)
);

-- ============================================================
-- Module: tariff
-- ============================================================

CREATE TABLE tariff (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_partner_id uuid NOT NULL REFERENCES partner(id),
  code             text NOT NULL,
  name             text,
  created_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE (owner_partner_id, code)
);

CREATE TABLE tariff_version (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tariff_id      uuid NOT NULL REFERENCES tariff(id),
  version_no     integer NOT NULL CHECK (version_no > 0),
  status         text NOT NULL DEFAULT 'DRAFT'
                 CHECK (status IN ('DRAFT', 'PUBLISHED', 'SUPERSEDED')),
  currency       varchar(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
  effective_from timestamptz NOT NULL,
  effective_to   timestamptz,
  content_hash   char(64),
  created_at     timestamptz NOT NULL DEFAULT now(),
  published_at   timestamptz,
  CONSTRAINT tariff_version_valid_range CHECK (effective_to IS NULL OR effective_to > effective_from),
  UNIQUE (tariff_id, version_no)
);

ALTER TABLE tariff_version ADD CONSTRAINT tariff_version_no_overlap
  EXCLUDE USING gist (
    tariff_id WITH =,
    tstzrange(effective_from, effective_to, '[)') WITH &&
  ) WHERE (status = 'PUBLISHED');

CREATE TABLE tariff_price_component (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tariff_version_id uuid NOT NULL REFERENCES tariff_version(id),
  element_order     integer NOT NULL CHECK (element_order >= 0),
  component_type    text NOT NULL
                    CHECK (component_type IN ('ENERGY', 'TIME', 'PARKING_TIME', 'FLAT')),
  price_minor       bigint NOT NULL CHECK (price_minor >= 0),
  step_size         integer NOT NULL DEFAULT 1 CHECK (step_size > 0),
  tax_rate_id       uuid REFERENCES tax_rate(id),
  created_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tariff_version_id, element_order, component_type)
);

CREATE TABLE tariff_restriction (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tariff_version_id    uuid NOT NULL REFERENCES tariff_version(id),
  element_order        integer NOT NULL CHECK (element_order >= 0),
  start_time           time,
  end_time             time,
  days_of_week         smallint[],
  min_duration_seconds integer CHECK (min_duration_seconds >= 0),
  max_duration_seconds integer CHECK (max_duration_seconds >= 0),
  min_energy_wh        bigint CHECK (min_energy_wh >= 0),
  max_energy_wh        bigint CHECK (max_energy_wh >= 0),
  min_power_w          bigint CHECK (min_power_w >= 0),
  max_power_w          bigint CHECK (max_power_w >= 0),
  min_current_a        integer CHECK (min_current_a >= 0),
  max_current_a        integer CHECK (max_current_a >= 0),
  CONSTRAINT tariff_restriction_duration CHECK (
    min_duration_seconds IS NULL OR max_duration_seconds IS NULL
    OR max_duration_seconds >= min_duration_seconds),
  CONSTRAINT tariff_restriction_energy CHECK (
    min_energy_wh IS NULL OR max_energy_wh IS NULL
    OR max_energy_wh >= min_energy_wh),
  CONSTRAINT tariff_restriction_power CHECK (
    min_power_w IS NULL OR max_power_w IS NULL
    OR max_power_w >= min_power_w),
  CONSTRAINT tariff_restriction_current CHECK (
    min_current_a IS NULL OR max_current_a IS NULL
    OR max_current_a >= min_current_a),
  UNIQUE (tariff_version_id, element_order)
);

-- ============================================================
-- Module: agreement
-- ============================================================

CREATE TABLE partner_agreement (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cpo_partner_id      uuid NOT NULL REFERENCES partner(id),
  emsp_partner_id     uuid NOT NULL REFERENCES partner(id),
  agreement_ref       text,
  status              text NOT NULL DEFAULT 'DRAFT'
                      CHECK (status IN ('DRAFT', 'ACTIVE', 'TERMINATED')),
  currency            varchar(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
  settlement_cycle    text NOT NULL DEFAULT 'MONTHLY'
                      CHECK (settlement_cycle IN ('WEEKLY', 'MONTHLY')),
  payment_terms_days  integer NOT NULL DEFAULT 30 CHECK (payment_terms_days >= 0),
  billing_period_basis text NOT NULL DEFAULT 'SESSION_START'
                      CHECK (billing_period_basis IN ('SESSION_START', 'SESSION_END')),
  effective_from      date NOT NULL,
  effective_to        date,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  version             bigint NOT NULL DEFAULT 0,
  CONSTRAINT partner_agreement_distinct_parties CHECK (cpo_partner_id <> emsp_partner_id),
  CONSTRAINT partner_agreement_valid_range CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

ALTER TABLE partner_agreement ADD CONSTRAINT partner_agreement_no_overlap
  EXCLUDE USING gist (
    cpo_partner_id WITH =,
    emsp_partner_id WITH =,
    daterange(effective_from, effective_to, '[]') WITH &&
  ) WHERE (status = 'ACTIVE');

CREATE TRIGGER partner_agreement_set_updated_at
BEFORE UPDATE ON partner_agreement
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE agreement_tariff_link (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  agreement_id      uuid NOT NULL REFERENCES partner_agreement(id),
  tariff_version_id uuid NOT NULL REFERENCES tariff_version(id),
  created_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (agreement_id, tariff_version_id)
);

-- ============================================================
-- Module: cdr
-- ============================================================

CREATE TABLE cdr (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cpo_partner_id         uuid NOT NULL REFERENCES partner(id),
  emsp_partner_id        uuid NOT NULL REFERENCES partner(id),
  cdr_external_id        text NOT NULL,
  session_external_id    text,
  token_uid              text,
  start_date_time        timestamptz NOT NULL,
  end_date_time          timestamptz NOT NULL,
  total_energy_wh        bigint NOT NULL CHECK (total_energy_wh >= 0),
  total_time_seconds     bigint CHECK (total_time_seconds >= 0),
  total_cost_minor       bigint NOT NULL,
  currency               varchar(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
  credit                 boolean NOT NULL DEFAULT false,
  credit_reference_cdr_id uuid REFERENCES cdr(id),
  source                 text NOT NULL CHECK (source IN ('OCPI_JSON', 'CSV', 'MANUAL')),
  raw_payload            jsonb NOT NULL,
  payload_hash           char(64) NOT NULL,
  ingest_status          text NOT NULL DEFAULT 'ACCEPTED'
                         CHECK (ingest_status IN ('ACCEPTED', 'QUARANTINED')),
  ingested_at            timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT cdr_time_order CHECK (end_date_time >= start_date_time),
  CONSTRAINT cdr_non_credit_non_negative CHECK (credit OR total_cost_minor >= 0),
  CONSTRAINT cdr_credit_requires_reference CHECK ((NOT credit) OR credit_reference_cdr_id IS NOT NULL),
  CONSTRAINT cdr_not_self_reference CHECK (credit_reference_cdr_id IS NULL OR credit_reference_cdr_id <> id),
  UNIQUE (cpo_partner_id, emsp_partner_id, cdr_external_id)
);

-- An original CDR may be credited at most once.
CREATE UNIQUE INDEX cdr_one_credit_per_original
  ON cdr (credit_reference_cdr_id) WHERE credit;

CREATE INDEX cdr_pair_time_idx
  ON cdr (cpo_partner_id, emsp_partner_id, start_date_time);

CREATE INDEX cdr_ingested_idx ON cdr (ingested_at);

CREATE TABLE cdr_dimension (
  id              bigserial PRIMARY KEY,
  cdr_id          uuid NOT NULL REFERENCES cdr(id),
  dimension_type  text NOT NULL,
  dimension_value text,
  unit            text,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX cdr_dimension_cdr_idx ON cdr_dimension (cdr_id);

CREATE TABLE cdr_validation_issue (
  id           bigserial PRIMARY KEY,
  cdr_id       uuid NOT NULL REFERENCES cdr(id),
  issue_code   text NOT NULL,
  severity     text NOT NULL CHECK (severity IN ('WARNING', 'ERROR')),
  detail       text,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX cdr_validation_issue_cdr_idx ON cdr_validation_issue (cdr_id);

-- CDR financial content is immutable. Only ingest_status (quarantine revalidation)
-- and validation issues may change. Deletes are forbidden.
CREATE OR REPLACE FUNCTION cdr_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'cdr rows cannot be deleted';
  END IF;
  IF (OLD.cpo_partner_id, OLD.emsp_partner_id, OLD.cdr_external_id,
      OLD.start_date_time, OLD.end_date_time, OLD.total_energy_wh,
      OLD.total_cost_minor, OLD.currency, OLD.credit,
      OLD.credit_reference_cdr_id, OLD.raw_payload, OLD.payload_hash, OLD.source)
     IS DISTINCT FROM
     (NEW.cpo_partner_id, NEW.emsp_partner_id, NEW.cdr_external_id,
      NEW.start_date_time, NEW.end_date_time, NEW.total_energy_wh,
      NEW.total_cost_minor, NEW.currency, NEW.credit,
      NEW.credit_reference_cdr_id, NEW.raw_payload, NEW.payload_hash, NEW.source) THEN
    RAISE EXCEPTION 'financial fields of cdr are immutable';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER cdr_immutable
BEFORE UPDATE OR DELETE ON cdr
FOR EACH ROW EXECUTE FUNCTION cdr_guard();

-- A credit must reference an original from the same partner pair.
CREATE OR REPLACE FUNCTION cdr_credit_check() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE ref cdr%ROWTYPE;
BEGIN
  IF NEW.credit THEN
    SELECT * INTO ref FROM cdr WHERE id = NEW.credit_reference_cdr_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'credit_reference_cdr_id % does not exist', NEW.credit_reference_cdr_id;
    END IF;
    IF ref.credit THEN
      RAISE EXCEPTION 'a credit CDR cannot reference another credit CDR';
    END IF;
    IF ref.cpo_partner_id <> NEW.cpo_partner_id OR ref.emsp_partner_id <> NEW.emsp_partner_id THEN
      RAISE EXCEPTION 'credit CDR partner pair does not match the original';
    END IF;
    IF ref.currency <> NEW.currency THEN
      RAISE EXCEPTION 'credit CDR currency does not match the original';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER cdr_credit_validation
BEFORE INSERT ON cdr
FOR EACH ROW EXECUTE FUNCTION cdr_credit_check();

-- ============================================================
-- Module: rating
-- ============================================================

CREATE TABLE rating_run (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cpo_partner_id  uuid NOT NULL REFERENCES partner(id),
  emsp_partner_id uuid NOT NULL REFERENCES partner(id),
  period_start    date NOT NULL,
  period_end      date NOT NULL,
  status          text NOT NULL DEFAULT 'PENDING'
                  CHECK (status IN ('PENDING', 'RUNNING', 'COMPLETED', 'FAILED', 'CANCELLED')),
  cursor_value    text,
  processed_count integer NOT NULL DEFAULT 0,
  failed_count    integer NOT NULL DEFAULT 0,
  started_at      timestamptz,
  finished_at     timestamptz,
  error_summary   text,
  created_by      text NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT rating_run_period CHECK (period_end >= period_start)
);

CREATE TABLE rating_result (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rating_run_id       uuid NOT NULL REFERENCES rating_run(id),
  cdr_id              uuid NOT NULL REFERENCES cdr(id),
  cpo_partner_id      uuid NOT NULL REFERENCES partner(id),
  emsp_partner_id     uuid NOT NULL REFERENCES partner(id),
  agreement_id        uuid NOT NULL REFERENCES partner_agreement(id),
  tariff_version_id   uuid NOT NULL REFERENCES tariff_version(id),
  status              text NOT NULL DEFAULT 'ACTIVE'
                      CHECK (status IN ('ACTIVE', 'SUPERSEDED')),
  currency            varchar(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
  energy_wh           bigint NOT NULL CHECK (energy_wh >= 0),
  subtotal_minor      bigint NOT NULL,
  tax_minor           bigint NOT NULL,
  total_minor         bigint NOT NULL,
  declared_total_minor bigint NOT NULL,
  variance_minor      bigint NOT NULL,
  input_hash          char(64) NOT NULL,
  computed_at         timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT rating_result_totals CHECK (subtotal_minor + tax_minor = total_minor),
  CONSTRAINT rating_result_variance CHECK (variance_minor = total_minor - declared_total_minor)
);

CREATE UNIQUE INDEX rating_result_one_active_per_cdr
  ON rating_result (cdr_id) WHERE status = 'ACTIVE';

CREATE INDEX rating_result_pair_idx
  ON rating_result (cpo_partner_id, emsp_partner_id, computed_at);

CREATE TABLE rating_line (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rating_result_id uuid NOT NULL REFERENCES rating_result(id),
  line_no          integer NOT NULL CHECK (line_no > 0),
  component_type   text NOT NULL
                   CHECK (component_type IN ('ENERGY', 'TIME', 'PARKING_TIME', 'FLAT')),
  description      text,
  quantity         numeric(18, 4) NOT NULL CHECK (quantity >= 0),
  unit             text,
  unit_price_minor bigint NOT NULL,
  amount_minor     bigint NOT NULL,
  tax_rate_id      uuid REFERENCES tax_rate(id),
  tax_minor        bigint NOT NULL DEFAULT 0,
  created_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE (rating_result_id, line_no)
);

CREATE TABLE rating_variance (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rating_result_id uuid NOT NULL REFERENCES rating_result(id),
  variance_type    text NOT NULL
                   CHECK (variance_type IN ('NONE', 'AMOUNT', 'ENERGY', 'CURRENCY', 'MISSING_TARIFF', 'MISSING_AGREEMENT')),
  declared_minor   bigint,
  rated_minor      bigint,
  delta_minor      bigint,
  tolerance_minor  bigint NOT NULL DEFAULT 0,
  detail           jsonb,
  created_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX rating_variance_result_idx ON rating_variance (rating_result_id);

-- ============================================================
-- Module: invoicing
-- ============================================================

CREATE TABLE invoice (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_no            text,
  issuer_partner_id     uuid NOT NULL REFERENCES partner(id),
  recipient_partner_id  uuid NOT NULL REFERENCES partner(id),
  status                text NOT NULL DEFAULT 'DRAFT'
                        CHECK (status IN ('DRAFT', 'ISSUED', 'CANCELLED', 'PARTIALLY_CREDITED', 'FULLY_CREDITED', 'CLOSED')),
  currency              varchar(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
  subtotal_minor        bigint NOT NULL DEFAULT 0 CHECK (subtotal_minor >= 0),
  tax_minor             bigint NOT NULL DEFAULT 0 CHECK (tax_minor >= 0),
  total_minor           bigint NOT NULL DEFAULT 0 CHECK (total_minor >= 0),
  period_start          date,
  period_end            date,
  issue_date            date,
  due_date              date,
  place_of_supply_state char(2),
  gstin_issuer          varchar(15),
  gstin_recipient       varchar(15),
  financial_year        varchar(7),
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  issued_at             timestamptz,
  CONSTRAINT invoice_totals CHECK (subtotal_minor + tax_minor = total_minor),
  CONSTRAINT invoice_issuer_not_recipient CHECK (issuer_partner_id <> recipient_partner_id),
  CONSTRAINT invoice_period CHECK (period_start IS NULL OR period_end IS NULL OR period_end >= period_start)
);

CREATE UNIQUE INDEX invoice_number_unique
  ON invoice (issuer_partner_id, financial_year, invoice_no)
  WHERE invoice_no IS NOT NULL;

CREATE INDEX invoice_recipient_status_idx ON invoice (recipient_partner_id, status);
CREATE INDEX invoice_issuer_status_idx ON invoice (issuer_partner_id, status);

CREATE TRIGGER invoice_set_updated_at
BEFORE UPDATE ON invoice
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE invoice_line (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id           uuid NOT NULL REFERENCES invoice(id),
  line_no              integer NOT NULL CHECK (line_no > 0),
  rating_result_id     uuid NOT NULL REFERENCES rating_result(id),
  description          text NOT NULL,
  hsn_sac              varchar(8),
  quantity             numeric(18, 4) NOT NULL CHECK (quantity >= 0),
  unit                 text,
  unit_price_minor     bigint NOT NULL,
  taxable_amount_minor bigint NOT NULL CHECK (taxable_amount_minor >= 0),
  tax_minor            bigint NOT NULL DEFAULT 0 CHECK (tax_minor >= 0),
  total_minor          bigint NOT NULL CHECK (total_minor >= 0),
  created_at           timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT invoice_line_totals CHECK (taxable_amount_minor + tax_minor = total_minor),
  UNIQUE (invoice_id, line_no),
  UNIQUE (rating_result_id)
);

CREATE INDEX invoice_line_invoice_idx ON invoice_line (invoice_id);

CREATE TABLE invoice_tax_line (
  id                   bigserial PRIMARY KEY,
  invoice_id           uuid NOT NULL REFERENCES invoice(id),
  tax_rate_id          uuid NOT NULL REFERENCES tax_rate(id),
  tax_kind             text NOT NULL CHECK (tax_kind IN ('CGST', 'SGST', 'IGST', 'CESS')),
  rate_bp              integer NOT NULL CHECK (rate_bp BETWEEN 0 AND 10000),
  taxable_amount_minor bigint NOT NULL CHECK (taxable_amount_minor >= 0),
  tax_amount_minor     bigint NOT NULL CHECK (tax_amount_minor >= 0),
  created_at           timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX invoice_tax_line_invoice_idx ON invoice_tax_line (invoice_id);

CREATE TABLE credit_note (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  credit_note_no text,
  invoice_id     uuid NOT NULL REFERENCES invoice(id),
  status         text NOT NULL DEFAULT 'DRAFT'
                 CHECK (status IN ('DRAFT', 'ISSUED')),
  currency       varchar(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
  subtotal_minor bigint NOT NULL CHECK (subtotal_minor >= 0),
  tax_minor      bigint NOT NULL CHECK (tax_minor >= 0),
  total_minor    bigint NOT NULL CHECK (total_minor >= 0),
  reason_code    text NOT NULL,
  reason_detail  text,
  created_at     timestamptz NOT NULL DEFAULT now(),
  issued_at      timestamptz,
  CONSTRAINT credit_note_totals CHECK (subtotal_minor + tax_minor = total_minor)
);

CREATE UNIQUE INDEX credit_note_number_unique
  ON credit_note (invoice_id, credit_note_no)
  WHERE credit_note_no IS NOT NULL;

-- Issued invoices are immutable. Drafts may change. Status may advance.
CREATE OR REPLACE FUNCTION invoice_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'invoices cannot be deleted';
  END IF;
  IF OLD.status <> 'DRAFT' THEN
    IF (OLD.invoice_no, OLD.issuer_partner_id, OLD.recipient_partner_id, OLD.currency,
        OLD.subtotal_minor, OLD.tax_minor, OLD.total_minor, OLD.period_start,
        OLD.period_end, OLD.issue_date, OLD.place_of_supply_state,
        OLD.gstin_issuer, OLD.gstin_recipient, OLD.financial_year)
       IS DISTINCT FROM
       (NEW.invoice_no, NEW.issuer_partner_id, NEW.recipient_partner_id, NEW.currency,
        NEW.subtotal_minor, NEW.tax_minor, NEW.total_minor, NEW.period_start,
        NEW.period_end, NEW.issue_date, NEW.place_of_supply_state,
        NEW.gstin_issuer, NEW.gstin_recipient, NEW.financial_year) THEN
      RAISE EXCEPTION 'issued invoice financial content is immutable';
    END IF;
  END IF;
  IF OLD.status = 'CLOSED' AND NEW.status <> 'CLOSED' THEN
    RAISE EXCEPTION 'closed invoice cannot change status';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER invoice_immutable
BEFORE UPDATE OR DELETE ON invoice
FOR EACH ROW EXECUTE FUNCTION invoice_guard();

-- ============================================================
-- Module: ledger
-- ============================================================

CREATE TABLE ledger_account (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code         text NOT NULL UNIQUE,
  name         text NOT NULL,
  account_type text NOT NULL
               CHECK (account_type IN ('ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE')),
  currency     varchar(3) CHECK (currency IS NULL OR currency ~ '^[A-Z]{3}$'),
  partner_id   uuid REFERENCES partner(id),
  is_active    boolean NOT NULL DEFAULT true,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE accounting_period (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  period_code varchar(7) NOT NULL UNIQUE,      -- e.g. '2026-11'
  start_date  date NOT NULL,
  end_date    date NOT NULL,
  status      text NOT NULL DEFAULT 'OPEN'
              CHECK (status IN ('OPEN', 'CLOSED', 'LOCKED')),
  closed_at   timestamptz,
  closed_by   text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT accounting_period_range CHECK (end_date >= start_date)
);

CREATE TABLE journal_entry (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entry_no            bigint GENERATED ALWAYS AS IDENTITY UNIQUE,
  entity_partner_id    uuid NOT NULL REFERENCES partner(id),
  accounting_period_id uuid NOT NULL REFERENCES accounting_period(id),
  source_type         text NOT NULL
                      CHECK (source_type IN ('INVOICE', 'CREDIT_NOTE', 'SETTLEMENT', 'ADJUSTMENT')),
  source_id           uuid NOT NULL,
  entry_type          text NOT NULL DEFAULT 'STANDARD'
                      CHECK (entry_type IN ('STANDARD', 'REVERSAL')),
  reverses_entry_id   uuid REFERENCES journal_entry(id),
  currency            varchar(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
  description         text,
  posted_at           timestamptz NOT NULL DEFAULT now(),
  created_by          text NOT NULL,
  CONSTRAINT journal_entry_reversal CHECK (
    (entry_type = 'REVERSAL' AND reverses_entry_id IS NOT NULL)
    OR (entry_type = 'STANDARD' AND reverses_entry_id IS NULL)),
  UNIQUE (entity_partner_id, source_type, source_id, entry_type)
);

CREATE INDEX journal_entry_period_idx ON journal_entry (accounting_period_id);
CREATE INDEX journal_entry_entity_idx ON journal_entry (entity_partner_id, posted_at);

CREATE TABLE journal_line (
  id               bigserial PRIMARY KEY,
  journal_entry_id uuid NOT NULL REFERENCES journal_entry(id),
  line_no          integer NOT NULL CHECK (line_no > 0),
  account_id       uuid NOT NULL REFERENCES ledger_account(id),
  debit_minor      bigint NOT NULL DEFAULT 0 CHECK (debit_minor >= 0),
  credit_minor     bigint NOT NULL DEFAULT 0 CHECK (credit_minor >= 0),
  partner_id       uuid REFERENCES partner(id),
  memo             text,
  CONSTRAINT journal_line_one_side CHECK (
    (debit_minor > 0 AND credit_minor = 0)
    OR (credit_minor > 0 AND debit_minor = 0)),
  UNIQUE (journal_entry_id, line_no)
);

CREATE INDEX journal_line_entry_idx ON journal_line (journal_entry_id);
CREATE INDEX journal_line_account_idx ON journal_line (account_id);
CREATE INDEX journal_line_partner_idx ON journal_line (partner_id);

CREATE OR REPLACE FUNCTION journal_line_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'journal lines are append-only';
END;
$$;

CREATE TRIGGER journal_line_immutable
BEFORE UPDATE OR DELETE ON journal_line
FOR EACH ROW EXECUTE FUNCTION journal_line_guard();

CREATE OR REPLACE FUNCTION journal_entry_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'journal entries are append-only';
END;
$$;

CREATE TRIGGER journal_entry_immutable
BEFORE UPDATE OR DELETE ON journal_entry
FOR EACH ROW EXECUTE FUNCTION journal_entry_guard();

-- Deferred balance check: at commit time, debits must equal credits and
-- the entry must have at least two lines. Deferred constraints allow
-- multi-row inserts inside one transaction.
CREATE OR REPLACE FUNCTION check_journal_balanced() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  entry_id uuid;
  total_debit bigint;
  total_credit bigint;
  line_count integer;
BEGIN
  entry_id := COALESCE(NEW.journal_entry_id, OLD.journal_entry_id);
  SELECT COALESCE(SUM(debit_minor), 0),
         COALESCE(SUM(credit_minor), 0),
         COUNT(*)
    INTO total_debit, total_credit, line_count
    FROM journal_line
   WHERE journal_entry_id = entry_id;

  IF line_count < 2 THEN
    RAISE EXCEPTION 'journal entry % must have at least two lines', entry_id;
  END IF;
  IF total_debit <> total_credit THEN
    RAISE EXCEPTION 'journal entry % is unbalanced: debit %, credit %',
      entry_id, total_debit, total_credit;
  END IF;
  IF total_debit = 0 THEN
    RAISE EXCEPTION 'journal entry % has zero value', entry_id;
  END IF;
  RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER journal_line_balanced
AFTER INSERT OR UPDATE OR DELETE ON journal_line
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION check_journal_balanced();

-- ============================================================
-- Module: reconciliation
-- ============================================================

CREATE TABLE reconciliation_run (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cpo_partner_id      uuid NOT NULL REFERENCES partner(id),
  emsp_partner_id     uuid NOT NULL REFERENCES partner(id),
  partner_invoice_ref text NOT NULL,
  period_start        date NOT NULL,
  period_end          date NOT NULL,
  status              text NOT NULL DEFAULT 'PENDING'
                      CHECK (status IN ('PENDING', 'RUNNING', 'COMPLETED', 'FAILED')),
  total_lines         integer NOT NULL DEFAULT 0,
  matched_lines       integer NOT NULL DEFAULT 0,
  exception_lines     integer NOT NULL DEFAULT 0,
  started_at          timestamptz,
  finished_at         timestamptz,
  created_by          text NOT NULL,
  created_at          timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT reconciliation_run_period CHECK (period_end >= period_start)
);

CREATE TABLE reconciliation_item (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reconciliation_run_id uuid NOT NULL REFERENCES reconciliation_run(id),
  invoice_line_ref     text NOT NULL,
  cdr_id               uuid REFERENCES cdr(id),
  invoice_line_id      uuid REFERENCES invoice_line(id),
  declared_amount_minor bigint NOT NULL,
  rated_amount_minor   bigint,
  status               text NOT NULL DEFAULT 'UNMATCHED'
                       CHECK (status IN ('UNMATCHED', 'MATCHED', 'AMOUNT_MISMATCH', 'MISSING_CDR', 'MISSING_INVOICE_LINE', 'RESOLVED')),
  created_at           timestamptz NOT NULL DEFAULT now(),
  UNIQUE (reconciliation_run_id, invoice_line_ref)
);

CREATE INDEX reconciliation_item_cdr_idx ON reconciliation_item (cdr_id);

CREATE TABLE reconciliation_exception (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id          uuid NOT NULL REFERENCES reconciliation_item(id),
  exception_type   text NOT NULL
                   CHECK (exception_type IN ('MISSING_CDR', 'MISSING_INVOICE_LINE', 'AMOUNT_MISMATCH', 'DUPLICATE_LINE', 'CREDIT_MISMATCH', 'CURRENCY_MISMATCH')),
  severity         text NOT NULL DEFAULT 'ERROR' CHECK (severity IN ('WARNING', 'ERROR')),
  status           text NOT NULL DEFAULT 'OPEN'
                   CHECK (status IN ('OPEN', 'RESOLVED', 'WAIVED')),
  resolution_code  text,
  resolution_note  text,
  resolved_by      text,
  resolved_at      timestamptz,
  detail           jsonb,
  created_at       timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT reconciliation_exception_resolution CHECK (
    status = 'OPEN'
    OR (resolution_code IS NOT NULL AND resolved_by IS NOT NULL AND resolved_at IS NOT NULL))
);

CREATE INDEX reconciliation_exception_status_idx
  ON reconciliation_exception (status, created_at);

-- ============================================================
-- Module: settlement
-- ============================================================

CREATE TABLE settlement_run (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cpo_partner_id  uuid NOT NULL REFERENCES partner(id),
  emsp_partner_id uuid NOT NULL REFERENCES partner(id),
  period_start    date NOT NULL,
  period_end      date NOT NULL,
  currency        varchar(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
  status          text NOT NULL DEFAULT 'DRAFT'
                  CHECK (status IN ('DRAFT', 'LOCKED', 'COMPLETED', 'FAILED')),
  net_amount_minor bigint,
  created_at      timestamptz NOT NULL DEFAULT now(),
  completed_at    timestamptz,
  CONSTRAINT settlement_run_period CHECK (period_end >= period_start)
);

CREATE UNIQUE INDEX settlement_run_one_completed
  ON settlement_run (cpo_partner_id, emsp_partner_id, period_start, period_end)
  WHERE status = 'COMPLETED';

CREATE TABLE settlement_item (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  settlement_run_id uuid NOT NULL REFERENCES settlement_run(id),
  journal_line_id   bigint NOT NULL REFERENCES journal_line(id),
  direction         text NOT NULL CHECK (direction IN ('PAYABLE', 'RECEIVABLE')),
  amount_minor      bigint NOT NULL CHECK (amount_minor > 0),
  created_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (journal_line_id)
);

CREATE TABLE settlement_statement (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  settlement_run_id uuid NOT NULL UNIQUE REFERENCES settlement_run(id),
  statement_no      text NOT NULL UNIQUE,
  content_hash      char(64) NOT NULL,
  issued_at         timestamptz NOT NULL DEFAULT now(),
  created_at        timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- Module: dispute
-- ============================================================

CREATE TABLE dispute (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cpo_partner_id    uuid NOT NULL REFERENCES partner(id),
  emsp_partner_id   uuid NOT NULL REFERENCES partner(id),
  cdr_id            uuid REFERENCES cdr(id),
  rating_result_id  uuid REFERENCES rating_result(id),
  invoice_id        uuid REFERENCES invoice(id),
  reconciliation_item_id uuid REFERENCES reconciliation_item(id),
  status            text NOT NULL DEFAULT 'OPEN'
                    CHECK (status IN ('OPEN', 'UNDER_REVIEW', 'ACCEPTED', 'REJECTED', 'RESOLVED', 'WITHDRAWN', 'CLOSED')),
  reason_code       text NOT NULL,
  description       text,
  opened_by         text NOT NULL,
  opened_at         timestamptz NOT NULL DEFAULT now(),
  resolved_at       timestamptz,
  resolution_code   text,
  closed_at         timestamptz,
  updated_at        timestamptz NOT NULL DEFAULT now(),
  version           bigint NOT NULL DEFAULT 0
);

CREATE TRIGGER dispute_set_updated_at
BEFORE UPDATE ON dispute
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX dispute_status_idx ON dispute (status, opened_at);

CREATE TABLE dispute_evidence (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dispute_id      uuid NOT NULL REFERENCES dispute(id),
  evidence_type   text NOT NULL,
  storage_key     text,
  file_name       text,
  file_size_bytes bigint CHECK (file_size_bytes IS NULL OR file_size_bytes >= 0),
  content_hash    char(64) NOT NULL,
  added_by        text NOT NULL,
  added_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX dispute_evidence_dispute_idx ON dispute_evidence (dispute_id);

CREATE TABLE dispute_event (
  id          bigserial PRIMARY KEY,
  dispute_id  uuid NOT NULL REFERENCES dispute(id),
  from_status text,
  to_status   text NOT NULL,
  actor       text NOT NULL,
  reason      text,
  occurred_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX dispute_event_dispute_idx ON dispute_event (dispute_id, occurred_at);

-- ============================================================
-- Module: platform (audit, outbox, idempotency, sequences)
-- ============================================================

CREATE TABLE audit_log (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  occurred_at    timestamptz NOT NULL DEFAULT now(),
  actor_type     text NOT NULL CHECK (actor_type IN ('USER', 'PARTNER_API', 'SYSTEM', 'PLATFORM_ADMIN')),
  actor_id       text NOT NULL,
  partner_id     uuid REFERENCES partner(id),
  action         text NOT NULL,
  entity_type    text NOT NULL,
  entity_id      text,
  correlation_id text,
  before_hash    char(64),
  after_hash     char(64),
  detail         jsonb
);

CREATE INDEX audit_log_partner_time_idx ON audit_log (partner_id, occurred_at);
CREATE INDEX audit_log_entity_idx ON audit_log (entity_type, entity_id);

CREATE TRIGGER audit_log_append_only
BEFORE UPDATE OR DELETE ON audit_log
FOR EACH ROW EXECUTE FUNCTION forbid_delete();

-- Intended domain outbox. If Spring Modulith's event publication registry is used,
-- the application maps to its `event_publication` table; this table documents the
-- required fields and can be replaced by a compatible view.
CREATE TABLE outbox_event (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type         text NOT NULL,
  aggregate_type     text NOT NULL,
  aggregate_id       uuid NOT NULL,
  payload            jsonb NOT NULL,
  publication_status text NOT NULL DEFAULT 'PENDING'
                     CHECK (publication_status IN ('PENDING', 'COMPLETED', 'FAILED')),
  attempts           integer NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  last_error         text,
  created_at         timestamptz NOT NULL DEFAULT now(),
  published_at       timestamptz
);

CREATE INDEX outbox_event_pending_idx
  ON outbox_event (publication_status, created_at)
  WHERE publication_status = 'PENDING';

CREATE TABLE idempotency_key (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id         uuid NOT NULL REFERENCES partner(id),
  route              text NOT NULL,
  idem_key           text NOT NULL,
  request_hash       char(64) NOT NULL,
  response_status    integer,
  response_body_hash char(64),
  created_at         timestamptz NOT NULL DEFAULT now(),
  expires_at         timestamptz NOT NULL,
  UNIQUE (partner_id, route, idem_key)
);

CREATE INDEX idempotency_key_expiry_idx ON idempotency_key (expires_at);

CREATE TABLE processed_event (
  consumer     text NOT NULL,
  event_id     uuid NOT NULL,
  processed_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (consumer, event_id)
);

CREATE TABLE sequence_number (
  name       text PRIMARY KEY,
  next_value bigint NOT NULL DEFAULT 1 CHECK (next_value > 0),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION next_sequence(p_name text) RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE
  allocated bigint;
BEGIN
  UPDATE sequence_number
     SET next_value = next_value + 1,
         updated_at = now()
   WHERE name = p_name
  RETURNING next_value - 1 INTO allocated;

  IF allocated IS NULL THEN
    RAISE EXCEPTION 'unknown sequence: %', p_name;
  END IF;
  RETURN allocated;
END;
$$;

-- ============================================================
-- Reporting views (read-only)
-- ============================================================

CREATE VIEW v_trial_balance AS
SELECT je.entity_partner_id,
       a.id AS account_id,
       a.code,
       a.name,
       a.account_type,
       COALESCE(SUM(jl.debit_minor), 0)  AS total_debit_minor,
       COALESCE(SUM(jl.credit_minor), 0) AS total_credit_minor,
       COALESCE(SUM(jl.debit_minor), 0) - COALESCE(SUM(jl.credit_minor), 0) AS balance_minor
  FROM ledger_account a
  LEFT JOIN journal_line jl ON jl.account_id = a.id
  LEFT JOIN journal_entry je ON je.id = jl.journal_entry_id
 GROUP BY je.entity_partner_id, a.id, a.code, a.name, a.account_type;

CREATE VIEW v_open_exceptions AS
SELECT e.id,
       e.exception_type,
       e.severity,
       e.status,
       e.created_at,
       r.cpo_partner_id,
       r.emsp_partner_id,
       r.partner_invoice_ref,
       i.invoice_line_ref,
       i.declared_amount_minor,
       i.rated_amount_minor
  FROM reconciliation_exception e
  JOIN reconciliation_item i ON i.id = e.item_id
  JOIN reconciliation_run r ON r.id = i.reconciliation_run_id
 WHERE e.status = 'OPEN';

-- ============================================================
-- Seed data (development only; safe to remove)
-- ============================================================

INSERT INTO ledger_account (code, name, account_type, currency)
VALUES
  ('1100', 'Accounts Receivable', 'ASSET', 'INR'),
  ('1200', 'Cash and Bank', 'ASSET', 'INR'),
  ('2100', 'Accounts Payable', 'LIABILITY', 'INR'),
  ('2200', 'GST Payable', 'LIABILITY', 'INR'),
  ('4000', 'Charging Revenue', 'REVENUE', 'INR'),
  ('4900', 'Discounts and Adjustments', 'REVENUE', 'INR')
ON CONFLICT (code) DO NOTHING;

INSERT INTO sequence_number (name, next_value)
VALUES ('invoice_number', 1)
ON CONFLICT (name) DO NOTHING;
