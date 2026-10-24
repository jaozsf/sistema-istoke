# StockIQ — FastAPI + PostgreSQL + Firebase + Flutter

ERP para fábricas e distribuidoras de copos: estoque, pedidos (vendedor →
produção → expedição → distribuidora), financeiro e IA, num app só para
iPhone, Android, web e desktop.

**Versão 1.1.0** · App web e API no mesmo endereço:
`https://backend-livid-one-99.vercel.app` (API em `/api/v1`, docs em `/docs`) · Dossiê completo do sistema (arquitetura, segurança,
testes, guias de usuário, implantação e planejamento):
[`docs/dossie/DOSSIE_STOCKIQ.md`](docs/dossie/DOSSIE_STOCKIQ.md)

O repositório tem dois projetos: `backend/` (API Python) e
`stockiq-flutter/` (app Flutter/Dart).

---

## Stack

| Camada | Tecnologia |
|---|---|
| API | FastAPI 0.115 (Python 3.12) |
| Banco | PostgreSQL 16 (Neon em produção) + SQLAlchemy 2 async + asyncpg |
| Migrações | Alembic (o servidor também cria tabelas novas na subida) |
| Auth | Firebase Auth (e-mail/senha + Google) + JWT interno de 7 dias, renovado sozinho pelo app |
| Push | Firebase Cloud Messaging |
| IA | Respostas prontas com dados reais + Anthropic Claude opcional |
| Relatórios | reportlab + qrcode + Pillow (PDF executivo, etiquetas QR) |
| App | Flutter 3.41 / Dart 3.11, Riverpod, go_router, Dio — visual iOS, paleta Lagoon |
| Hospedagem | Vercel (serverless) |
| Testes | pytest, flutter_test |

---

## Estrutura

```
backend/
├── app/
│   ├── core/          config (normaliza URL da Neon), banco, Firebase, JWT + RBAC, fuso BR
│   ├── models/        Company, Branch, User, Product, Stock, Movement, Finance, Log,
│   │                  DeviceToken, BoxStandard, Distributor, Customer, Order(+Item, Event)
│   ├── schemas/       Pydantic v2
│   ├── repositories/  acesso ao banco
│   ├── services/      regras: estoque, financeiro, pedidos/logística, push, auth
│   ├── controllers/   rotas HTTP (logistics_controller = pedidos, caixas, clientes, distribuidoras)
│   ├── ai/  reports/
├── alembic/versions/  0001 inicial · 0002 push · 0003 pedidos e setores
├── tests/             test_products.py, test_orders.py
├── requirements.txt       runtime (o que a Vercel instala — manter enxuto)
└── requirements-dev.txt   + pytest, alembic, aiosqlite, psycopg2

stockiq-flutter/lib/
├── core/       tema Lagoon, rotas por setor, providers, API + renovação de sessão,
│               aviso de atualização (update_service.dart)
├── features/   auth, dashboard, products, stock, qr, orders, admin, team,
│               ai_assistant, notifications, errors (404)
└── shared/     modelos e componentes (ios_widgets.dart: lista agrupada, título grande, caixa 3D)
```

---

## Perfis (RBAC)

| Role | Setor | Pode |
|---|---|---|
| `admin` | Dono | Tudo, incluindo equipe, padrões de caixa e distribuidoras |
| `manager` | Gerente | Operação inteira (pedidos, estoque, produtos, painel, IA); avança/cancela qualquer pedido |
| `seller` | Vendedor | Clientes e pedidos próprios; escolhe a distribuidora com o cliente |
| `production` | Produção | Fila de pedidos com arte/borda; iniciar produção e enviar para separação |
| `shipping` | Expedição | Separação, conferência caixa a caixa, despacho com NF |
| `operator` | Operador | Produtos, estoque e QR |

O app só mostra as abas de cada setor; a permissão de verdade é checada na API.

## Fluxo do pedido

```
enviado ──(com arte/borda)──► em_producao ──► em_separacao ──► conferido ──► despachado
   └────────(sem arte/borda)──────────────────────┘     ▲            │
                                                         └─ reabrir ──┘
cancelado: gerente/admin em qualquer etapa aberta; vendedor só em "enviado"
```

- O vendedor pede **em caixas**; o padrão de caixa do modelo converte em unidades.
- O estoque baixa quando o pedido sai de `enviado` (com receita e custo no financeiro);
  cancelar devolve o estoque e estorna o financeiro.
- `conferido` só libera quando todas as caixas foram contadas; `despachado` exige distribuidora.
- Cada mudança grava um evento (quem, de qual etapa para qual) e manda push ao próximo setor.

---

## Backend — local com Docker Compose

```bash
git clone https://github.com/jaozsf/sistema-istoke.git
cd sistema-istoke/backend
cp .env.example .env        # edite SECRET_KEY e FIREBASE_PROJECT_ID
# salve a chave da conta de serviço do Firebase como backend/firebase-credentials.json
docker compose up -d --build
# API: http://localhost:8010/docs (porta mapeada no docker-compose.yml)
```

Seed opcional: edite `FIREBASE_UID`/`USER_EMAIL` em `seed.py` e rode
`docker compose exec api python seed.py`.

## Backend — local sem Docker

```bash
cd backend
python -m venv venv && source venv/bin/activate   # Windows: venv\Scripts\activate
pip install -r requirements-dev.txt
cp .env.example .env    # DATABASE_URL apontando pro seu Postgres
alembic upgrade head
uvicorn app.main:app --reload
```

## Produção (Vercel + Neon) — web e API no mesmo projeto

```bash
./scripts/publicar.sh            # build web → backend/public + vercel --prod
./scripts/publicar.sh preview    # deploy de teste
./scripts/publicar.sh apk        # APK Android de release
```

