.PHONY: help check init plan apply destroy bootstrap port-forward seed lint test

help:
	@echo "SOC Platform AWS - Comandos disponíveis:"
	@echo "  check        Validar pré-requisitos"
	@echo "  init         terraform init"
	@echo "  plan         terraform plan (ENV=dev|prod)"
	@echo "  apply        terraform apply"
	@echo "  destroy      terraform destroy"
	@echo "  bootstrap    Instalar stack pós-Terraform"
	@echo "  port-forward Expor serviços localmente"
	@echo "  seed         Aplicar schema DB"
	@echo "  lint         Lint todos componentes"
	@echo "  test         Rodar testes"

ENV ?= dev

check:
	@./scripts/check-prereqs.sh

init:
	cd terraform && terraform init

plan:
	cd terraform && terraform plan -var-file=environments/$(ENV).tfvars -out=tfplan

apply:
	cd terraform && terraform apply tfplan

destroy:
	cd terraform && terraform destroy -var-file=environments/$(ENV).tfvars

bootstrap:
	@./scripts/bootstrap-cluster.sh

port-forward:
	@./scripts/port-forward.sh

seed:
	@./scripts/seed-database.sh

lint:
	cd terraform && terraform fmt -check -recursive
	cd backend && npm run lint
	cd frontend && npm run lint

test:
	cd backend && npm test
	cd frontend && npm test
