# Contribuindo

## Workflow

1. Fork e clone
2. Branch: `git checkout -b feat/nome`
3. Conventional Commits
4. PR para `main`

## Padrões

- `terraform fmt -recursive` antes do commit
- `make scan` deve passar (checkov, tfsec)
- Adicione exemplo se for novo módulo
- Atualize README do módulo
- Atualize CHANGELOG.md

## Adicionar módulo novo

```
modules/novo-modulo/
├── main.tf
├── variables.tf
├── outputs.tf
└── README.md
```

Use `terraform-docs` para gerar a tabela de inputs/outputs no README.
