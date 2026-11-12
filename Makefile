.PHONY: help db-up db-down db-reset db-shell schema docs-check openapi-lint verify

help:
	@echo "VoltReckon documentation blueprint"
	@echo ""
	@echo "  make db-up          Start PostgreSQL 18"
	@echo "  make db-down        Stop PostgreSQL"
	@echo "  make db-reset       Stop PostgreSQL and delete the volume (destructive)"
	@echo "  make db-shell       Open psql"
	@echo "  make schema         Apply docs/database/schema.sql to the local database"
	@echo "  make docs-check     Find TODO/TBD markers in documentation"
	@echo "  make openapi-lint   Validate docs/api/openapi.yaml with Redocly"
	@echo "  make verify         Run available checks"

db-up:
	docker compose up -d postgres
	docker compose ps

db-down:
	docker compose down

db-reset:
	docker compose down -v

db-shell:
	docker compose exec postgres psql -U voltreckon -d voltreckon

schema:
	docker compose exec -T postgres psql -U voltreckon -d voltreckon < docs/database/schema.sql

docs-check:
	@find docs -name '*.md' -print0 | xargs -0 grep -nE '(TODO|TBD)[[:space:]]*:' || true

openapi-lint:
	npx --yes @redocly/cli@latest lint docs/api/openapi.yaml --format=stylish

verify: docs-check openapi-lint
	@if [ -f backend/pom.xml ]; then cd backend && mvn verify; else echo "backend/pom.xml not present; skipping application build"; fi
