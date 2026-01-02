.PHONY: help test lint test-unit test-env-vars test-schema test-all docs install clean

# Default target
help:
	@echo "Heimdall Helm Chart - Available targets:"
	@echo ""
	@echo "  make test           - Run all tests (lint, unit, env-vars, schema)"
	@echo "  make lint           - Run Helm chart linting"
	@echo "  make test-unit      - Run Helm unit tests"
	@echo "  make test-env-vars  - Run environment variable validation"
	@echo "  make test-schema    - Run values schema validation"
	@echo "  make test-all       - Run complete test suite (includes integration)"
	@echo "  make docs           - Start documentation development server"
	@echo "  make install        - Install chart to local cluster"
	@echo "  make clean          - Clean generated files"
	@echo ""

# Run fast tests (lint, unit, env-vars, schema)
test: lint test-unit test-env-vars test-schema
	@echo "✅ All fast tests passed!"

# Run complete test suite (includes integration tests)
test-all: test
	@echo "Running integration tests..."
	@echo "Note: Requires kind cluster. Run 'kind create cluster' first."
	ct install --config .github/ct.yaml

# Helm linting
lint:
	@echo "🔍 Linting Helm chart..."
	helm lint ./heimdall --strict
	@echo "✅ Lint passed!"

# Helm unit tests
test-unit:
	@echo "🧪 Running Helm unit tests..."
	@helm plugin list | grep -q unittest || { \
		echo "Installing helm-unittest plugin..."; \
		helm plugin install https://github.com/helm-unittest/helm-unittest --version=v1.0.3; \
	}
	helm unittest ./heimdall
	@echo "✅ Unit tests passed!"

# Environment variables validation
test-env-vars:
	@echo "🔍 Validating environment variables..."
	@command -v python3 >/dev/null 2>&1 || { echo "Error: python3 not found"; exit 1; }
	@python3 -c "import yaml" 2>/dev/null || { \
		echo "Installing PyYAML..."; \
		pip3 install pyyaml; \
	}
	python3 heimdall/tests/scripts/test_env_vars_schema_compliance.py
	python3 heimdall/tests/scripts/validate_env_vars_against_templates.py
	@echo "✅ Environment variable validation passed!"

# Schema validation
test-schema:
	@echo "🔍 Validating values schema..."
	@command -v helm >/dev/null 2>&1 || { echo "Error: helm not found"; exit 1; }
	helm dependency update ./heimdall
	helm template heimdall ./heimdall >/dev/null
	@echo "Testing invalid values are rejected..."
	@if helm template heimdall ./heimdall --set nodeEnv=invalid 2>&1 | grep -q "values don't meet the specifications"; then \
		echo "✅ Schema validation working correctly"; \
	else \
		echo "❌ Schema validation failed - should reject invalid nodeEnv"; \
		exit 1; \
	fi
	@echo "✅ Schema validation passed!"

# Start documentation development server
docs:
	@echo "📚 Starting documentation server..."
	cd docs && pnpm install && pnpm dev

# Install chart to local cluster
install:
	@echo "📦 Installing Heimdall chart..."
	@kubectl cluster-info >/dev/null 2>&1 || { echo "Error: No Kubernetes cluster found"; exit 1; }
	helm dependency update ./heimdall
	helm upgrade --install heimdall ./heimdall -n heimdall --create-namespace
	@echo "✅ Chart installed! Access with: kubectl port-forward -n heimdall svc/heimdall 8080:3000"

# Clean generated files
clean:
	@echo "🧹 Cleaning generated files..."
	rm -rf heimdall/charts/
	rm -f heimdall/Chart.lock
	rm -rf docs/.nuxt docs/.output docs/node_modules
	@echo "✅ Clean complete!"
