#!/usr/bin/env python3
"""VoltReckon scaffold: backend (Maven multi-module, Spring Boot) + frontend (React TSX).

Run from the repo root:      python scaffold.py
Preview only (no writes):    python scaffold.py --dry-run
Other location:              python scaffold.py --root C:\\path\\to\\VoltReckon

Safe to re-run: it NEVER overwrites an existing file, so your docs/, README,
Makefile, compose.yaml and .github/workflows/ci.yml are left untouched.
"""
import argparse
import sys
from pathlib import Path

# --------------------------------------------------------------------------- #
# Layout roots
# --------------------------------------------------------------------------- #
APP = "backend/voltreckon-app"
OCPI = "backend/voltreckon-ocpi-model"
SIM = "backend/voltreckon-simulator"
FE = "frontend"
MAIN = f"{APP}/src/main/java/com/voltreckon"
TEST = f"{APP}/src/test/java/com/voltreckon"
RES = f"{APP}/src/main/resources"
SIMJ = f"{SIM}/src/main/java/com/voltreckon/simulator"
OCPIJ = f"{OCPI}/src/main/java/com/voltreckon/ocpi"

SPEC = []  # list of (directory, [file names]); a name without a dot becomes NAME.java


def add(directory, names):
    SPEC.append((directory, [n.strip() for n in names.split(",") if n.strip()]))


def module(name, root="", **subs):
    """One Spring Modulith module: public API in the root package, the rest under internal/."""
    base = f"{MAIN}/{name}"
    add(base, "package-info" + ("," + root if root else ""))
    for sub, names in subs.items():
        add(f"{base}/internal/{sub}", names)


# --------------------------------------------------------------------------- #
# Repo root extras (docs/, README, Makefile, compose.yaml, ... already exist)
# --------------------------------------------------------------------------- #
add(".github", "dependabot.yml")
add(".github/workflows", "backend-ci.yml,frontend-ci.yml")
add("deploy/docker", "backend.Dockerfile,frontend.Dockerfile,nginx.conf")
add("deploy/observability", "otel-collector.yaml,prometheus.yml,loki-config.yaml,tempo.yaml")
add("deploy/observability/grafana/provisioning/datasources", "datasources.yml")
add("deploy/observability/grafana/provisioning/dashboards",
    "dashboards.yml,ingestion.json,ledger.json,settlement.json")
add("data", "README.md")
add("data/raw", ".gitkeep")
add("data/processed", ".gitkeep")
add("scripts", "dev-up.ps1,dev-up.sh,load-demo-data.ps1")

# --------------------------------------------------------------------------- #
# Backend: parent + tooling
# --------------------------------------------------------------------------- #
add("backend", "pom.xml")
add("backend/.mvn", "maven.config,jvm.config")
add("backend/config/checkstyle", "checkstyle.xml")
add("backend/config/spotbugs", "exclude.xml")

# --------------------------------------------------------------------------- #
# Backend: voltreckon-ocpi-model (pure Java, no Spring)
# --------------------------------------------------------------------------- #
add(OCPI, "pom.xml")
add(f"{OCPIJ}/common", "Price,DisplayText,GeoLocation")
add(f"{OCPIJ}/cdr", "Cdr,CdrLocation,CdrToken,ChargingPeriod,CdrDimension")
add(f"{OCPIJ}/tariff", "Tariff,TariffElement,PriceComponent,TariffRestrictions")
add(f"{OCPIJ}/credentials", "Credentials,Role,BusinessDetails")
add(f"{OCPIJ}/envelope", "OcpiResponse,OcpiStatusCode")
add(f"{OCPIJ}/validation", "CdrConstraints,CdrValidator")
add(f"{OCPI}/src/test/java/com/voltreckon/ocpi", "CdrJsonRoundTripTest,TariffJsonRoundTripTest")
add(f"{OCPI}/src/test/resources/spec-examples", ".gitkeep")

# --------------------------------------------------------------------------- #
# Backend: voltreckon-app (modular monolith)
# --------------------------------------------------------------------------- #
add(APP, "pom.xml")
add(MAIN, "VoltReckonApplication")

