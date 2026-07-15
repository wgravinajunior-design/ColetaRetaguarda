# 📊 Análise Completa de Endpoints - Mobile vs Backend

**Data:** 15 de julho de 2026  
**Status:** Análise de Integração  
**Versão Backend:** 1.18.0+

---

## 🎯 Resumo Executivo

O backend possui **apenas 1 feature completa** (Pessoas/Produtores) e **3 features sem implementação** (Motoristas, Veículos, Rotas). O mobile está preparado para 4 features principais que faltam endpoints:

| Feature | Mobile Ready? | Backend Status | Endpoint | Prioridade |
|---------|:--:|:--:|:--:|:--:|
| **Pessoas** | ✅ 100% | ✅ Completo | `/coleta/pessoas` | ✅ |
| **Motoristas** | ✅ 100% | ❌ Stub | `/coleta/motoristas` | 🔴 |
| **Veículos** | ✅ 100% | ❌ Stub | `/coleta/veiculos` | 🔴 |
| **Rotas** | ✅ 100% | ❌ Stub | `/coleta/rotas` | 🔴 |
| **Paradas/Coleta** | ✅ 100% | ❌ Não existe | `/coleta/paradas` | 🔴 |

---

## 📱 FEATURE 1: PESSOAS (PRODUTORES) ✅

### Mobile Status
- ✅ Model: `PessoaModel` completo (21 campos)
- ✅ Repository: `PessoaRepository` com sync
- ✅ ViewModel: `ProdutorViewModel` completo
- ✅ UI: Tela de listagem, formulário, mapa
- ✅ Offline: SyncService integrado

### Backend Status
- ✅ Endpoint `/coleta/pessoas` - **GET** implementado
- ✅ Endpoint `/coleta/pessoas` - **POST** implementado
- ✅ Endpoint `/coleta/pessoas/:id` - **PUT** implementado
- ✅ Endpoint `/coleta/pessoas/:id` - **DELETE** implementado

### Campos Suportados (Mobile → Backend)
```json
{
  "nome": "string",
  "endereco": "string",
  "latitude": "float",
  "longitude": "float",
  "volume_medio": "float",
  "hr_coleta": "string (HH:mm)",
  "km": "float"
}
```

### Status
✅ **PRONTO PARA USO**

---

## 🚗 FEATURE 2: MOTORISTAS

### Mobile Status
- ✅ Model: `MotoristaModel` completo (23 campos)
- ✅ Repository: `MotoristaRepository` com CRUD
- ✅ ViewModel: `MotoristaViewModel` completo
- ✅ UI: Tela de listagem, formulário
- ✅ Offline: Preparado para sync

### Campos do Model
```dart
MotoristaModel {
  id, nome, apelido,
  cpf, rg,
  telefone, celular, email,
  endereco, numero, complemento, bairro, cidade, cep,
  cnh, cnhValidade,
  status, dataCadastro, dataAtualizacao
}
```

### Backend Status
- ❌ Endpoint `/coleta/motoristas` - **GET** (Stub - retorna 501)
- ❌ Endpoint `/coleta/motoristas` - **POST** (Stub - retorna 501)
- ❌ Endpoint `/coleta/motoristas/:id` - **PUT** (Stub - retorna 501)
- ❌ Endpoint `/coleta/motoristas/:id` - **DELETE** (Stub - retorna 501)

### O que Falta
```dart
// GET /coleta/motoristas
SELECT MOT_ID, MOT_NOME, MOT_APELIDO, MOT_CPF, MOT_RG,
       MOT_TELEFONE, MOT_CELULAR, MOT_EMAIL,
       MOT_ENDERECO, MOT_NUMERO, MOT_COMPLEMENTO,
       MOT_BAIRRO, MOT_CIDADE, MOT_CEP,
       MOT_CNH, MOT_CNH_VALIDADE,
       MOT_STATUS
FROM TB_MOTORISTA WHERE MOT_STATUS = 'A'
```

### Status
⏳ **PRIORIDADE ALTA** - Tabelas existem no Firebird

---

## 🚙 FEATURE 3: VEÍCULOS

### Mobile Status
- ✅ Model: `VeiculoModel` completo (14 campos)
- ✅ Repository: `VeiculoRepository` com CRUD
- ✅ ViewModel: `VeiculoViewModel` completo
- ✅ UI: Tela de listagem, formulário
- ✅ Offline: Preparado para sync

