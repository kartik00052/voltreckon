# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Nothing yet. The application is not implemented.

## [0.1.0] - 2026-11-12

### Added

- Research library covering industry analysis, the India EV ecosystem, competitors, standards, and a verified learning resource library.
- Architecture documentation: system context, architecture overview, module boundaries, database design, security architecture, deployment architecture, reliability, and supporting diagrams.
- ADRs for architecture style, database strategy, financial model, messaging strategy, OCPI scope, AI deferral, UBC positioning, and deferred Redis/Spring Batch.
- PostgreSQL 18 reference schema and financial domain design.
- OpenAPI 3.1 contract and API design guide.
- Testing strategy, implementation roadmap, issue breakdown, and operations runbook.
- Principal-engineer review with scope and validation concerns.
- Root project files: README, CONTRIBUTING, SECURITY, CODE_OF_CONDUCT, CHANGELOG, and MIT LICENSE.

### Changed

- Reorganized documentation into the required `research`, `architecture`, ADR, database, API, testing, roadmap, operations, and review structure.
- Updated the resource library to a 24-category format with verified URLs and metadata.

### Fixed

- Corrected internal links after moving research and architecture files.
- Replaced dead source URLs and recorded rejected links.

### Security

- Documented the threat model, tenancy rules, audit trail, and responsible disclosure process.
- No application code or production deployment exists in this release.
