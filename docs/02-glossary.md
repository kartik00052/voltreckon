# 02 — Glossary

- **Status:** Draft
- **Owner:** VoltReckon maintainer
- **Last verified:** 2026-11-13
- **Applies to phases:** 0–10

Definitions here are the vocabulary used by every other document. A term with a source
marker is defined by that source; the wording below is the reading VoltReckon implements.
When a rule and this glossary disagree, the rule wins and this file is corrected.

## 1. Actors and organisations

| Term | Definition |
|---|---|
| **Partner** | An organisation with a commercial relationship in VoltReckon. Every partner has one or more roles. A partner is the tenant boundary for data. |
| **CPO** (Charge Point Operator) | The partner that operates charging stations and produces CDRs. A CPO may also act as an eMSP. |
| **eMSP** (e-Mobility Service Provider) | The partner that contracts with drivers and pays the CPO for charging. Also written EMSP. |
| **Roaming** | Use of a charging station by a driver contracted to a different organisation, enabled by an agreement between CPO and eMSP. |
| **Hub** | An intermediary that routes roaming messages. VoltReckon is not a hub. |
| **Roaming manager** | The human who onboards partners and pins commercial terms. |
| **Partner system** | A machine client authenticated with OAuth2 client credentials, acting for exactly one partner. |
| **Driver** | The end user of charging. VoltReckon stores a token or contract reference, never a driver profile. |

## 2. OCPI and roaming objects

| Term | Definition |
|---|---|
| **OCPI** | Open Charge Point Interface, the roaming protocol used for CDR exchange [ref-1][ref-2]. |
| **OCPI 2.2.1** | The compatibility edition VoltReckon must accept from existing partners [ref-1]. |
| **OCPI 2.3.0** | The target edition for new development [ref-2]. |
| **OCPI 2.3.0-ed2** | The 2026-06-18 edition that adds Invoice Reconciliation [ref-3][ref-4]. |
| **CDR** (Charge Detail Record) | The record of one charging session: identities, location, timestamps, energy, cost, and currency. |
| **Session** | A charging transaction from plug-in to unplug, identified by `session_id` in the CDR. |
| **Location** | An OCPI location containing EVSEs and connectors. VoltReckon stores the identifiers needed for rating context, not a full location inventory. |
| **EVSE** | Electric Vehicle Supply Equipment: one or more connectors at a location. |
| **Connector** | The physical plug and its standard, power, and tariff identifiers. |
| **Token** | The OCPI identifier presented by the driver or vehicle. Treated as a pseudonymous contract reference. |
| **Credit CDR** | A CDR that reverses an earlier CDR. It has `credit=true` and `credit_reference_id` equal to the original CDR `id`; only total fields are negative. |
| **CDR dimension** | A measured quantity on a CDR, such as energy, time, flat fee, or parking, with its own unit and period. |
| **Tariff** | A published price list with components and restrictions. |
| **Tariff version** | An immutable snapshot of a tariff with an effective window. A CDR is pinned to one version. |
| **Price component** | One priced element of a tariff: energy, time, flat, parking, or reservation. |
| **Tariff restriction** | A condition on a tariff or component, such as day, time, or minimum duration. |
| **Invoice Reconciliation** | The OCPI 2.3.0-ed2 module where a CPO or eMSP publishes the CDRs that belong to an invoice [ref-4]. |

## 3. Commercial and financial objects

| Term | Definition |
|---|---|
| **Ingestion** | Receiving, validating, deduplicating, and storing a CDR before rating. |
| **Quarantine** | A durable state for a CDR that cannot be accepted. Quarantined CDRs have no financial effect and a reason code. |
| **Rating** | Applying a pinned tariff version to a CDR to produce amounts. Rating is deterministic and repeatable. |
| **Re-rating** | Rating the same CDR again, normally after a correction, without mutating the prior result. |
| **Variance** | A recorded difference between two rating results, a CDR and an invoice, or a statement and the ledger. |
| **Invoice** | A financial document issued by one partner to another for rated CDRs, with tax and a due date. |
| **Credit note** | A new document that reduces or reverses an issued invoice; the original invoice is never edited. |
| **Invoice line** | One rated CDR or adjustment on an invoice, with quantity, unit price, net, tax, and total. |
| **Reconciliation** | Matching a partner statement or invoice to internal CDRs and invoices, and recording exceptions. |
| **Exception** | A reconciliation difference that needs a human decision: missing, duplicate, amount, tax, or timing. |
| **Dispute** | A case raised against an invoice, CDR, rating result, or reconciliation exception. |
| **Evidence** | A file or reference attached to a dispute with a hash and metadata. |
| **Settlement** | The periodic calculation of net amounts owed between two partners. |
| **Netting** | Offsetting invoices and credit notes across a pair and period to reach one payable amount. |
| **Settlement statement** | The reproducible, hashed output of a settlement run. |
| **Ageing** | The classification of open receivables and payables by due-date bucket. |
| **Maker-checker** | A control where one user prepares a financial action and a different user approves it. |

