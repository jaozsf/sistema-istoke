# StockIQ — FastAPI + PostgreSQL + Firebase + Flutter

ERP SaaS com controle de estoque, financeiro e IA integrada. Repositório
tem dois projetos: `backend/` (API) e `stockiq-flutter/` (app Flutter,
roda em web/Android/iOS/desktop).

---

## Stack

| Camada | Tecnologia |
|---|---|
| API | FastAPI 0.111 + Uvicorn |
| Banco | PostgreSQL 16 + SQLAlchemy 2 (async) |
| Migrações | Alembic |
| Auth | Firebase Auth (email/senha + Google) + JWT interno (python-jose) |
| IA | Respostas padrão sem custo (dados reais) + Anthropic Claude opcional pra perguntas livres |
| QR Code | qrcode + Pillow + reportlab (PDF de etiquetas) |
| Frontend | Flutter (Riverpod + go_router) |
| Container | Docker + Docker Compose |

---

## Estrutura

```
backend/
├── app/
│   ├── core/          config, database, firebase, security (JWT + RBAC)
│   ├── models/        ORM: Company, Branch, User, Product, Stock, Movement, Finance, Log
│   ├── schemas/       Pydantic v2: request/response bodies
│   ├── repositories/  Acesso ao banco (BaseRepository + específicos)
│   ├── services/      Regras de negócio (auth, product, stock, company, user)
│   ├── controllers/   Routers FastAPI (endpoints HTTP)
│   ├── ai/            Assistente (respostas padrão + Claude opcional)
│   ├── reports/        PDF (relatório executivo, etiquetas QR)
│   └── utils/         seed.py alternativo, qr_code helpers
└── seed.py             Seed principal (empresa + filial + usuário + produtos demo)

stockiq-flutter/
├── lib/
│   ├── core/           config, providers, services (API, auth, notificações)
│   ├── features/       telas (auth, dashboard, produtos, estoque, qr, ia)
│   └── shared/         models (freezed) e widgets reusáveis
└── web/                 suporte a Flutter Web (gerado por `flutter create . --platforms=web`)
```

---

## Backend — Setup com Docker Compose (recomendado)

### 1. Clone

```bash
git clone https://github.com/jaozsf/sistema-istoke.git
cd sistema-istoke/backend
```

### 2. Firebase