# shared kernel + platform infrastructure
add(f"{MAIN}/shared", "package-info")
add(f"{MAIN}/shared/money", "Money,MoneyAmountConverter,RoundingPolicy")
add(f"{MAIN}/shared/party", "PartyRef,CountryCode")
add(f"{MAIN}/shared/error", "DomainException,ErrorCode,ProblemDetailFactory")
add(f"{MAIN}/shared/idempotency", "IdempotencyKey,IdempotencyService,IdempotencyRecord")
add(f"{MAIN}/shared/event", "DomainEvent")
add(f"{MAIN}/platform", "package-info")
add(f"{MAIN}/platform/config", "JacksonConfig,JpaConfig,ClockConfig,OpenApiConfig")
add(f"{MAIN}/platform/security", "SecurityConfig,JwtAuthConverter,OcpiTokenAuthFilter,CurrentUser")
add(f"{MAIN}/platform/web", "GlobalExceptionHandler,CorrelationIdFilter")
add(f"{MAIN}/platform/messaging", "KafkaConfig,EventExternalizationConfig")
add(f"{MAIN}/platform/storage", "BlobStore,MinioBlobStore,LocalFsBlobStore")
add(f"{MAIN}/platform/observability", "MetricsConfig,TracingConfig")

# business modules
module("iam",
       domain="AppUser,RoleAssignment,Role",
       application="AuthService,TokenService",
       persistence="AppUserRepository",
       web="AuthController,dto/.gitkeep")
module("partners", root="PartnerApi",
       domain="Party,PartyRole,RoamingAgreement,GstProfile",
       application="PartyService,AgreementService",
       persistence="PartyRepository,AgreementRepository",
       web="PartyController,AgreementController,dto/.gitkeep")
module("ingestion", root="CdrAccepted,CdrRejected",
       domain=("RawCdr,IngestionStatus,QuarantineReason,rules/ValidationRule,rules/SchemaRule,"
               "rules/EnergyConsistencyRule,rules/TimeWindowRule,rules/KnownPartyRule,rules/DuplicateRule"),
       application="IngestCdrUseCase,ValidationPipeline,ReplayQuarantinedUseCase",
       persistence="RawCdrRepository",
       web="OcpiCdrController,CdrBatchUploadController,QuarantineController,dto/.gitkeep")
module("tariff", root="PricingApi,PriceBreakdown",
       domain="Tariff,TariffVersion,TariffElement,RestrictionMatcher",
       application="PricingEngine,TariffVersionResolver,TimeOfUseSplitter",
       persistence="TariffRepository",
       web="TariffController,dto/.gitkeep")
module("ledger", root="LedgerApi,TransactionPosted",
       domain=("Account,AccountType,JournalTransaction,JournalEntry,TransactionStatus,"
               "AccountingPeriod,DoubleEntryPolicy"),
       application="PostingService,ReversalService,BalanceService,PeriodCloseService",
       persistence="AccountRepository,JournalRepository,BalanceSnapshotRepository",
       web="AccountController,JournalController,TrialBalanceController,dto/.gitkeep")
module("billing", root="BillingApi,InvoiceIssued",
       domain="Invoice,InvoiceLine,CreditNote,InvoiceState,GstBreakup,PlaceOfSupply",
       application="InvoiceService,GstCalculator,InvoiceNumberGenerator,CreditNoteService",
       einvoice="IrpClient,HttpIrpClient,EInvoicePayloadMapper,IrnService",
       pdf="InvoicePdfRenderer,QrCodeService",
       persistence="InvoiceRepository,CreditNoteRepository",
       web="InvoiceController,CreditNoteController,dto/.gitkeep")
module("dispute", root="DisputeOpened,DisputeResolved",
       domain="Dispute,DisputeState,DisputeTransitions,Evidence",
       application="DisputeService,EvidenceService",
       persistence="DisputeRepository",
       web="DisputeController,dto/.gitkeep")
module("settlement", root="SettlementApproved",
       domain="NettingRun,SettlementStatement,PayoutInstruction,ApprovalStep",
       application="NettingEngine,StatementService,ApprovalService",
       jobs="PeriodSettlementJob",
       persistence="NettingRunRepository,StatementRepository",
       web="NettingController,StatementController,ApprovalController,dto/.gitkeep")
