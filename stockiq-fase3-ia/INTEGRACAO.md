# Fase 3 — Integração com o Backend (Fase 1)

## O que foi adicionado

| Arquivo | Descrição |
|---|---|
| `app/ai/analytics.py` | Motor de analytics: alertas, score de filiais, insights de produtos |
| `app/ai/predictions.py` | Previsão de demanda com regressão linear OLS |
| `app/ai/assistant.py` | Assistente Claude com contexto dinâmico (substitui o da Fase 1) |
| `app/reports/pdf_report.py` | Gerador de PDF executivo com ReportLab |
| `app/controllers/analytics_controller.py` | 5 novos endpoints REST |
| `tests/test_analytics.py` | 20 testes unitários sem necessidade de banco |

---

## Integração passo a passo

### 1. Instale as dependências adicionais

```bash
cd stockiq-backend
pip install numpy==1.26.4 pandas==2.2.2 reportlab==4.2.0 --break-system-packages
```

Ou adicione ao `requirements.txt` e rode:

```bash
pip install -r requirements.txt
```

### 2. Copie os arquivos para o backend da Fase 1

```bash
# Analytics e IA
cp app/ai/analytics.py   ../stockiq-backend/app/ai/
cp app/ai/predictions.py ../stockiq-backend/app/ai/
cp app/ai/assistant.py   ../stockiq-backend/app/ai/   # substitui o existente

# PDF
cp app/reports/pdf_report.py ../stockiq-backend/app/reports/
mkdir -p ../stockiq-backend/app/reports
touch ../stockiq-backend/app/reports/__init__.py

# Controller
cp app/controllers/analytics_controller.py ../stockiq-backend/app/controllers/

# Testes
cp tests/test_analytics.py ../stockiq-backend/tests/
```

### 3. Registre o controller em main.py

```python
# Em: stockiq-backend/app/main.py
from app.controllers.analytics_controller import router as analytics_router

# Na seção de routers:
app.include_router(analytics_router, prefix=API)
```

### 4. Rode os testes

```bash
cd stockiq-backend
pytest tests/test_analytics.py -v
```

---

## Novos endpoints

| Método | Rota | Descrição | Role mínimo |
|---|---|---|---|
| GET | `/api/v1/analytics/report` | Relatório completo (alertas + filiais + produtos) | operator |
| GET | `/api/v1/analytics/forecast` | Previsão de demanda por produto | operator |
| GET | `/api/v1/analytics/alerts` | Apenas alertas ativos | operator |
| POST | `/api/v1/analytics/ask` | Chat com IA (histórico multi-turn) | operator |
| GET | `/api/v1/analytics/report/pdf` | Download PDF executivo | manager |

---

## Exemplo de uso — Chat com histórico

```http
POST /api/v1/analytics/ask
Authorization: Bearer <token>

{
  "question": "Qual filial precisa de mais atenção?",
  "history": [
    {"role": "user",      "content": "Quais são os alertas críticos?"},
    {"role": "assistant", "content": "Há 2 alertas críticos: estoque zerado do..."}
  ]
}
```

## Exemplo de uso — Relatório PDF

```bash
# Baixa o PDF diretamente
curl -H "Authorization: Bearer <token>" \
     http://localhost:8000/api/v1/analytics/report/pdf \
     -o relatorio_stockiq.pdf
```

---

## Algoritmos implementados

### AnalyticsEngine

| Detector | Lógica |
|---|---|
| Estoque crítico | `quantity <= min_quantity` → warning; `quantity == 0` → critical |
| Produto parado | Sem movimentação nos últimos 30 dias com estoque > 0 |
| Queda de vendas | Saídas da semana atual vs semana anterior por filial, threshold 20% |
| Margem negativa | `cost_price >= sale_price` |
| Score de filial | 100 - (itens críticos × 10) - (alertas da filial × 8), min 0 |

### DemandForecaster

| Componente | Implementação |
|---|---|
| Série temporal | Saídas agrupadas por dia (últimos 60 dias) |
| Regressão | OLS nativo (sem sklearn): `slope = Σ(x-x̄)(y-ȳ) / Σ(x-x̄)²` |
| Confiança | R² simplificado: `1 - SS_res/SS_tot` |
| Dias até zerar | `stock_total / avg_daily_demand` |
| Qtd recompra | `avg_daily × (lead_time + 14) × safety_factor` |
| Sazonalidade | Índice de demanda por dia da semana relativo à média |

---

## Integração Flutter (Fase 2)

Adicione ao `StockApiService` do app Flutter:

```dart
// lib/core/services/stock_api_service.dart

Future<Map<String, dynamic>> getAnalyticsReport() async {
  final resp = await _dio.get('/analytics/report');
  return resp.data as Map<String, dynamic>;
}

Future<Map<String, dynamic>> getForecast() async {
  final resp = await _dio.get('/analytics/forecast');
  return resp.data as Map<String, dynamic>;
}

Future<Uint8List> downloadPDF() async {
  final resp = await _dio.get('/analytics/report/pdf',
    options: Options(responseType: ResponseType.bytes));
  return Uint8List.fromList(resp.data as List<int>);
}
```

Para abrir o PDF no Flutter:
```bash
flutter pub add open_filex
```
```dart
// Salva e abre o PDF
final dir  = await getTemporaryDirectory();
final file = File('${dir.path}/relatorio.pdf');
await file.writeAsBytes(pdfBytes);
await OpenFilex.open(file.path);
```
