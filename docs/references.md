# References

- **Status:** Draft
- **Owner:** VoltReckon maintainer
- **Last verified:** 2026-11-13
- **Applies to phases:** 0–10

Every external claim marked `[ref-N]` resolves here. IDs are appended, never reused. A
source that is a landing page or a document repository is labelled as such; the exact
document title is the claim being supported. Facts that could not be pinned to a primary
document are marked `[ASSUMPTION]` in the body and are not the sole basis of a MUST.

| ID | Source | URL | Supports | Verified |
|---|---|---|---|---|
| ref-1 | OCPI, specification tag `2.2.1` | https://github.com/ocpi/ocpi/tree/2.2.1 | Compatibility edition; CDR 2.2.1 fields [ref-1] | 2026-11-13 |
| ref-2 | OCPI, specification tag `v2.3.0` | https://github.com/ocpi/ocpi/tree/v2.3.0 | Target edition; 2.3.0 changes | 2026-11-13 |
| ref-3 | OCPI, specification tag `v2.3.0-ed2` | https://github.com/ocpi/ocpi/tree/v2.3.0-ed2 | 2026-06-18 edition; version history | 2026-11-13 |
| ref-4 | OCPI, Invoice Reconciliation module, `v2.3.0-ed2` | https://github.com/ocpi/ocpi/blob/v2.3.0-ed2/mod_invoice_reconciliation.asciidoc | Invoice Reconciliation object and endpoints | 2026-11-13 |
| ref-9 | GST e-invoice portal, Government of India | https://einvoice1.gst.gov.in/ | E-invoice registration; IRN; cancellation window | 2026-11-13 |
| ref-11 | Ministry of Electronics and IT, data protection framework | https://www.meity.gov.in/data-protection-framework | DPDP Act, 2023 and DPDP Rules, 2025 | 2026-11-13 |
| ref-13 | Ministry of Power, charging infrastructure clarification | https://powermin.gov.in/ | Charging an EV is a service, clarification dated 2018-04-13 | 2026-11-13 |
| ref-14 | GST Council, Karnataka AAR No. KAR ADRG 24/2023 | https://gstcouncil.gov.in/sites/default/files/AAR/karnataka_state_aar_no._24-2023_of_chamundeswari_electricity_supply.pdf | SAC 998714; 18% treatment for standalone EV charging | 2026-11-13 |
| ref-18 | Maven Central, Spring Boot parent 4.1.2 | https://central.sonatype.com/artifact/org.springframework.boot/spring-boot-starter-parent/4.1.2 | Runtime and BOM version | 2026-11-13 |
| ref-19 | Maven Central, Spring Modulith BOM 2.1.0 | https://central.sonatype.com/artifact/org.springframework.modulith/spring-modulith-bom/2.1.0 | Modulith version | 2026-11-13 |
| ref-23 | IETF, RFC 9457 | https://www.rfc-editor.org/rfc/rfc9457.html | Problem Details for HTTP APIs | 2026-11-13 |
| ref-24 | IETF, RFC 3339 | https://www.rfc-editor.org/rfc/rfc3339.html | Date and time on the Internet | 2026-11-13 |
| ref-25 | ISO, ISO 4217 currency codes | https://www.iso.org/iso-4217-currency-codes.html | Currency codes and minor units | 2026-11-13 |
| ref-27 | UBC / Beckn protocol | https://ubc.energy/ | UBC is Beckn-based and separate from OCPI | 2026-11-13 |
| ref-29 | Spring Modulith 2.1, events | https://docs.spring.io/spring-modulith/reference/2.1/events.html | Event publication registry, at-least-once delivery | 2026-11-13 |
| ref-30 | ArchUnit | https://www.archunit.org/ | Architecture rules in JUnit | 2026-11-13 |

## Notes on sources

- OCPI edition dates: `2.2.1` is 2021-10-06, `v2.3.0` is 2025-02-21, and `v2.3.0-ed2` is
  2026-06-18 [ref-1][ref-2][ref-3].
- The Invoice Reconciliation module is added by `v2.3.0-ed2`, not by `v2.3.0` [ref-3][ref-4].
- CDR fields `cdr_token`, `cdr_location`, `credit`, `credit_reference_id`, and
  `home_charging_compensation` already exist in `2.2.1` [ref-1]. They are not 2.3.0-only.
- `ref-13` is a ministry landing page; the exact clarification document is titled
  *Clarification on charging infrastructure for electric vehicles* and is dated 2018-04-13.
  Pin the PDF before Phase 5; until then treat the precise wording as `[ASSUMPTION]`.
- `ref-14` is an Authority for Advance Ruling decision. It binds the applicant, not the
  industry. VoltReckon keeps GST rates effective-dated and configurable [ref-14].
- `ref-11` is the MeitY framework landing page. Pin the Act and the Rules PDFs before
  Phase 5; do not infer commencement dates from this registry.

## Reference gaps to close before the owning phase

| Needed by | Missing primary source | Action |
|---|---|---|
| 07-gst-and-compliance | CBIC Notification 11/2017-CT(R), rate schedule | Pin the notification PDF and serial number. |
| 07-gst-and-compliance | CBIC Notification 10/2025-CT(R), electricity nil rate | Pin the notification PDF and effective date. |
| 07-gst-and-compliance | CBIC Notification 09/2025-CT(R), EV chargers 5% | Pin the notification PDF and effective date. |
| 07-gst-and-compliance | IGST Act section 12 and CGST Rule 46 | Pin the India Code / CBIC text. |
| 07-gst-and-compliance | E-invoice AATO threshold and IRN rules | Confirm against the e-invoice portal and a current CBIC circular. |
| 07-gst-and-compliance | DPDP Act and Rules commencement | Confirm against MeitY notifications. |
| 13-build-and-operations | Testcontainers, PostgreSQL 18, Flyway 12 docs | Add the exact version pages used by the build. |