module("reconciliation",
       domain="ReconciliationRun,Discrepancy,MatchResult",
       application="StatementImporter,CdrMatcher,DiscrepancyService",
       persistence="ReconciliationRepository",
       web="ReconciliationController,dto/.gitkeep")
module("audit",
       domain="AuditEvent,HashChain",
       application="AuditRecorder,ChainVerifier,SessionTimelineQuery",
       persistence="AuditEventRepository",
       web="AuditController,dto/.gitkeep")
module("reporting", **{"": "DashboardQueries,DashboardController,dto/.gitkeep"})

# resources
add(RES, "application.yml,application-local.yml,application-prod.yml,logback-spring.xml")
add(f"{RES}/db/migration",
    "V001__extensions_and_schemas.sql,V002__partners.sql,V003__tariffs.sql,V004__ingestion.sql,"
    "V005__ledger_core.sql,V006__ledger_periods_balances.sql,V007__billing.sql,V008__disputes.sql,"
    "V009__settlement.sql,V010__reconciliation.sql,V011__audit_hash_chain.sql,"
    "V012__event_publication_outbox.sql,V013__iam.sql,V014__seed_chart_of_accounts.sql")
add(f"{RES}/reference", "gst-state-codes.csv,sac-codes.yml")
add(f"{RES}/templates/invoice", "invoice.html,invoice.css")

# tests
add(TEST, "ArchitectureTests")
add(f"{TEST}/support", "PostgresTestConfig,KafkaTestConfig,TestClock,CdrFixtures,JwtTestSupport")
add(f"{TEST}/ingestion", "CdrValidationPipelineTest,IngestCdrIT")
add(f"{TEST}/tariff", "PricingEngineTest")
add(f"{TEST}/ledger", "LedgerInvariantProperties,PostingServiceIT")
add(f"{TEST}/billing", "GstCalculatorTest,InvoiceStateIT")
add(f"{TEST}/dispute", "DisputeTransitionsTest")
add(f"{TEST}/settlement", "NettingEngineTest,SettlementApprovalIT")
add(f"{TEST}/audit", "ChainVerifierTest")
add(f"{TEST}/contract", "OpenApiContractTest")
add(f"{TEST}/e2e", "CdrToSettlementFlowIT")
add(f"{APP}/src/test/resources", "application-test.yml")
add(f"{APP}/src/test/resources/fixtures/cdr", ".gitkeep")
add(f"{APP}/src/test/resources/fixtures/scenarios", ".gitkeep")

# --------------------------------------------------------------------------- #
# Backend: voltreckon-simulator (synthetic data, mock CPO, mock IRP)
# --------------------------------------------------------------------------- #
add(SIM, "pom.xml")
add(SIMJ, "SimulatorApplication")
add(f"{SIMJ}/cli", "GenerateCommand,PushCommand,ReplayCommand")
add(f"{SIMJ}/dataset", "AcnDataImporter,DundeeCsvImporter,StationLocationImporter")
add(f"{SIMJ}/generator", "SessionGenerator,DistributionModel,TariffAssigner,GstinFactory")
add(f"{SIMJ}/chaos",
    "ChaosInjector,DuplicateFault,LateArrivalFault,ClockSkewFault,NegativeEnergyFault,"
    "MidSessionTariffChangeFault,CreditCdrFault")
add(f"{SIMJ}/cpo", "CpoSimulator,OcpiPushClient")
add(f"{SIMJ}/irp", "MockIrpController,IrnHasher")
add(f"{SIM}/src/main/resources", "application.yml")
add(f"{SIM}/src/main/resources/seed", "operators.yml,distributions.yml")
add(f"{SIM}/src/main/resources/scenarios",
    "happy-path.yml,duplicate-storm.yml,late-and-skewed.yml,dispute-heavy.yml")
add(f"{SIM}/src/test/java/com/voltreckon/simulator", "SessionGeneratorDeterminismTest")