`backend/vercel.json` manda `/api/*`, `/health`, `/docs` para a API (Python)
e todo o resto para o app web estático em `backend/public/` (gerado, fora do
Git). A API exclui `public/` do pacote Python para não inflar o cold start.
Como app e API ficam na mesma origem, o navegador não precisa de CORS.

Variáveis em Vercel → Settings → Environment Variables:

| Variável | Obrigatória | Observação |
|---|---|---|
| `DATABASE_URL` | Sim | Pode colar a URL da Neon como vem (`postgresql://...?sslmode=require`) — o código converte para asyncpg e desliga o cache de comandos no pooler |
| `SECRET_KEY` | Sim | Mesma em todas as instâncias |
| `FIREBASE_CREDENTIALS_JSON` | Sim | Conteúdo inteiro do JSON da conta de serviço |
| `ALLOWED_ORIGINS` | Web | JSON (`["https://..."]`) ou lista separada por vírgula |
| `DEBUG` | Não | `False` em produção |
| `ANTHROPIC_API_KEY` / `ANTHROPIC_MODEL` | Não | Assistente de IA para perguntas livres |

Saúde: `GET /health` (app) e `GET /health/db` (banco).

---

## App Flutter

```bash
cd stockiq-flutter
flutter pub get
flutter run -d chrome        # ou android / ios / windows
```

- Firebase próprio: `dart pub global activate flutterfire_cli && flutterfire configure`.
- API: `lib/core/constants/app_constants.dart` → `baseUrl` (padrão: produção na Vercel).
- Builds: `flutter build web` · `flutter build apk --release` · `flutter build ipa` (Mac).
- O APK de release ainda é assinado com a chave de debug — para a Play Store, configure uma chave própria em `android/app/build.gradle`.

### Lançar uma atualização

1. Suba `appVersion` e escreva as novidades em `whatsNew` (`lib/core/services/update_service.dart`).
2. Coloque o mesmo número em `version:` no `pubspec.yaml`.
3. Ao abrir, o usuário vê "Olá, temos uma nova atualização para você :)". Na web, o app compara com o `version.json` publicado e oferece **Atualizar agora**.

---

## Endpoints principais (`/api/v1`)

| Grupo | Rotas |
|---|---|
| Auth | `POST /auth/login` (token Firebase → JWT; primeiro login desconhecido cria empresa nova e vira admin) |
| Usuários | `GET /users/me`, `GET/POST /users`, `PATCH/DELETE /users/{id}` |
| Empresas/filiais | `/companies`, `/companies/{id}/branches` |
| Produtos | `/products`, `/products/{id}/qr`, `/products/qr-labels/pdf`, `/products/scan/{qr}` (lista: `?limit=` até 500) |
| Estoque | `/stock/low`, `/branches/{id}/stock`, `POST /movements`, `PUT /branches/{b}/stock/{p}/adjust` |
| Financeiro | `/finance/summary?days=1`, `/finance?days=30` |
| Padrões de caixa | `GET /box-standards`, `PUT/DELETE /box-standards/{product_id}` (admin) |
| Distribuidoras | `GET/POST /distributors`, `PUT/DELETE /distributors/{id}` (admin) |
| Clientes | `GET/POST /customers`, `PUT /customers/{id}` (vendedor/gerente) |
| Pedidos | `GET /orders?status=abertos`, `GET /orders/summary`, `POST /orders`, `GET/PATCH /orders/{id}` |
| Etapas | `POST /orders/{id}/transition`, `PUT /orders/{id}/items/{item_id}/check` |
| IA / análises | `POST /ai/ask`, `/analytics/report/pdf` |

---

## Testes

```bash
cd backend && pip install -r requirements-dev.txt && pytest tests -v   # 10 testes
cd stockiq-flutter && flutter test && flutter analyze                   # 13 testes
```

Teste de carga em produção (24/10/2026): 6.750 requisições até 300 simultâneas,
0 erros. Detalhes no dossiê, seção 12.

---

## Solução de problemas

| Sintoma | Causa provável | Correção |
|---|---|---|
| App desloga depois de um tempo fechado | Versão antiga do app (sem renovação de sessão) | Atualizar para 1.1.0+ |
| Primeira tela demora alguns segundos | Cold start da Vercel / Neon dormindo | Normal; o app tenta de novo sozinho |
| "Produto sem padrão de caixa" ao criar pedido | Modelo sem padrão cadastrado | Admin: Gestão → Padrões de caixa |
| "Pedido com arte/borda passa pela produção primeiro" | Expedição tentou pular a produção | Produção inicia o pedido |
| "Confira todas as caixas antes de finalizar" | Conferência incompleta | Ajustar a contagem de cada item |
| Login dá erro de CORS no navegador | Origem fora de `ALLOWED_ORIGINS` | Adicionar a origem e redeployar |
| Container `stockiq_api` não sobe (mount de `firebase-credentials.json`) | Arquivo fora de `backend/` | Colocar o arquivo em `backend/` |
| Tela cinza em build release | Exceção no `build()` de algum widget | Rodar com `flutter run` para ver o erro |

---

## Próximos passos

- [x] Pedidos com produção, separação, conferência e despacho
- [x] Padrão de caixa, distribuidoras, clientes, setores
- [x] Visual iOS (claro/escuro), sessão persistente, aviso de atualização, 404
- [x] API estável na Vercel + teste de carga
- [x] App web publicado junto da API
- [ ] APK com chave de release; TestFlight
- [ ] Paginação acima de 500 produtos; rate limit na API
- [ ] QR Code na conferência; etiqueta de volume da carga
- [ ] Tela de previsão de demanda (`/analytics/forecast` já existe)