## 4. Accounting

| Term | Definition |
|---|---|
| **Ledger** | The append-only record of financial postings. |
| **Journal entry** | A balanced set of debit and credit lines for one financial event. |
| **Posting** | One debit or credit line in a journal entry. |
| **Chart of accounts** | The versioned list of account codes and their normal balances. |
| **Account** | A named ledger bucket, such as receivable, payable, revenue, or tax. |
| **Trial balance** | The report of debit and credit totals and net balances per account for a period. |
| **Period** | A closed or open accounting window, normally a calendar month in Asia/Kolkata. |
| **Open period** | A period that accepts postings. |
| **Closed period** | A period that rejects new postings; corrections go to the next open period with a link to the original. |
| **Reversal** | A new journal that exactly negates an earlier journal; the earlier journal is unchanged. |
| **Minor units** | The smallest integer unit of a currency, such as paise for INR. Money is stored as an integer count of minor units. |
| **Currency** | An ISO 4217 three-letter code [ref-25]. |
| **Rounding** | Converting an exact amount to payable minor units using a documented rule, normally HALF_UP per line. |
| **Balanced** | Total debits equal total credits for a journal, and the sum of all account balances is zero. |

## 5. Indian tax and compliance

| Term | Definition |
|---|---|
| **GST** | Goods and Services Tax, the Indian indirect tax on supply. |
| **SAC** | Services Accounting Code. EV charging is treated as SAC 998714 in the cited AAR [ref-14]. |
| **Place of supply** | The jurisdiction that determines how GST is split between CGST, SGST, and IGST. |
| **CGST / SGST / IGST** | Central GST, State GST, and Integrated GST components of a tax amount. |
| **Tax rate** | An effective-dated configuration of rate and tax type, never a hard-coded number. |
| **Taxable value** | The amount on which GST is calculated, normally net of discounts and excluding tax. |
| **HSN** | Harmonised System of Nomenclature code used for goods. |
| **E-invoice** | An electronic invoice registered with the GST e-invoice system, identified by an IRN [ref-9]. |
| **IRN** | Invoice Reference Number, a 64-character identifier returned by the e-invoice system. |
| **AATO** | Aggregate Annual Turnover, the threshold that determines e-invoice applicability. |
| **DPDP** | Digital Personal Data Protection Act, 2023, and its rules [ref-11]. |
| **Data principal** | The individual to whom personal data relates. |
| **Data fiduciary** | The entity that determines the purpose and means of processing personal data. |
| **Personal data** | Data about an identifiable individual. A token or contract reference can be personal data in context. |
| **Minimisation** | Collecting and retaining only the personal data needed for a stated purpose. |

## 6. Platform and engineering

| Term | Definition |
|---|---|
| **Module** | A Spring Modulith module under `com.voltreckon.<module>` with a public API and an `internal` package. |
| **Public API** | The types another module may import: commands, queries, results, events, and enums. |
| **Internal** | Implementation types, including persistence and web adapters, that no other module may import. |
| **Domain layer** | Pure Java rules and value objects with no Spring, JPA, or Jackson dependency. |
| **Application layer** | Use-case orchestration and transaction boundaries inside a module. |
| **Adapter layer** | Web, persistence, messaging, and external-system code inside a module. |
| **Shared kernel** | The `shared` module: small, stable value types and errors used by every module. |
| **Platform** | The `platform` module: technical persistence, time, identifiers, outbox, and web plumbing. |
| **Outbox** | A table of events written in the same transaction as the state change, then delivered at least once. |
| **Domain event** | An immutable record that something happened, named `<module>.<entity>.<action>.v<major>`. |
| **Idempotency key** | A client-supplied key that makes a retried write return the original result instead of repeating it. |
| **Processed event** | A consumer-side record that an event ID has already been handled. |
| **Partner scope** | The enforced filter that limits every read and write to one partner, except explicitly authorised cross-partner roles. |
| **Audit chain** | An append-only sequence of audit records where each hash covers the previous hash. |
| **UBC** | Unified Billing & Charging, a Beckn-based protocol separate from OCPI [ref-27]. |
| **Beckn** | An open network protocol; VoltReckon would expose an adapter, not a core dependency. |
| **Walking skeleton** | The Phase 0 vertical slice: build, migration, health endpoint, architecture test, and one integration test. |

## 7. Abbreviations

| Abbreviation | Expansion |
|---|---|
| AAR | Authority for Advance Ruling |
| API | Application Programming Interface |
| CDR | Charge Detail Record |
| CPO | Charge Point Operator |
| eMSP / EMSP | e-Mobility Service Provider |
| EVSE | Electric Vehicle Supply Equipment |
| GST | Goods and Services Tax |
| HSN | Harmonised System of Nomenclature |
| IRN | Invoice Reference Number |
| IRP | Invoice Registration Portal |
| OCPI | Open Charge Point Interface |
| SAC | Services Accounting Code |
| UBC | Unified Billing & Charging |