# --------------------------------------------------------------------------- #
# Frontend: Vite + React + TypeScript
# --------------------------------------------------------------------------- #
add(FE, "package.json,index.html,vite.config.ts,tsconfig.json,tsconfig.node.json,eslint.config.js,"
        ".prettierrc,.env.example,playwright.config.ts")
add(f"{FE}/public", "favicon.svg")
add(f"{FE}/e2e", "auth.spec.ts,settlement-flow.spec.ts")
S = f"{FE}/src"
add(S, "main.tsx")
add(f"{S}/app", "App.tsx,router.tsx,providers.tsx,ProtectedRoute.tsx,queryClient.ts")
add(f"{S}/api", "schema.d.ts,client.ts,errors.ts")
F = f"{S}/features"
add(f"{F}/auth", "authStore.ts,index.ts")
add(f"{F}/auth/pages", "LoginPage.tsx")
add(f"{F}/auth/hooks", "useAuth.ts")
add(f"{F}/dashboard/pages", "DashboardPage.tsx")
add(f"{F}/dashboard/components", "KpiCards.tsx,SettlementTrendChart.tsx")
add(f"{F}/partners/pages", "PartnerListPage.tsx,PartnerDetailPage.tsx")
add(f"{F}/partners/components", "AgreementForm.tsx")
add(f"{F}/ingestion/pages", "UploadCdrPage.tsx,IngestionStatusPage.tsx,QuarantinePage.tsx")
add(f"{F}/tariffs/pages", "TariffListPage.tsx")
add(f"{F}/tariffs/components", "TariffTimeline.tsx")
add(f"{F}/ledger/pages", "AccountsPage.tsx,JournalPage.tsx,TrialBalancePage.tsx")
add(f"{F}/invoices", "invoices.module.css,index.ts")
add(f"{F}/invoices/api", "useInvoices.ts")
add(f"{F}/invoices/components", "InvoiceTable.tsx,GstBreakupCard.tsx,CreditNoteDialog.tsx")
add(f"{F}/invoices/pages", "InvoiceListPage.tsx,InvoiceDetailPage.tsx")
add(f"{F}/disputes/pages", "DisputeQueuePage.tsx,DisputeDetailPage.tsx")
add(f"{F}/disputes/components", "EvidenceUploader.tsx")
add(f"{F}/settlement/pages", "NettingPreviewPage.tsx,ApprovalQueuePage.tsx,StatementPage.tsx")
add(f"{F}/reconciliation/pages", "ReconciliationPage.tsx")
add(f"{F}/reconciliation/components", "DiscrepancyTable.tsx")
add(f"{F}/audit/pages", "AuditTrailPage.tsx")
add(f"{F}/audit/components", "SessionTimeline.tsx")
add(f"{S}/components/ui",
    "Button.tsx,Button.module.css,DataTable.tsx,DataTable.module.css,Modal.tsx,Modal.module.css,"
    "StatusBadge.tsx,StatusBadge.module.css,MoneyText.tsx,Toast.tsx,Toast.module.css")
add(f"{S}/components/layout",
    "AppShell.tsx,AppShell.module.css,Sidebar.tsx,Sidebar.module.css,Topbar.tsx,Topbar.module.css")
add(f"{S}/components/feedback", "ErrorBoundary.tsx,EmptyState.tsx,Spinner.tsx,Spinner.module.css")
add(f"{S}/hooks", "usePagination.ts,useDebounce.ts")
add(f"{S}/lib", "money.ts,date.ts,gst.ts,format.ts")
add(f"{S}/styles", "tokens.css,reset.css,global.css")
add(f"{S}/test", "setup.ts,renderWithProviders.tsx")
add(f"{S}/test/mocks", "handlers.ts,server.ts")

# --------------------------------------------------------------------------- #
# Content generation
# --------------------------------------------------------------------------- #
POM_NS = ('xmlns="http://maven.apache.org/POM/4.0.0" '
          'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
          'xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 '
          'https://maven.apache.org/xsd/maven-4.0.0.xsd"')