### Campos do Model
```dart
VeiculoModel {
  id, placa, marca, modelo, cor, ano,
  tipo, renavam, chassi,
  status, dataCadastro, dataAtualizacao
}
```

### Backend Status
- ❌ Endpoint `/coleta/veiculos` - **GET** (Stub)
- ❌ Endpoint `/coleta/veiculos` - **POST** (Stub)
- ❌ Endpoint `/coleta/veiculos/:id` - **PUT** (Stub)
- ❌ Endpoint `/coleta/veiculos/:id` - **DELETE** (Stub)

### O que Falta
```dart
// GET /coleta/veiculos
SELECT VEI_ID, VEI_PLACA, VEI_MARCA, VEI_MODELO, VEI_COR,
       VEI_ANO, VEI_TIPO, VEI_RENAVAM, VEI_CHASSI,
       VEI_STATUS
FROM TB_VEICULO WHERE VEI_STATUS = 'A'
```

### Status
⏳ **PRIORIDADE ALTA** - Tabelas existem no Firebird

---

## 🗺️ FEATURE 4: ROTAS

### Mobile Status
- ✅ Model: `RotaModel` completo (15 campos)
- ✅ Repository: `RotaRepository` com CRUD
- ✅ ViewModel: `RotaViewModel` completo
- ✅ UI: Tela de listagem, detalhe, mapa
- ✅ Offline: Preparado para sync

### Campos do Model
```dart
RotaModel {
  id, descricao, regiao,
  motoristaId, veiculoId,
  status,
  dataPrevista, dataInicio, dataFim,
  paradas, kmEstimado, kmRealizado,
  dataCadastro
}
```

### Backend Status
- ❌ Endpoint `/coleta/rotas` - **GET** (Stub)
- ❌ Endpoint `/coleta/rotas` - **POST** (Stub)
- ❌ Endpoint `/coleta/rotas/:id` - **PUT** (Stub)
- ❌ Endpoint `/coleta/rotas/:id` - **DELETE** (Stub)

### O que Falta
```dart
// GET /coleta/rotas
SELECT ROT_ID, ROT_DESCRICAO, ROT_REGIAO,
       ROT_MOTORISTA_ID, ROT_VEICULO_ID,
       ROT_STATUS,
       ROT_DATA_PREVISTA, ROT_DATA_INICIO, ROT_DATA_FIM,
       ROT_PARADAS, ROT_KM_ESTIMADO, ROT_KM_REALIZADO
FROM TB_ROTA WHERE ROT_STATUS IN ('A', 'P')
```

### Status
⏳ **PRIORIDADE ALTA** - Tabelas existem no Firebird

---

## 🛑 FEATURE 5: PARADAS/COLETA

### Mobile Status
- ✅ Model: `ParadaModel` completo (21 campos)
- ✅ Repository: `ParadaRepository` com CRUD e upload
- ✅ ViewModel: `ColetaViewModel` completo
- ✅ UI: Tela de coleta com mapa, foto, assinatura, temperatura
- ✅ Offline: Sincronização com upload de fotos/assinaturas
- ✅ Serviços: GPS, câmera, assinatura, comprovante

### Campos do Model
```dart
ParadaModel {
  id, rotaId, pessoaId,
  pessoaNome, cnpjCpf, endereco,
  latitude, longitude,
  status, // P=Pendente, E=Em Andamento, C=Sucesso, R=Recusado
  temperatura, volume, justificativa,
  gpsCapturaLatitude, gpsCapturaltitude,
  horarioChegada, horarioSaida,
  assinaturaBase64, fotoPath,
  dataCadastro
}
```

### Backend Status
- ❌ Endpoint `/coleta/paradas` - **GET** (Não existe)
- ❌ Endpoint `/coleta/paradas` - **POST** (Não existe)
- ❌ Endpoint `/coleta/paradas/:id` - **PUT** (Não existe)
- ❌ Endpoint `/coleta/paradas/foto` - **POST** upload (Não existe)
- ❌ Endpoint `/coleta/paradas/:id/assinatura` - **PUT** (Não existe)

