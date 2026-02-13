.PHONY: help test test-unit test-integration test-integration-ci sandbox sandbox-reinstall sandbox-teardown lint

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

test: test-unit ## Run all local tests (unit only; integration needs DDEV)

test-unit: ## Run unit tests (no DDEV required)
	./tests/run-bats.sh

test-integration: ## Run integration tests (requires DDEV running)
	bats tests/integration

test-integration-ci: ## Run integration tests simulating CI conditions (no global gitconfig)
	@echo "Simulating CI: temporarily removing ~/.gitconfig..."
	@if [ -f "$$HOME/.gitconfig" ]; then \
		cp "$$HOME/.gitconfig" "$$HOME/.gitconfig.bak.ddev-claude-test"; \
		rm -f "$$HOME/.gitconfig"; \
		trap 'mv "$$HOME/.gitconfig.bak.ddev-claude-test" "$$HOME/.gitconfig" 2>/dev/null; echo "Restored ~/.gitconfig"' EXIT; \
		bats tests/integration; \
	else \
		echo "No ~/.gitconfig found, running tests as-is..."; \
		bats tests/integration; \
	fi

# ---------------------------------------------------------------------------
# Sandbox (local dev environment)
# ---------------------------------------------------------------------------

sandbox: ## Create sandbox DDEV project and install addon
	cd sandbox && bash setup.sh

sandbox-reinstall: ## Reinstall addon into existing sandbox after code changes
	cd sandbox && bash reinstall.sh

sandbox-teardown: ## Destroy sandbox DDEV project and clean files
	cd sandbox && bash teardown.sh

# ---------------------------------------------------------------------------
# Linting
# ---------------------------------------------------------------------------

lint: ## Check shell scripts for syntax errors
	@echo "Checking bash syntax..."
	@for f in claude/entrypoint.sh claude/healthcheck.sh claude/resolve-and-apply.sh \
	          claude/hooks/*.sh claude/scripts/*.sh \
	          sandbox/*.sh commands/host/*; do \
		bash -n "$$f" && printf '  %-50s OK\n' "$$f" || exit 1; \
	done
	@echo "All scripts pass syntax check."