INTERFACES = {"BlobStore", "IrpClient", "ValidationRule", "DomainEvent"}
RECORDS = {"CdrAccepted", "CdrRejected", "TransactionPosted", "InvoiceIssued", "DisputeOpened",
           "DisputeResolved", "SettlementApproved", "PriceBreakdown", "PartyRef", "CountryCode",
           "IdempotencyKey", "Money"}
ENUMS = {"AccountType", "PartyRole", "Role", "ErrorCode"}
ENUM_SUFFIXES = ("Status", "State", "Reason", "StatusCode")
TEST_SUFFIXES = ("Test", "Tests", "IT", "Properties")


def pom(rel):
    parent = ('  <modelVersion>4.0.0</modelVersion>\n')
    if rel.as_posix() == "backend/pom.xml":
        return (f'<?xml version="1.0" encoding="UTF-8"?>\n<project {POM_NS}>\n{parent}'
                '  <groupId>com.voltreckon</groupId>\n  <artifactId>voltreckon-parent</artifactId>\n'
                '  <version>0.1.0-SNAPSHOT</version>\n  <packaging>pom</packaging>\n'
                '  <name>VoltReckon</name>\n\n  <modules>\n'
                '    <module>voltreckon-ocpi-model</module>\n    <module>voltreckon-app</module>\n'
                '    <module>voltreckon-simulator</module>\n  </modules>\n\n  <properties>\n'
                '    <!-- Use the JDK you have installed (21 or 25). -->\n'
                '    <maven.compiler.release>21</maven.compiler.release>\n'
                '    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>\n'
                '  </properties>\n\n'
                '  <!-- TODO: import the Spring Boot BOM in dependencyManagement (check spring.io for the\n'
                '       current 4.x version), then pin plugins: surefire, failsafe, jacoco, checkstyle,\n'
                '       spotbugs, flyway, spring-boot-maven-plugin. -->\n</project>\n')
    artifact = rel.parent.name
    deps = ""
    if artifact != "voltreckon-ocpi-model":
        deps = ('\n  <dependencies>\n    <dependency>\n      <groupId>com.voltreckon</groupId>\n'
                '      <artifactId>voltreckon-ocpi-model</artifactId>\n'
                '      <version>${project.version}</version>\n    </dependency>\n  </dependencies>\n')
    return (f'<?xml version="1.0" encoding="UTF-8"?>\n<project {POM_NS}>\n{parent}'
            '  <parent>\n    <groupId>com.voltreckon</groupId>\n'
            '    <artifactId>voltreckon-parent</artifactId>\n    <version>0.1.0-SNAPSHOT</version>\n'
            '    <relativePath>../pom.xml</relativePath>\n  </parent>\n'
            f'  <artifactId>{artifact}</artifactId>\n  <packaging>jar</packaging>\n{deps}</project>\n')


def java(rel):
    parts = rel.parts
    pkg = ".".join(parts[parts.index("java") + 1:-1])
    name = rel.stem
    if name == "package-info":
        return f"/** Module `{parts[-2]}`: document its public API and allowed dependencies here. */\npackage {pkg};\n"
    if name in ("VoltReckonApplication", "SimulatorApplication"):
        return (f"package {pkg};\n\n// TODO: switch to @SpringBootApplication once the Spring Boot BOM and starters are in the pom.\n"
                f"public class {name} {{\n    public static void main(String[] args) {{\n    }}\n}}\n")
    if name.endswith(TEST_SUFFIXES):
        kind, body = "class", "{\n    // TODO\n}"
    elif name in INTERFACES or name.endswith("Api"):
        kind, body = "interface", "{\n}"
    elif name in RECORDS:
        kind, body = "record", "() {\n}"
    elif name in ENUMS or name.endswith(ENUM_SUFFIXES):
        kind, body = "enum", "{\n    ;\n}"
    else:
        kind, body = "class", "{\n}"
    return f"package {pkg};\n\npublic {kind} {name} {body}\n"


def tsx(rel):
    name = rel.stem
    if name[0].islower() and name != "main":
        return "export {};\n"   # non-component .tsx (router, providers, test helpers)
    if name == "main":
        return ("import { StrictMode } from 'react';\nimport { createRoot } from 'react-dom/client';\n"
                "import './styles/global.css';\nimport { App } from './app/App';\n\n"
                "createRoot(document.getElementById('root')!).render(\n  <StrictMode>\n    <App />\n"
                "  </StrictMode>,\n);\n")
    return f"export function {name}() {{\n  return <div>{name}</div>;\n}}\n"


