.PHONY: help fmt validate scan test docs

help:
	@echo "make fmt       - Format all .tf files"
	@echo "make validate  - Validate all modules"
	@echo "make scan      - Run checkov + tfsec"
	@echo "make test      - Run Terratest"
	@echo "make docs      - Generate module docs (terraform-docs)"

fmt:
	terraform fmt -recursive

validate:
	@for d in modules/*/; do \
		echo "→ Validating $$d"; \
		cd $$d && terraform init -backend=false -upgrade && terraform validate && cd ../..; \
	done

scan:
	checkov -d modules/ --framework terraform --quiet
	tfsec modules/

test:
	cd test && go test -v -timeout 30m ./...

docs:
	@for d in modules/*/; do \
		terraform-docs markdown table --output-file README.md $$d; \
	done