### O que Precisa Ser Criado
```dart
// POST /coleta/paradas
{
  "rota_id": 1,
  "pessoa_id": 5,
  "status": "E",
  "temperatura": 4.5,
  "volume": 50.0,
  "horario_chegada": "08:30",
  "gps_captura_latitude": -20.5,
  "gps_captura_longitude": -45.3
}

// POST /coleta/paradas/foto (multipart/form-data)
file: <image>
parada_id: 1

// PUT /coleta/paradas/:id/assinatura
{
  "assinatura_base64": "data:image/png;base64,..."
}

// PUT /coleta/paradas/:id/status
{
  "status": "C",
  "horario_saida": "09:15",
  "justificativa": "" // se recusado
}
```

### Status
🔴 **PRIORIDADE CRÍTICA** - Feature principal do mobile não implementada

---

## 🔄 FLUXO ESPERADO: COLETA OFFLINE

```
Mobile App
  ↓
1. Sincronizar Rotas Abertas (GET /coleta/rotas)
   ↓
2. Carregar Paradas Pendentes (GET /coleta/paradas?rota_id=1&status=P)
   ↓
3. Executar Coleta (offline):
   - Chegar na parada
   - GPS automático
   - Capturar temperatura
   - Tirar foto
   - Coletar assinatura
   - Atualizar status → "C" (Coleta OK) ou "R" (Recusado)
   ↓
4. Sincronizar quando online:
   - PUT /coleta/paradas/:id (dados)
   - POST /coleta/paradas/foto (imagem)
   - PUT /coleta/paradas/:id/assinatura (assinatura)
   ↓
5. Retornar status "S" (Sincronizado)
```

---

## 📋 REQUISITOS POR ENDPOINT

### GET /coleta/motoristas
**Requer:** JWT Token  
**Retorna:** Lista de motoristas  
**Campos:**
```json
[
  {
    "id": 1,
    "nome": "João Silva",
    "cpf": "123.456.789-00",
    "rg": "12.345.678-9",
    "telefone": "(31) 3333-3333",
    "celular": "(31) 99999-9999",
    "email": "joao@email.com",
    "endereco": "Rua X",
    "cidade": "Belo Horizonte",
    "cnh": "123456789",
    "cnhValidade": "2025-12-31",
    "status": "ATIVO"
  }
]
```

### GET /coleta/veiculos
**Requer:** JWT Token  
**Retorna:** Lista de veículos  
**Campos:**
```json
[
  {
    "id": 1,
    "placa": "ABC1234",
    "marca": "Scania",
    "modelo": "R440",
    "cor": "Branco",
    "ano": "2022",
    "tipo": "C",
    "renavam": "12345678901",
    "chassi": "XXXXXXXXXXXXXXXXX",
    "status": "ATIVO"
  }
]
```

### GET /coleta/rotas
**Requer:** JWT Token  
**Query:** `?data=2026-07-15&status=A` (opcional)  
**Retorna:** Lista de rotas do dia  
**Campos:**
```json
[
  {
    "id": 1,
    "descricao": "Rota Sul",
    "motorista_id": 1,
    "veiculo_id": 1,
    "status": "A",
    "data_prevista": "2026-07-15",
    "paradas": 5,
    "km_estimado": 150.5
  }
]
```

### GET /coleta/paradas?rota_id=1
**Requer:** JWT Token  
**Query:** `?rota_id=1&status=P` (status=P,E,C,R ou vazio para todos)  
**Retorna:** Lista de paradas da rota  

### POST /coleta/paradas
**Requer:** JWT Token  
**Body:** Dados da parada (sem foto/assinatura)  
**Retorna:** `{id: 123}`  

### PUT /coleta/paradas/:id
**Requer:** JWT Token  
**Body:** Atualizar temperatura, volume, status, etc  
**Retorna:** `{success: true}`  

### POST /coleta/paradas/foto
**Requer:** JWT Token  
**Content-Type:** multipart/form-data  
**Fields:** `parada_id`, `file`  
**Retorna:** `{success: true, url: "..."}`  

### PUT /coleta/paradas/:id/assinatura
**Requer:** JWT Token  
**Body:** `{assinatura_base64: "data:image/png;base64,..."}`  
**Retorna:** `{success: true}`  

---

## 🛠️ Plano de Implementação