def ts(rel):
    name = rel.stem
    if name.startswith("use"):
        return f"export function {name}() {{\n  // TODO\n}}\n"
    if name == "schema.d":
        return "// GENERATED by `npm run api:gen` from ../docs/api/openapi.yaml. Do not edit.\nexport {};\n"
    if name == "vite.config":
        return ("import { defineConfig } from 'vite';\nimport react from '@vitejs/plugin-react';\n\n"
                "export default defineConfig({\n  plugins: [react()],\n"
                "  server: { port: 5173, proxy: { '/api': 'http://localhost:8080' } },\n});\n")
    if name == "playwright.config":
        return ("import { defineConfig } from '@playwright/test';\n\n"
                "export default defineConfig({\n  testDir: './e2e',\n"
                "  use: { baseURL: 'http://localhost:5173' },\n});\n")
    return "export {};\n"


def yml(rel):
    n = rel.name
    if n == "dependabot.yml":
        return ('version: 2\nupdates:\n'
                '  - package-ecosystem: maven\n    directory: /backend\n    schedule: { interval: weekly }\n'
                '  - package-ecosystem: npm\n    directory: /frontend\n    schedule: { interval: weekly }\n'
                '  - package-ecosystem: github-actions\n    directory: /\n    schedule: { interval: weekly }\n')
    if n == "backend-ci.yml":
        return ('name: backend-ci\non:\n  push:\n    branches: [main]\n    paths: ["backend/**", ".github/workflows/backend-ci.yml"]\n'
                '  pull_request:\n    paths: ["backend/**", ".github/workflows/backend-ci.yml"]\n'
                'permissions:\n  contents: read\njobs:\n  verify:\n    runs-on: ubuntu-latest\n    steps:\n'
                '      - uses: actions/checkout@v4\n      - uses: actions/setup-java@v4\n        with:\n'
                '          distribution: temurin\n          java-version: "21"\n          cache: maven\n'
                '      - run: mvn -B -f backend/pom.xml verify\n')
    if n == "frontend-ci.yml":
        return ('name: frontend-ci\non:\n  push:\n    branches: [main]\n    paths: ["frontend/**", ".github/workflows/frontend-ci.yml"]\n'
                '  pull_request:\n    paths: ["frontend/**", ".github/workflows/frontend-ci.yml"]\n'
                'permissions:\n  contents: read\njobs:\n  check:\n    runs-on: ubuntu-latest\n'
                '    defaults:\n      run:\n        working-directory: frontend\n    steps:\n'
                '      - uses: actions/checkout@v4\n      - uses: actions/setup-node@v4\n        with:\n'
                '          node-version: "22"\n          cache: npm\n'
                '          cache-dependency-path: frontend/package-lock.json   # commit the lock file first\n'
                '      - run: npm ci\n      - run: npm run lint\n      - run: npm run build\n      - run: npm test\n')
    if n == "application.yml" and "voltreckon-app" in rel.as_posix():
        return "spring:\n  application:\n    name: voltreckon\n"
    if n == "application.yml":
        return "spring:\n  application:\n    name: voltreckon-simulator\n"
    return f"# TODO: {n}\n"


