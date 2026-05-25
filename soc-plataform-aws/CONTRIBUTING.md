# Contribuindo

Obrigado pelo interesse! 🙏

## Setup local

```bash
git clone https://github.com/USER/soc-platform-aws
cd soc-platform-aws
./scripts/check-prereqs.sh
```

## Workflow

1. Fork
2. Branch: `git checkout -b feat/minha-feature` (Conventional Commits)
3. Commits assinados: `git commit -s -m "feat: ..."`
4. Push e abra PR

## Padrões

### Conventional Commits

- `feat:` nova feature
- `fix:` bug fix
- `docs:` documentação
- `refactor:` refactor sem mudança de comportamento
- `test:` testes
- `chore:` build, dependências
- `ci:` pipelines
- `security:` correções de segurança

### Code style

- Backend: ESLint (Airbnb base)
- Frontend: ESLint + Prettier
- Terraform: `terraform fmt`
- Shell: shellcheck

### Tests

- Backend: Jest, coverage > 80%
- Frontend: Vitest + Testing Library
- E2E: Playwright (em roadmap)

## Definition of Done

- [ ] Código revisado
- [ ] Testes passando
- [ ] Coverage mantido ou melhorado
- [ ] Docs atualizadas
- [ ] Sem secrets no diff
- [ ] CI verde

## Code of Conduct

Contributor Covenant 2.1. Seja respeitoso.
