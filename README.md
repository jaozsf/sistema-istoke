# StockIQ Backend — FastAPI + PostgreSQL + Firebase

ERP SaaS com controle de estoque, financeiro e IA integrada.

---

## Stack

| Camada | Tecnologia |
|---|---|
| API | FastAPI 0.111 + Uvicorn |
| Banco | PostgreSQL 16 + SQLAlchemy 2 (async) |
| Migrações | Alembic |
| Auth | Firebase Auth + JWT interno (python-jose) |
| IA | Anthropic Claude (claude-sonnet-4) |
| QR Code | qrcode + Pillow |
| Container | Docker + Docker Compose |

---

## Estrutura

```
app/
├── core/          config, database, firebase, security (JWT + RBAC)
├── models/        ORM: Company, Branch, User, Product, Stock, Movement, Finance, Log
├── schemas/       Pydantic v2: request/response bodies
├── repositories/  Acesso ao banco (BaseRepository + específicos)
├── services/      Regras de negócio (auth, product, stock, company, user)
├── controllers/   Routers FastAPI (endpoints HTTP)
├── ai/            Assistente Claude com contexto real da empresa
└── utils/         seed.py, qr_code helpers
```

---

## Setup local (sem Docker)

### 1. Clone e ambiente

```bash
git clone <repo>
cd stockiq-backend
python -m venv venv
source venv/bin/activate          # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### 2. Configure o .env

```bash
cp .env.example .env
# Edite .env com suas credenciais reais
```

### 3. Firebase

1. Acesse [Firebase Console](https://console.firebase.google.com)
2. Configurações do projeto → Contas de serviço → Gerar nova chave privada
3. Salve como `firebase-credentials.json` na raiz do projeto

### 4. PostgreSQL

```bash
# Com Docker (recomendado):
docker run -d --name stockiq_db \
  -e POSTGRES_PASSWORD=senha \
  -e POSTGRES_DB=stockiq \
  -p 5432:5432 postgres:16-alpine
```

### 5. Migrações

```bash
alembic upgrade head
```

### 6. Seed de desenvolvimento

```bash
python -m app.utils.seed
# Anote o company_id gerado — você precisará dele
```

### 7. Rodar

```bash
uvicorn app.main:app --reload
# API disponível em: http://localhost:8000
# Docs:             http://localhost:8000/docs
```

---

## Setup com Docker Compose (produção local)

```bash
cp .env.example .env
# Edite .env
cp seu-firebase.json firebase-credentials.json

docker compose up -d
# Aplica migrações
docker compose exec api alembic upgrade head
# Seed (opcional)
docker compose exec api python -m app.utils.seed
```

---

## Fluxo de autenticação

```
Flutter                    Firebase              Backend
  │                           │                    │
  ├─ signInWithEmailAndPassword ──►                 │
  │                           ├─── idToken ────────►│
  │                           │                    ├─ verify_firebase_token()
  │                           │                    ├─ busca User por firebase_uid
  │◄──────────────────── JWT interno ───────────────┤
  │                           │                    │
  ├─ GET /api/v1/products  ───────────────────────►│
  │   Authorization: Bearer <JWT>                  │
  │◄────────────────── 200 produtos ───────────────┤
```

---

## Endpoints principais

### Auth
| Método | Rota | Descrição |
|---|---|---|
| POST | `/api/v1/auth/login` | Login com Firebase idToken → JWT |

### Usuários
| Método | Rota | Role mínimo |
|---|---|---|
| GET | `/api/v1/users/me` | operator |
| GET | `/api/v1/users` | manager |
| POST | `/api/v1/users` | admin |
| PATCH | `/api/v1/users/{id}` | admin |
| DELETE | `/api/v1/users/{id}` | admin |

### Empresas & Filiais
| Método | Rota | Role mínimo |
|---|---|---|
| GET | `/api/v1/companies` | admin |
| POST | `/api/v1/companies` | admin |
| GET | `/api/v1/companies/{id}/branches` | operator |
| POST | `/api/v1/companies/{id}/branches` | admin |

### Produtos
| Método | Rota | Role mínimo |
|---|---|---|
| GET | `/api/v1/products?q=notebook` | operator |
| POST | `/api/v1/products` | manager |
| GET | `/api/v1/products/{id}` | operator |
| PATCH | `/api/v1/products/{id}` | manager |
| DELETE | `/api/v1/products/{id}` | admin |
| GET | `/api/v1/products/{id}/qr` | operator |
| GET | `/api/v1/products/scan/{qr_payload}` | operator |

### Estoque & Movimentações
| Método | Rota | Descrição |
|---|---|---|
| GET | `/api/v1/stock/low` | Estoques abaixo do mínimo |
| GET | `/api/v1/branches/{id}/stock` | Estoque de uma filial |
| GET | `/api/v1/movements` | Últimas movimentações |
| POST | `/api/v1/movements` | Registrar entrada/saída/transfer |
| PUT | `/api/v1/branches/{b}/stock/{p}/adjust` | Ajuste direto (admin) |

### IA
| Método | Rota | Descrição |
|---|---|---|
| POST | `/api/v1/ai/ask` | Pergunta com contexto real da empresa |

---

## Roles (RBAC)

| Role | Permissões |
|---|---|
| `admin` | Tudo |
| `manager` | Criar/editar produtos, ver usuários da empresa |
| `operator` | Consultar e registrar movimentações |

---

## Tipos de movimentação

| Tipo | Efeito |
|---|---|
| `entrada` | Aumenta estoque na filial |
| `saida` | Diminui estoque (valida saldo) |
| `transfer` | Saída de uma filial + entrada em outra |
| `ajuste` | Define quantidade exata (admin) |

---

## Próximos passos (Fase 2)

- [ ] Financeiro: registrar receitas/custos automáticos por movimentação
- [ ] Relatórios: PDF de estoque e financeiro
- [ ] Notificações: Firebase Cloud Messaging para alertas de estoque baixo
- [ ] Analytics IA: previsão de demanda, detecção de anomalias
- [ ] App Flutter: telas conectadas a esta API