def other(rel):
    n, s = rel.name, rel.suffix
    if n == "pom.xml":
        return pom(rel)
    if n == "checkstyle.xml":
        return ('<?xml version="1.0"?>\n<!DOCTYPE module PUBLIC "-//Checkstyle//DTD Checkstyle Configuration 1.3//EN"\n'
                '  "https://checkstyle.org/dtds/configuration_1_3.dtd">\n<module name="Checker">\n'
                '  <module name="TreeWalker"/>\n</module>\n')
    if n == "exclude.xml":
        return '<?xml version="1.0" encoding="UTF-8"?>\n<FindBugsFilter>\n</FindBugsFilter>\n'
    if n == "logback-spring.xml":
        return ('<?xml version="1.0" encoding="UTF-8"?>\n<configuration>\n'
                '  <include resource="org/springframework/boot/logging/logback/defaults.xml"/>\n'
                '  <include resource="org/springframework/boot/logging/logback/console-appender.xml"/>\n'
                '  <root level="INFO">\n    <appender-ref ref="CONSOLE"/>\n  </root>\n</configuration>\n')
    if n == "maven.config":
        return "--no-transfer-progress\n"
    if n == "jvm.config":
        return "-Xmx1g\n"
    if n == "package.json":
        return ('{\n  "name": "voltreckon-frontend",\n  "private": true,\n  "version": "0.1.0",\n  "type": "module",\n'
                '  "scripts": {\n    "dev": "vite",\n    "build": "tsc -b && vite build",\n    "preview": "vite preview",\n'
                '    "lint": "eslint .",\n    "test": "vitest run",\n    "e2e": "playwright test",\n'
                '    "api:gen": "openapi-typescript ../docs/api/openapi.yaml -o src/api/schema.d.ts"\n  }\n}\n')
    if n == "tsconfig.json":
        return ('{\n  "compilerOptions": {\n    "target": "ES2022",\n    "lib": ["ES2022", "DOM", "DOM.Iterable"],\n'
                '    "module": "ESNext",\n    "moduleResolution": "bundler",\n    "jsx": "react-jsx",\n'
                '    "strict": true,\n    "noUncheckedIndexedAccess": true,\n    "skipLibCheck": true,\n'
                '    "isolatedModules": true,\n    "noEmit": true,\n    "types": ["vite/client"]\n  },\n'
                '  "include": ["src"]\n}\n')
    if n == "tsconfig.node.json":
        return ('{\n  "compilerOptions": {\n    "target": "ES2022",\n    "module": "ESNext",\n'
                '    "moduleResolution": "bundler",\n    "skipLibCheck": true,\n    "noEmit": true\n  },\n'
                '  "include": ["vite.config.ts", "playwright.config.ts"]\n}\n')
    if n == "eslint.config.js":
        return "// TODO: add typescript-eslint + react-hooks rules after `npm install`.\nexport default [];\n"
    if n == ".prettierrc":
        return '{\n  "singleQuote": true,\n  "semi": true,\n  "printWidth": 100\n}\n'
    if n == ".env.example":
        return "VITE_API_BASE_URL=http://localhost:8080\n"
    if n == "index.html":
        return ('<!doctype html>\n<html lang="en">\n  <head>\n    <meta charset="UTF-8" />\n'
                '    <link rel="icon" type="image/svg+xml" href="/favicon.svg" />\n'
                '    <meta name="viewport" content="width=device-width, initial-scale=1.0" />\n'
                '    <title>VoltReckon</title>\n  </head>\n  <body>\n    <div id="root"></div>\n'
                '    <script type="module" src="/src/main.tsx"></script>\n  </body>\n</html>\n')
    if n == "invoice.html":
        return ('<!DOCTYPE html>\n<html xmlns:th="http://www.thymeleaf.org">\n<head>\n  <meta charset="UTF-8"/>\n'
                '  <title>Tax Invoice</title>\n  <link rel="stylesheet" href="invoice.css"/>\n</head>\n'
                '<body>\n  <!-- TODO: seller/buyer GSTIN, place of supply, line items, CGST/SGST/IGST, IRN + QR -->\n'
                '</body>\n</html>\n')
    if n == "favicon.svg":
        return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
                '<path d="M13 2 4 14h6l-1 8 9-12h-6z" fill="#f5b400"/></svg>\n')
    if n == "tokens.css":
        return (":root {\n  --color-bg: #ffffff;\n  --color-fg: #14171f;\n  --color-accent: #f5b400;\n"
                "  --radius: 8px;\n  --space: 8px;\n}\n")
    if n == "global.css":
        return "@import './tokens.css';\n@import './reset.css';\n\nbody {\n  background: var(--color-bg);\n  color: var(--color-fg);\n}\n"
    if n == "reset.css":
        return "*,\n*::before,\n*::after {\n  box-sizing: border-box;\n}\n\nbody {\n  margin: 0;\n}\n"
    if s == ".css" and n.endswith(".module.css"):
        return ".root {\n}\n"
    if s == ".css":
        return f"/* TODO: {n} */\n"
    if s == ".sql":
        return f"-- {n}\n-- TODO: derive from docs/database/schema.sql (keep one module's tables per file).\n"
    if s == ".json":
        return '{\n  "title": "%s",\n  "panels": []\n}\n' % rel.stem
    if n == "gst-state-codes.csv":
        return "code,name\n"
    if n == "README.md" and rel.parent.name == "data":
        return ("# data/\n\nPublic datasets used only to shape the synthetic CDR generator.\n\n"
                "- `raw/` is git-ignored. Download here: ACN-Data, Dundee public charging, Ministry of Power station list.\n"
                "- Check each dataset's licence before use and record it below.\n"
                "- `processed/` holds small derived samples that are safe to commit.\n\n"
                "| Dataset | Source URL | Licence / terms | Downloaded on |\n|---|---|---|---|\n")
    if n.endswith((".ps1", ".sh")):
        return ("#!/usr/bin/env bash\n" if n.endswith(".sh") else "") + f"# TODO: {n}\n"
    if n == ".gitkeep":
        return ""
    return f"# TODO: {n}\n"


