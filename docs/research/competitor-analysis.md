# Competitor analysis

**Purpose:** map what already exists, what each category actually does, and where a narrow reconciliation workbench can plausibly fit.

**Caveat:** vendor capabilities are described from public documentation and marketing pages. Pricing is rarely public and is not asserted here. No vendor was contacted for this report.

---

## 1. Competitive landscape overview

```
                     Consumer / driver facing        Operator / back office
                     ────────────────────────        ──────────────────────
Discovery & payment  UBC/BHIM, PlugShare, OEM apps,   (not VoltReckon)
                     CPO/eMSP apps

Charging operations  (not VoltReckon)                 Driivz, AMPECO, Numocity,
                                                      Kazam, EVRE, in-house CSMS

Roaming connectivity  (not VoltReckon)                Hubject, Gireve, UBC/Beckn,
                                                      bilateral OCPI

Financial control     (not VoltReckon)                ERP + spreadsheets + custom
                                                      scripts + VoltReckon (target)
```

VoltReckon does not compete in the top three bands. It competes with the **fourth band**, which is currently a mix of ERP modules, spreadsheets, and bespoke scripts.

### 1.1 Company and project profiles

Fields are limited to what the vendor or a primary filing states publicly. "Unknown" means not verified, not "does not exist".

| Name | Website | Category | Main functionality | Target users | Documented integration standards | Business model (public) | Lessons for VoltReckon |
|---|---|---|---|---|---|---|---|
| **Hubject** | [hubject.com](https://www.hubject.com/) | Roaming hub | intercharge roaming, OCPI connectivity, Plug&Charge services | CPOs, eMSPs, OEMs | OCPI, ISO 15118 (Plug&Charge) | Roaming/network services (pricing not public) | Connectivity and contracts are a network business; integrate rather than compete. |
| **Gireve** | [gireve.com](https://www.gireve.com/) | Roaming hub / data | OCPI connectivity, Plug&Charge, market data | CPOs, eMSPs, public authorities | OCPI, ISO 15118 | Connectivity and data services (pricing not public) | Data products are adjacent; stay focused on the financial control layer. |
| **UBC / Beckn (India)** | No single official product site verified; see [launch reporting](https://www.thehindubusinessline.com/economy/india-gets-its-upi-for-ev-charging-as-kumaraswamy-unveils-unified-bharat-e-charge/article70970320.ece) | Public digital infrastructure | Discovery, ordering, UPI payment rail for EV charging | Drivers, CPOs, eMSPs | Beckn; UPI/BHIM | Public infrastructure | Complement it; do not build a consumer app or a competing gateway. |
| **ChargePoint** | [chargepoint.com](https://www.chargepoint.com/) | CPO + charging platform / eMSP | Networked charging, station management, fleet, driver app, roaming, eMSP services | CPOs, site hosts, fleets, drivers | OCPP-J 1.6, OCPI 2.1.1, OICP 2.1 (per public data sheets) | Hardware plus software subscriptions/services | Large players already bundle billing and roaming; compete on neutral, cross-platform reconciliation and audit. |
| **Driivz** | [driivz.com](https://driivz.com/) | CPMS | Charger operations, energy management, roaming, billing/reporting | CPOs, utilities, fleets | OCPP, OCPI (publicly described) | Enterprise software licence | Strong on operations; Indian GST/e-invoice and dispute evidence remain plausible gaps. |
| **AMPECO** | [ampeco.com](https://www.ampeco.com/) | CPMS | White-label charging platform, roaming, payments, dashboards | CPOs, utilities, fleets | OCPI, OCPP (publicly described) | SaaS subscription | A broad platform can add reconciliation; a neutral control layer is the differentiator. |
| **Monta** | [monta.com](https://monta.com/) | CPMS / eMSP platform | Charge point management, billing/invoicing, roaming, settlement reconciliation, payments | CPOs, utilities, fleets, parking operators | OCPP-native; "100+ direct OCPI integrations" (public site) | SaaS plus regulated payment services (EMI-licensed) | Shows that settlement reconciliation is becoming table stakes for large platforms; win on depth, neutrality, and Indian compliance. |
| **Numocity** | [numocity.com](https://numocity.com/) | CPMS (India-origin, global) | Charging network management, roaming, fleets, load management, service operations | CPOs, eMSPs, fleets, utilities | OCPP, OCPI (publicly described); Hubject partnership | Software/services | Local operations matter; reconciliation is often secondary. |
| **Kazam** | [kazam.energy](https://kazam.energy/) | Charger manufacturer + CMS / CPO | OCPP-compliant chargers, CMS, roaming, revenue management, UBC onboarding | CPOs, OEMs, fleets, businesses | OCPP; roaming (publicly described) | Hardware + software + operations | Indian operators want practical onboarding, not enterprise suites. |
| **EVRE** | [evre.in](https://evre.in/) | Charger manufacturer + operations | AC/DC chargers, installation, operations, billing integrations | Builders, CPOs, fleets, OEMs, institutions | Hardware/OCPP (publicly described) | Hardware/operations | Hardware vendors increasingly bundle software; finance tooling is usually manual. |
| **Tally / Zoho Books** | [tallysolutions.com](https://tallysolutions.com/) / [zoho.com/books](https://www.zoho.com/books/) | Accounting software | GST invoices, returns, ledger, compliance | SMBs and finance teams | Export/import, APIs | Licence/subscription | Integrate via exports; do not rebuild statutory accounting. |
| **steve** | [github.com/steve-community/steve](https://github.com/steve-community/steve) | Open-source OCPP/OCPI platform | Charging platform reference implementation | Developers, small operators | OCPP, OCPI | Open source | Study the protocol handling; do not fork it as the financial product. |

**Note on ChargePoint:** the standards list above comes from ChargePoint public data sheets, which name OCPI 2.1.1, OCPP-J 1.6, and OICP 2.1. A company can support newer versions than a specific data sheet states; do not assume it is limited to those versions.

### 1.2 Capability comparison

Legend: **Yes** = publicly documented; **Partial** = adjacent or platform-dependent; **No** = not a public focus; **?** = not verified.

| Capability | Hubject | Gireve | ChargePoint | Driivz | AMPECO | Monta | Indian CPMS | Tally/Zoho | VoltReckon (target) |
|---|---|---|---|---|---|---|---|---|---|
| Charger operations / OCPP | No | No | Yes | Yes | Yes | Yes | Yes | No | No |
| Roaming connectivity | Yes | Yes | Yes | Yes | Yes | Yes | Partial | No | Consumes |
| OCPI CDR handling | Yes | Yes | Yes | Yes | Yes | Yes | Partial | No | Yes |
| CDR-level re-rating and variance | ? | ? | Partial | Partial | Partial | Partial | ? | No | Yes |
| Invoice reconciliation / exceptions | Partial | Partial | Partial | Partial | Partial | Yes (settlement reconciliation) | ? | No | Yes |
| GST / Indian e-invoice readiness | No | No | No (global focus) | Partial | Partial | Partial | Partial | Yes | Yes (data, not filing) |
| Double-entry ledger | No | No | No | No | No | No | No | Yes | Yes |
| Dispute evidence chain | No | No | No | ? | ? | ? | ? | No | Yes |
| Settlement netting / statements | Partial | Partial | Partial | Partial | Partial | Yes | Partial | No | Yes |
| Self-hostable | No | No | No | No | No | No | No | No | Yes |

The matrix is deliberately conservative. "No" means "not publicly positioned as a capability", not a claim that the vendor cannot do it internally.

---

## 2. Roaming hubs

### Hubject

- Operates a large international roaming network (intercharge) and provides OCPI-based connectivity, Plug&Charge (ISO 15118) services, and related tooling.
- Value: reach, contracts, certificate handling, and partner onboarding.
- Does not replace a CPO's or eMSP's internal billing/reconciliation system. A hub routes and may record transactions; the parties still must reconcile invoices and tax.
- Publicly documented: [hubject.com](https://www.hubject.com/) — capability summary only; no pricing asserted.

### Gireve

- European roaming hub and data platform; OCPI connectivity, Plug&Charge, and market data.
- Similar position: network and data layer, not the operator's financial subledger.
- Publicly documented: [gireve.com](https://www.gireve.com/).

### UBC / Beckn (India)

- Public digital infrastructure, not a commercial hub. Discovery and payment via BHIM/UPI; Beckn protocol.
- Reported pilot states: Maharashtra, Karnataka, Delhi-NCR, Haryana, Rajasthan.
- Does not (as publicly described) provide CPO↔eMSP invoice reconciliation, GST invoicing, or dispute evidence.

**Implication:** hubs are **partners or upstream rails**, not competitors. VoltReckon can consume their CDR exchanges. Competing with a hub would require network effects VoltReckon does not have.

---

## 3. CPMS / charging platform vendors

These platforms manage chargers (OCPP), sessions, pricing, and often roaming. Some include billing modules.

| Vendor | Publicly described strengths | Likely overlap with VoltReckon | Likely gaps VoltReckon can target |
|---|---|---|---|
| **ChargePoint** | Hardware, network software, fleet, driver app, roaming, eMSP services | Billing, roaming, fleet reimbursement | Cross-platform neutral reconciliation; Indian GST/e-invoice depth |
| **Driivz** | Large-scale CPMS, operations, energy management, roaming connectivity | Billing, reporting | Deep CPO↔eMSP reconciliation evidence, Indian GST/e-invoice workflow |
| **AMPECO** | White-label CPMS, OCPI roaming, payments, dashboards | Tariffs, invoicing, roaming | Standalone reconciliation across multiple CPMS/partners; audit-first ledger |
| **Monta** | CPMS, billing/invoicing, roaming, settlement reconciliation, EMI-licensed payments | Billing, invoicing, roaming settlement | Neutral reconciliation across platforms; deeper audit/evidence; Indian tax fit |
| **Numocity** | Indian CPMS/charging platform, OCPP, network management | Local operations, billing | Partner-invoice reconciliation as a separate control layer |
| **Kazam** | Indian charging platform + CPO; UBC integration | Billing, operations | Cross-partner reconciliation independent of a single platform |
| **EVRE** | Indian charging infrastructure and platform | Operations, billing | Same as above |
| **In-house CSMS** | Fully tailored to the operator | Everything the operator builds | Mature reconciliation, tax, audit, and settlement without building it |

**Honest assessment:** if a CPO already runs Driivz or AMPECO, it may prefer that vendor's billing module. VoltReckon's best fit is:

- Operators with a **custom or basic CSMS** and Excel-based finance.
- Operators using **multiple CPMS** or multiple partners and needing one neutral reconciliation layer.
- Finance teams that need **auditability and GST/e-invoice data** more than charger operations.

VoltReckon should not claim superiority over these platforms in charger operations. It does not do charger operations.

---

## 4. Indian CPO platforms and networks

Large Indian CPOs (Tata Power EZ Charge, Statiq, ChargeZone, Jio-bp pulse, Fortum, Ather Grid, Zeon) run their own platforms and finance operations. They are potential **users** of a reconciliation tool but are unlikely to buy a small vendor's system without proof.

Smaller CPOs and fleet operators are more plausible early adopters because:

- They have fewer engineering resources.
- They integrate with several eMSPs/aggregators.
- Their finance processes are manual and error-prone.
- They value a self-hostable tool with CSV import.

---

## 5. Accounting and ERP software

| Category | Examples | What they do well | What they do not do |
|---|---|---|---|
| Indian accounting | Tally, Zoho Books, Busy | GST invoices, returns, ledger, compliance | CDR-level rating, OCPI reconciliation, session-level evidence |
| Global ERP | SAP, Oracle, NetSuite | Enterprise finance, consolidation | EV-charging-specific CDR logic without customization |
| Spreadsheets | Excel, Google Sheets | Flexibility | Auditability, invariants, idempotency, scale |

**Positioning:** VoltReckon is a **subledger and reconciliation system**, not a replacement for accounting software. It should export balanced journals and invoice data to Tally/Zoho/ERP. This reduces adoption friction and avoids competing with entrenched compliance tools.

---

## 6. Open-source projects to study (not direct competitors)

| Project | What it is | Why it matters |
|---|---|---|
| **steve** (`steve-community/steve`) | Open-source OCPP/OCPI charging platform | Reference for OCPI endpoints, CDR handling, and data models |
| **Java-OCA-OCPP** (`ChargeTimeEU`) | OCPP client/server library | Shows protocol message handling; not a settlement system |
| **Extrawest OCPI 2.2.1** | OCPI client/server example | Reference for OCPI module mapping |
| **ocpi-tariffs** (`tandemdrive`) | Tariff calculation library | Reference for tariff element/restriction evaluation |
| **OCPI OpenAPI specification** (`ocpi/openapi-specification`) | Generated OpenAPI specs | Contract reference for integration |

These are useful for learning and for contract testing. None is a GST-aware reconciliation subledger. Do not fork them as the product; study them and write the financial domain independently.

---

## 7. Build vs. buy vs. adapt

| Option | Effort | Control | Fit |
|---|---|---|---|
| Buy a CPMS with billing (Driivz/AMPECO/Numocity) | Medium–high licence cost; onboarding | Low | Good if the operator also needs charger operations |
| Use ERP + spreadsheets | Low setup; high manual effort | Medium | Works at very small scale; fails on audit and volume |
| Build custom scripts | High maintenance; hidden coupling | High | Common today; fragile |
| Adopt a roaming hub's reporting | Low | Low | Does not solve internal GST/reconciliation |
| **VoltReckon (self-hosted)** | Medium build; low licence | High | Fits operators with custom CSMS and finance-heavy needs |

The honest conclusion: **VoltReckon is a build option for a narrow problem, not a category-defining product.** Its justification is control, auditability, and Indian tax fit, not breadth.

---

## 8. Differentiation (and what is not differentiating)

**Genuinely differentiating if executed well:**

- OCPI 2.3.0 Invoice Reconciliation semantics implemented rigorously.
- Immutable, double-entry ledger tied to CDR and invoice evidence.
- GST/e-invoice-ready data with versioned tax rules.
- Dispute evidence chain.
- Small, auditable, self-hostable codebase.

**Not differentiating:**

- "Supports OCPI" — many systems do.
- "Has a dashboard" — table stakes.
- "Uses AI" — not credible without data and a controlled use case.
- "Blockchain for trust" — no buyer requirement; adds complexity.
- "Microservices at scale" — irrelevant at MVP volume.

**Weaknesses to acknowledge:**

- No network effects; a hub or CPMS vendor can add reconciliation features.
- No brand or customer base.
- Dependent on partner data quality and cooperation.
- Indian tax law may change and require ongoing maintenance.
- A single developer cannot match vendor support and SLAs.

---

## 9. Competitive strategy

1. **Do not compete on connectivity.** Integrate with hubs, UBC, and partner OCPI endpoints.
2. **Do not compete on charger operations.** Consume records from any CSMS.
3. **Win on evidence and financial control.** Make every rupee traceable from meter to ledger.
4. **Win on Indian compliance fit.** GST and e-invoice data prepared correctly, configurable per entity.
5. **Stay self-hostable and small.** Operators with sensitive commercial data may prefer it.
6. **Publish the blueprint.** Credibility comes from rigor, not marketing.

---

## 10. Sources

- Hubject — [hubject.com](https://www.hubject.com/)
- Gireve — [gireve.com](https://www.gireve.com/)
- ChargePoint platform — [chargepoint.com](https://www.chargepoint.com/)
- ChargePoint cloud plan data sheet (OCPI 2.1.1, OCPP-J 1.6, OICP 2.1) — [docs.chargepoint.com](https://docs.chargepoint.com/spec-lib/content/pdfs/7-misc/cp_commercial_cloud_plan.pdf)
- ChargePoint FY2026 Form 10-K (eMSP services, roaming, reconciliation) — [SEC EDGAR](https://www.sec.gov/Archives/edgar/data/1777393/000177739326000013/chpt-20260131.htm)
- Monta platform — [monta.com](https://monta.com/)
- Numocity — [numocity.com](https://numocity.com/)
- Kazam — [kazam.energy](https://kazam.energy/)
- EVRE — [evre.in](https://evre.in/)
- Tally — [tallysolutions.com](https://tallysolutions.com/)
- Zoho Books — [zoho.com/books](https://www.zoho.com/books/)
- AMPECO EV roaming — [ampeco.com](https://www.ampeco.com/us/ev-charging-platform/ev-roaming)
- AMPECO glossary (eMSP/roaming) — [ampeco.com](https://www.ampeco.com/ev-charging-glossary/ev-roaming-network-operator)
- Driivz roaming article — [driivz.com](https://driivz.com/blog/eroaming-advantages)
- steve — [github.com/steve-community/steve](https://github.com/steve-community/steve)
- Java-OCA-OCPP — [github.com/ChargeTimeEU/Java-OCA-OCPP](https://github.com/ChargeTimeEU/Java-OCA-OCPP)
- Extrawest OCPI — [github.com/extrawest/Extrawest-OCPI-2.2.1](https://github.com/extrawest/Extrawest-OCPI-2.2.1)
- ocpi-tariffs — [github.com/tandemdrive/ocpi-tariffs](https://github.com/tandemdrive/ocpi-tariffs)
- OCPI OpenAPI — [github.com/ocpi/openapi-specification](https://github.com/ocpi/openapi-specification)
- UBC launch — [The Hindu BusinessLine](https://www.thehindubusinessline.com/economy/india-gets-its-upi-for-ev-charging-as-kumaraswamy-unveils-unified-bharat-e-charge/article70970320.ece)

All URLs above were reachable on 12 November 2026. Vendor pages change; re-check capability claims before relying on them.