1. Acesse o [Firebase Console](https://console.firebase.google.com) e crie um projeto.
2. **Authentication → Sign-in method** → ative **Email/senha** e (opcional) **Google**.
3. **Configurações do projeto → Contas de serviço → Gerar nova chave privada** — baixa um `.json`.
4. Salve esse arquivo como `backend/firebase-credentials.json` (**dentro da pasta `backend/`**, não na raiz do repositório — o `docker-compose.yml` procura o arquivo relativo a essa pasta).

### 3. Configure o `.env`

```bash
cp .env.example .env
# Edite pelo menos SECRET_KEY e FIREBASE_PROJECT_ID
```

### 4. Suba os containers

```bash
docker compose up -d --build
```

Isso sobe Postgres + API. A API roda as migrações automaticamente no
startup (via SQLAlchemy `create_all` durante o lifespan). Confirme em
http://localhost:8000/docs.

> **Porta já em uso?** Se você já tem outro Postgres/API rodando nas
> portas 5432/8000, edite os mapeamentos em `docker-compose.yml` (ex:
> `"5435:5432"` e `"8010:8000"`) e ajuste `DATABASE_URL`/`DATABASE_URL_SYNC`
> no `.env` de acordo (o host interno continua `db:5432`, só a porta
> exposta no seu PC muda).

### 5. Seed de dados (empresa + usuário admin + produtos demo)

Edite `backend/seed.py`: troque `FIREBASE_UID` e `USER_EMAIL` pelo UID e
email de um usuário que você criou em Authentication → Users no Firebase
Console. Depois:

```bash
docker compose exec api python seed.py
```

Anote o `company_id` impresso — não é necessário pro app funcionar, mas
ajuda a depurar direto no banco se precisar.

> **Login sem editar o seed:** se você ativou o provedor **Google** no
> passo 2, qualquer conta Google que logar pelo app ganha acesso
> automático (role `operator`, vinculada à primeira empresa cadastrada) —
> não precisa editar `seed.py` pra cada pessoa nova.

---

## Backend — Setup local sem Docker

```bash
cd backend
python -m venv venv
source venv/bin/activate          # Windows: venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env
# edite .env — DATABASE_URL apontando pra localhost em vez de "db"
alembic upgrade head
python seed.py
uvicorn app.main:app --reload
# API: http://localhost:8000 — Docs: http://localhost:8000/docs
```

---

## Frontend (Flutter)

### Pré-requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) instalado (`flutter doctor` sem erros bloqueantes).
- Backend já rodando (passos acima).

### 1. Configure o Firebase do app web/mobile

O arquivo `lib/firebase_options.dart` já vem com a config web do projeto
Firebase usado no desenvolvimento. Se você criou seu **próprio** projeto
Firebase, gere o seu:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Isso sobrescreve `lib/firebase_options.dart` com as chaves do seu projeto
(essas chaves de app web/mobile não são segredo — só a chave de conta de
serviço do backend é sensível).

### 2. Aponte pra sua API

Edite `lib/core/constants/app_constants.dart` → `baseUrl`:

| Onde vai rodar | Valor |
|---|---|
| Emulador Android | `http://10.0.2.2:8000/api/v1` (padrão já configurado) |
| iOS Simulator / Web / Desktop | `http://localhost:8000/api/v1` |
| Dispositivo físico / produção | IP da máquina ou domínio real |

### 3. Instale dependências e rode

```bash
cd stockiq-flutter
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # gera *.freezed.dart / *.g.dart
flutter run -d chrome     # ou: flutter run -d edge / windows / android / ios
```

Pra build de produção web (serve estático, sem hot reload):

```bash
flutter build web
# serve build/web com qualquer servidor estático, ex:
python -m http.server 5173 --directory build/web
```

> Se o `build_runner` travar com erro em `retrofit_generator`: o pacote
> não é usado no código (era dependência morta) e já foi removido do
> `pubspec.yaml`. Se voltar a acontecer com outro gerador, rode
> `flutter pub get` de novo antes de tentar o build.

---

## Fluxo de autenticação

```
Flutter                    Firebase              Backend
  │                           │                    │
  ├─ signInWithEmailAndPassword ──►                 │
  │  (ou signInWithPopup do Google)                 │
  │                           ├─── idToken ────────►│
  │                           │                    ├─ verify_firebase_token()
  │                           │                    ├─ busca User por firebase_uid
  │                           │                    ├─ (se não achar: vincula por
  │                           │                    │   email OU auto-cadastra
  │                           │                    │   como operator)
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
| POST | `/api/v1/auth/login` | Login com Firebase idToken → JWT (auto-cadastra no primeiro login com Google) |

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
| GET | `/api/v1/products?q=nome` | operator |
| POST | `/api/v1/products` | manager |
| GET | `/api/v1/products/{id}` | operator |
| PATCH | `/api/v1/products/{id}` | manager |
| DELETE | `/api/v1/products/{id}` | admin |
| GET | `/api/v1/products/{id}/qr` | operator |
| GET | `/api/v1/products/qr-labels/pdf` | operator — PDF com etiqueta (QR + nome + SKU) de cada produto ativo, pra imprimir |
| GET | `/api/v1/products/scan/{qr_payload}` | operator |

### Estoque & Movimentações
| Método | Rota | Descrição |
|---|---|---|
| GET | `/api/v1/stock/low` | Estoques abaixo do mínimo |
| GET | `/api/v1/branches/{id}/stock` | Estoque de uma filial |
| GET | `/api/v1/movements` | Últimas movimentações |
| POST | `/api/v1/movements` | Registrar entrada/saída/transfer |
| PUT | `/api/v1/branches/{b}/stock/{p}/adjust` | Ajuste direto (admin) |

### IA / Assistente
| Método | Rota | Descrição |
|---|---|---|
| POST | `/api/v1/ai/ask` | Perguntas comuns (estoque baixo, produto parado, queda de vendas, onde tô perdendo dinheiro) respondem na hora com dados reais, sem custo de IA. Pergunta fora desses padrões cai pro Claude, se `ANTHROPIC_API_KEY` estiver configurada — senão retorna aviso pedindo a chave. |

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
| `saida` | Diminui estoque (valida saldo). Preencha "observações" se retirou menos que uma caixa/lote fechado. |
| `transfer` | Saída de uma filial + entrada em outra |
| `ajuste` | Define quantidade exata (admin) |

---

## Solução de problemas comuns

| Sintoma | Causa provável | Fix |
|---|---|---|
| Container `stockiq_api` não sobe: erro de mount em `firebase-credentials.json` | Arquivo não existe em `backend/` (só na raiz do repo, ou não foi baixado) | Confira o passo 2 do setup — o arquivo precisa estar dentro de `backend/` |
| `IsADirectoryError` no boot da API | Docker criou um diretório vazio no lugar do arquivo (aconteceu de tentar subir sem o arquivo existir antes) | `docker compose down`, apague a pasta com esse nome, coloque o arquivo de verdade, suba de novo |
| Tela do app fica branca sem erro nenhum | Alguma exceção não tratada travou o `main()` antes do primeiro frame (comum: chamada que espera configuração que não existe, tipo Firebase Messaging sem service worker no web) | Roda com `flutter run` (não `build`) pra ver o erro real no terminal, ou abre o DevTools do navegador (F12 → Console) |
| Tela cinza sólida em alguma rota (sem crash no terminal) | Em build release, widget que lançou exceção no `build()` vira uma caixa cinza sem texto (por design do Flutter) — rode em modo debug pra ver o erro de verdade | `flutter run` local, reproduzir a mesma navegação |
| Login dá erro de CORS no navegador | Origem do Flutter Web (porta do `flutter run`/servidor estático) não está em `ALLOWED_ORIGINS` no `.env` do backend | Adicione a origem (ex: `http://localhost:5173`) e reinicie o container (`docker compose up -d --force-recreate api` — `restart` sozinho não relê o `.env`) |
| `TypeError: "0.00": type 'String' is not a subtype of type 'num'` | Preço vem como `Decimal`/string do backend, já corrigido no modelo Flutter (`ProductModel`) | Se acontecer de novo em outro campo numérico, mesma causa — adicionar conversor `fromJson` |

---

## Próximos passos

- [x] App Flutter conectado à API (web funcionando; mobile precisa de config Firebase própria via `flutterfire configure`)
- [x] Respostas padrão no Assistente sem depender de IA paga
- [x] Etiquetas QR em PDF pra imprimir
- [ ] Financeiro: registrar receitas/custos automáticos por movimentação
- [ ] Relatório PDF de estoque e financeiro completo (já existe endpoint `/analytics/report/pdf`, falta expor no app)
- [ ] Notificações push (Firebase Cloud Messaging) — desativadas no web por falta de `firebase-messaging-sw.js`/VAPID key
- [ ] Analytics IA: previsão de demanda (`/analytics/forecast` já existe no backend, falta tela no app)