### Fase 1: Motoristas (4 endpoints)
Tempo estimado: **2 horas**

```dart
// Em lib/core/backend/api_server.dart
static Future<shelf.Response> _listMotoristas(shelf.Request request) async {
  final tokenData = _validateBearerToken(request);
  if (tokenData == null) return _errorResponse(401, 'Token inválido');
  
  final db = await DbConnection().db;
  final query = db.query();
  await query.openCursor(
    sql: 'SELECT MOT_ID, MOT_NOME, MOT_APELIDO, MOT_CPF, MOT_RG, '
        'MOT_TELEFONE, MOT_CELULAR, MOT_EMAIL, '
        'MOT_ENDERECO, MOT_NUMERO, MOT_COMPLEMENTO, '
        'MOT_BAIRRO, MOT_CIDADE, MOT_CEP, '
        'MOT_CNH, MOT_CNH_VALIDADE, MOT_STATUS '
        'FROM TB_MOTORISTA WHERE MOT_STATUS = \'A\' '
        'ORDER BY MOT_NOME',
  );
  
  final items = <Map<String, dynamic>>[];
  await for (var row in query.rows()) {
    items.add({
      'id': row['MOT_ID'],
      'nome': row['MOT_NOME'],
      'cpf': row['MOT_CPF'] ?? '',
      'rg': row['MOT_RG'] ?? '',
      'telefone': row['MOT_TELEFONE'],
      'celular': row['MOT_CELULAR'],
      'email': row['MOT_EMAIL'],
      'endereco': row['MOT_ENDERECO'],
      'cidade': row['MOT_CIDADE'],
      'cnh': row['MOT_CNH'],
      'cnh_validade': row['MOT_CNH_VALIDADE'],
      'status': row['MOT_STATUS'] == 'A' ? 'ATIVO' : 'INATIVO',
    });
  }
  
  await query.close();
  return shelf.Response.ok(
    jsonEncode({'success': true, 'data': items}),
    headers: {'Content-Type': 'application/json'},
  );
}
```

### Fase 2: Veículos (4 endpoints)
Tempo estimado: **2 horas**

### Fase 3: Rotas (4 endpoints)
Tempo estimado: **2 horas**

### Fase 4: Paradas/Coleta (6 endpoints + upload)
Tempo estimado: **4 horas** (inclui multipart e armazenamento de arquivos)

---

## 📊 Resumo de Implementação

| Fase | Feature | Endpoints | Tempo | Status |
|------|---------|-----------|-------|--------|
| ✅ | Pessoas | 4 | 2h | Completo |
| ⏳ | Motoristas | 4 | 2h | Faltam endpoints |
| ⏳ | Veículos | 4 | 2h | Faltam endpoints |
| ⏳ | Rotas | 4 | 2h | Faltam endpoints |
| 🔴 | Paradas | 6 | 4h | Não existe |
| **Total** | **5 features** | **22 endpoints** | **12h** | **Será 100%** |

---

## ✅ Próximas Etapas

1. **Esta semana:**
   - [ ] Implementar `/coleta/motoristas` (GET, POST, PUT, DELETE)
   - [ ] Implementar `/coleta/veiculos` (GET, POST, PUT, DELETE)
   - [ ] Implementar `/coleta/rotas` (GET, POST, PUT, DELETE)

2. **Próxima semana:**
   - [ ] Implementar `/coleta/paradas` (GET, POST, PUT)
   - [ ] Implementar upload de foto e assinatura
   - [ ] Testar sincronização offline completa

3. **Futuro:**
   - [ ] Implementar relatórios de coleta
   - [ ] Implementar confirmação de entrega
   - [ ] Implementar rejeição com justificativa

---

## 🎯 Conclusão

✅ **Mobile 100% pronto** para todas as features  
❌ **Backend 20% pronto** (apenas Pessoas implementado)

**Faltam implementar:**
- 4 endpoints GET (listagem)
- 4 endpoints POST (criar)
- 8 endpoints PUT (atualizar)
- 4 endpoints DELETE (deletar)
- 2 endpoints especializados (foto, assinatura)

**Total: 22 endpoints** para integração completa mobile ↔ backend.

---

**Versão:** 1.18.0+  
**Data:** 15 de julho de 2026  
**Status:** Análise Completa - Pronto para Implementação
