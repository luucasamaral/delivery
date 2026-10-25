# Mesa — SaaS para restaurantes

Fases 1 e 2 — fundação e gestão: monorepo pnpm/Turbo, três apps Next.js, API NestJS, PostgreSQL/Prisma, Redis, autenticação, isolamento multi-tenant e gestão de catálogo, unidades, equipe e restaurante. PDV, pedidos, cardápio público, cobranças e administração de planos pertencem às fases seguintes.

Leia [a arquitetura e os critérios de aceitação](docs/architecture.md), [a segurança](docs/security.md) e [a validação](docs/validation.md).

**Para testar neste Windows sem Docker:** execute `INICIAR-LOCAL.cmd`. O [guia local](docs/local-windows.md) explica os endereços, contas, recuperação de senha e o atalho para parar. Este modo mantém banco, Redis e e-mails de teste na própria máquina.

## Pré-requisitos

- Node.js 24 e pnpm 10.34.7 (`corepack enable` e `corepack prepare pnpm@10.34.7 --activate`).
- Docker Engine com Compose para PostgreSQL, Redis e Mailpit.
- Se não quiser instalar pnpm globalmente, substitua `pnpm` por `npm exec --yes --package=pnpm@10.34.7 -- pnpm`.

Execute os comandos a partir da raiz deste diretório.

## Inicialização local (PowerShell)

```powershell
Copy-Item .env.example .env
# Edite .env: defina SEED_PASSWORD (12+ caracteres) e as credenciais locais.
pnpm install --frozen-lockfile
docker compose --env-file .env -f infrastructure/docker/compose.yaml up -d
pnpm db:generate
pnpm db:migrate
pnpm db:seed
pnpm --filter @restaurant/database build
pnpm --filter @restaurant/types build
pnpm dev
```

No Linux/macOS, use `cp .env.example .env`. O `.env` está ignorado pelo Git. As credenciais no exemplo são exclusivamente locais. Não reutilize esse Compose como implantação de produção.

| Serviço | URL local |
| --- | --- |
| Restaurante | http://localhost:3000 |
| Administração | http://localhost:3001 |
| Cardápio (indisponível nesta fase) | http://localhost:3002 |
| API / OpenAPI | http://localhost:4000/docs |
| Saúde da API | http://localhost:4000/health/ready |
| E-mails de desenvolvimento | http://localhost:8025 |

O seed é explícito, idempotente e exclusivo de desenvolvimento. Cria `owner.a@example.test`, `owner.b@example.test` e `admin@example.test`, com a senha configurada em `SEED_PASSWORD`. As duas contas de proprietário pertencem a restaurantes diferentes. A conta da plataforma não possui acesso operacional aos restaurantes. O seed não altera senhas existentes nem renova trials em uma segunda execução.

Login → selecionar restaurante → Catálogo, Unidades, Equipe e Restaurante. O proprietário também consulta a assinatura. Recuperação de senha envia o link ao Mailpit; abra o link e defina uma nova senha. Logout revoga a sessão atual; “Encerrar todas as minhas sessões” revoga todas as sessões da conta. Entre nas contas A e B em perfis separados do navegador: cookies em localhost são compartilhados entre portas.

## Verificações

```powershell
pnpm db:validate
pnpm lint
pnpm typecheck
pnpm test
pnpm build
pnpm test:integration
```

O comando de integração compila `database`, `types` e `api` automaticamente. Ele inicia seu próprio PostgreSQL temporário, com senhas aleatórias, aplica as migrations reais e executa o seed duas vezes. Não se conecta ao banco configurado no `.env`. Os diretórios de teste ficam em `.local/` para diagnóstico; o servidor é encerrado ao fim da suíte. A suíte HTTP isola o rate limiter de Redis; isso **não valida Redis**. Consulte o relatório para os limites e os testes adicionais de infraestrutura.

## Aplicações também no Docker

Primeiro suba a infraestrutura, aplique migrations e execute o seed conforme acima. Depois:

```powershell
docker compose --env-file .env -f infrastructure/docker/compose.yaml --profile apps up -d --build
```

Os containers são locais e rodam sem root. O Dockerfile inicial prioriza reprodutibilidade; redução da imagem, pipeline, TLS e hardening pertencem à preparação para produção. Mudanças em `API_INTERNAL_URL` exigem novo build Next, pois as regras de encaminhamento são geradas no build. Não use `docker compose down -v` para reiniciar: isso remove os dados.

## Banco e migrations

- `DATABASE_URL`: role `restaurant_app`, sem superusuário, DDL ou BYPASSRLS.
- `MIGRATION_DATABASE_URL`: credencial administrativa, somente migrations/seed; nunca disponibilizar à API em produção.
- `init-role.sh` cria a role apenas na primeira inicialização do volume. Alterar uma senha no `.env` não altera uma role existente.
- Migrations versionadas em `packages/database/prisma/migrations`; aplicar com `prisma migrate deploy`.
- Novas alterações: `pnpm --filter @restaurant/database exec prisma migrate dev --name nome_da_alteracao`, com banco/shadow database locais apropriados. Revisar SQL, chaves e RLS.
- Adicionar tabela tenant exige política RLS e teste de isolamento. Não executar consultas operacionais diretamente pelo client global.

## Organização

`apps/api` contém identidade, tenancy, licenciamento e limite inicial da administração. `apps/{dashboard,admin,storefront}` contêm os shells web. `packages/database` contém schema, migrations, cliente e seed; `types` contém contratos Zod; `ui` compartilha interface e estilos; `config` compartilha TypeScript. `infrastructure` contém a configuração local; `docs` registra decisões e pendências.

A Fase 2 inclui cadastro e edição de unidades, equipe, perfil, categorias, produtos e adicionais. Consulte [decisões e validação](docs/phase2.md). A próxima etapa é a Fase 3, com cardápio público e pedidos; ela depende de autorização antes de começar.
