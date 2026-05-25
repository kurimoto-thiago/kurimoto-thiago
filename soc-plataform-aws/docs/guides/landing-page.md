# 🌐 Landing Page Pessoal — Guia Completo

Site pessoal para amplificar o portfólio do SOC Platform.

## Stack recomendada

| Camada | Tecnologia | Motivo |
|--------|------------|--------|
| Framework | **Astro 4** | SSG ultrarrápido, ótimo SEO |
| Estilo | **TailwindCSS** | Consistente com o dashboard SOC |
| Hospedagem | **Cloudflare Pages** ou Vercel | Free tier generoso |
| CDN | Cloudflare | Performance global |
| Analytics | Plausible / Umami | Privacy-first, sem cookies |
| Domínio | `seunome.dev` ou `.cloud` | ~US$ 15/ano (Namecheap, Cloudflare) |

## Arquitetura visual

**Tema:** dark (combina com SOC), cyan/slate, monospace para detalhes técnicos.
**Fontes:** JetBrains Mono (display/code) + Inter (body) — distintivas, técnicas.
**Inspiração:** terminal moderno, Material Design 3, alguns toques retrô (CRT scanlines opcional).

## Estrutura one-page

### 1. Hero (acima da dobra)

```
┌──────────────────────────────────────────────┐
│  $ whoami                                    │
│  > Thiago Kurimoto                           │
│  > Cloud & Security Engineer                 │
│  > 25y industry · 4y education · MSc student │
│                                              │
│  [Ver o SOC ao vivo]  [LinkedIn]  [GitHub]   │
└──────────────────────────────────────────────┘
```

Elementos:
- Terminal animado com efeito de digitação
- Status pill: "🟢 Disponível para oportunidades remotas"
- CTA primário: link para soc.seudominio.dev

### 2. Sobre

Três parágrafos curtos:
- **Quem sou** — instrutor + engenheiro
- **O que faço** — cloud, segurança, observabilidade
- **O que busco** — posições Cloud Engineer / SRE / Security Engineer

### 3. Projeto destaque

Card grande com:
- Screenshot real do Grafana
- Stack em ícones
- Métricas: "30d uptime · 99.95%", "MTTR 12min", "12k events/day"
- Botões: Ver demo | Ver código | Ler artigo

### 4. Stack visual

Grid de ícones com proficiência (★★★★★):
- AWS · Kubernetes · Terraform · Linux · Docker · Python · Node.js · Wazuh · Prometheus · Grafana · Ansible · GitHub Actions

### 5. Experiência (timeline vertical)

```
2022 — Hoje   SENAI SP             Instrutor Cyber/IA/Cloud
2018 — 2022   [Empresa]            Cloud/Infra Engineer
2010 — 2018   [Empresa]            SysAdmin/Networking
...
```

### 6. Pesquisa acadêmica

- UFABC PPG-INF mestrando
- Tema: P4 + ML-IDS para IoT
- Orientador: Prof. Kleinschmidt
- Link para repositório do tema

### 7. Conteúdo

Cards com ebooks e artigos:
- 📘 AWS Well-Architected Brazilian Guide
- 📗 Prometheus & Grafana: Zero to Specialist
- ✍️ Artigos técnicos

### 8. Contato

- Email com mailto:
- LinkedIn, GitHub, Lattes
- Formulário (Formspree gratuito) opcional

### 9. Footer

- Copyright
- Link para fonte do próprio site no GitHub (mostrar transparência)
- Última atualização (commit SHA)

## Diferenciais visuais

- **Live status** — fetch da API do SOC mostrando uptime real
- **Modo PT-BR / EN** — toggle de idioma
- **Custom cursor** — sutil, técnico
- **Easter egg** — `Ctrl+`` abre terminal interativo (com `whoami`, `cat resume.txt`, `nmap localhost`)
- **CV download** — PDF gerado dinamicamente

## SEO

- `<title>Thiago Kurimoto — Cloud & Security Engineer</title>`
- Meta description com palavras-chave Guppy
- Schema.org Person
- Open Graph image gerada por API (vercel/og)
- sitemap.xml automático (Astro)
- robots.txt permitindo indexação

## Performance

Targets:
- Lighthouse 100/100/100/100
- LCP < 1.2s
- Bundle JS < 50KB (Astro Islands)
- Imagens otimizadas em AVIF/WebP

## Estrutura de arquivos

```
seunome-dev/
├── astro.config.mjs
├── tailwind.config.mjs
├── package.json
├── public/
│   ├── og.png
│   ├── cv-thiago-kurimoto.pdf
│   └── favicon.svg
├── src/
│   ├── components/
│   │   ├── Hero.astro
│   │   ├── Terminal.astro
│   │   ├── ProjectCard.astro
│   │   ├── Timeline.astro
│   │   ├── StackGrid.astro
│   │   └── ContactForm.astro
│   ├── content/
│   │   ├── projects.json
│   │   ├── experience.json
│   │   └── articles/
│   ├── layouts/
│   │   └── Base.astro
│   ├── pages/
│   │   ├── index.astro
│   │   ├── pt.astro
│   │   ├── en.astro
│   │   └── api/
│   │       └── soc-status.ts
│   └── styles/
│       └── global.css
└── README.md
```

## Deploy

```bash
# Cloudflare Pages
npm create astro@latest seunome-dev
cd seunome-dev
npm install -D @astrojs/tailwind tailwindcss
# build local
npm run build
# Conectar ao GitHub e deploy automático no Cloudflare Pages
```

## Custo total

| Item | Custo/ano |
|------|-----------|
| Domínio `.dev` | $12 |
| Hospedagem Cloudflare | $0 (free tier) |
| Email profissional (Zoho) | $0 |
| Analytics (Umami self-hosted) | $0 |
| **Total** | **~$12/ano** |

## Roadmap

- v1: Static one-page (lançamento)
- v2: Blog em MDX (artigos)
- v3: Galeria de projetos com filtros
- v4: API pública mostrando métricas live do SOC
- v5: Dashboard interativo embed via iframe seguro