def content(rel):
    s = rel.suffix
    if s == ".java":
        return java(rel)
    if s == ".tsx":
        return tsx(rel)
    if s == ".ts":
        return ts(rel)
    if s in (".yml", ".yaml"):
        return yml(rel)
    return other(rel)


GITIGNORE_LINES = ["backend/**/target/", "frontend/node_modules/", "frontend/dist/",
                   "data/raw/*", "!data/raw/.gitkeep", ".env"]


def main():
    ap = argparse.ArgumentParser(description="Create the VoltReckon project skeleton (never overwrites).")
    ap.add_argument("--root", default=".", help="repo root (default: current directory)")
    ap.add_argument("--dry-run", action="store_true", help="show what would be created, write nothing")
    ap.add_argument("--force", action="store_true", help="skip the repo-root sanity check")
    args = ap.parse_args()

    root = Path(args.root).resolve()
    if not args.force and not ((root / "docs").is_dir() or (root / ".git").exists()):
        sys.exit(f"{root} does not look like the VoltReckon repo (no docs/ or .git). "
                 "cd into it or pass --root (or --force).")

    created = skipped = 0
    for directory, names in SPEC:
        for raw in names:
            name = raw if "." in raw.rsplit("/", 1)[-1] else raw + ".java"
            rel = Path(directory) / name
            target = root / rel
            if target.exists():
                skipped += 1
                continue
            created += 1
            if args.dry_run:
                print(f"  would create  {rel.as_posix()}")
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(content(rel), encoding="utf-8", newline="\n")

    added = []
    gi = root / ".gitignore"
    if not args.dry_run:
        existing = gi.read_text(encoding="utf-8").splitlines() if gi.exists() else []
        missing = [l for l in GITIGNORE_LINES if l not in (x.strip() for x in existing)]
        if missing:
            with gi.open("a", encoding="utf-8", newline="\n") as fh:
                fh.write(("\n" if existing and existing[-1] != "" else "") + "# VoltReckon scaffold\n" +
                         "\n".join(missing) + "\n")
            added = missing

    verb = "would create" if args.dry_run else "created"
    print(f"\nDone: {verb} {created} files, skipped {skipped} that already exist.")
    if added:
        print(f".gitignore: appended {len(added)} line(s).")
    print("\nNext steps:")
    print("  1. cd backend; mvn wrapper:wrapper        # generates mvnw / mvnw.cmd")
    print("  2. mvn -f backend/pom.xml validate        # checks the multi-module wiring")
    print("  3. cd frontend; npm install react react-dom react-router-dom @tanstack/react-query zod")
    print("     npm install -D vite @vitejs/plugin-react typescript vitest @playwright/test "
          "openapi-typescript eslint prettier @types/react @types/react-dom")


if __name__ == "__main__":
    main()