# 📊 Análise: Backend Delphi vs. Flutter Retaguarda

**Data:** 14 de julho de 2026  
**Status:** ⚠️ INTEGRAÇÃO NECESSÁRIA  
**Versão Backend:** Horse (Delphi)  
**Versão Frontend:** Flutter 1.17.0+

---

## 🔍 Situação Atual

### Backend (Delphi + Horse)
- ✅ **Servidor rodando:** `Server.exe` em `C:\...\backend_delphi\`
- ✅ **Framework:** Horse (framework web Delphi)
- ✅ **Controllers implementados:** 11 (Auth, Pessoa, Produtor, Motorista, Rota, etc)
- ✅ **Autenticação:** Bearer Token (JWT-like)
- ⚠️ **Documentação:** Parcial (apenas MovimentoConta)

### Frontend (Flutter)
- ✅ **App rodando:** Teste de login local (Firebird direto)
- ❌ **APIs integradas:** NÃO está usando endpoints do backend
- ❌ **Autenticação de API:** NÃO implementada
- ⚠️ **Repositórios:** Apontam para endpoints não integrados

---

## 📋 Endpoints Implementados no Backend

### 1. **Autenticação** (`/auth`)

#### POST `/auth/login`
```
Descrição: Autenticar usuário
Body: { login, senha }
Response (200): { id, nome, perfil, login, id_pessoa_app, token }
Response (401): { error: "Credenciais invalidas" }
```

**Status:** ✅ Implementado  
**Flutter Current:** ❌ Não está usando (autentifica direto no Firebird)

#### PUT `/auth/senha/:id`
```
Descrição: Trocar senha
Headers: Authorization: Bearer token
Body: { senha_atual, senha_nova }
Response (200): { success: true }
Response (401): { error: "Senha atual incorreta" }
```

**Status:** ✅ Implementado  
**Flutter Current:** ❌ Não implementado

#### DELETE `/auth/logout`
```
Descrição: Revogar token
Headers: Authorization: Bearer token
Response (200): { success: true }
```

**Status:** ✅ Implementado  
**Flutter Current:** ❌ Não implementado

---

### 2. **Produtores** (`/coleta/produtores`)

#### GET `/coleta/produtores`
```
Descrição: Listar todos os produtores
Headers: Authorization: Bearer token
Response (200): [
  {
    id, nome, endereco, latitude, longitude, 
    volume_medio_diario, horario_coleta_previsto, 
    km_ate_tanque_principal, id_resfriador, status
  }
]
```

**Status:** ✅ Implementado  
**Flutter Current:** ⚠️ ViewModels esperam isso, mas não conseguem chamar

#### POST `/coleta/produtores`
```
Body: { nome, endereco, latitude, longitude, volume_medio_diario, ... }
Response (201): { id }
```

**Status:** ✅ Implementado  
**Flutter Current:** ⚠️ Nenhuma implementação

#### PUT `/coleta/produtores/:id`
```
Body: { nome, endereco, latitude, longitude, ... }
Response (200): { success: true }
```

**Status:** ✅ Implementado  
**Flutter Current:** ❌ Não implementado

#### DELETE `/coleta/produtores/:id`
```
Descrição: Soft delete (PES_STATUS = 'I')
Response (200): { success: true }
```

**Status:** ✅ Implementado  
**Flutter Current:** ❌ Não implementado

---

### 3. **Movimento Conta / Financeiro** (`/coleta/movimento-conta`)

#### GET `/coleta/movimento-conta`
```
Parâmetros: tipo, data_inicio, data_fim, conta
Response: [{ mov_id, mov_tipo, mov_valor, mov_dt_emissao, ... }]
```

**Status:** ✅ Implementado (documentado)  
**Flutter Current:** ❌ Não integrado

#### POST `/coleta/movimento-conta`
```
Body: { mov_tipo, mov_conta, mov_valor, mov_dt_emissao, ... }
Response: { mov_id }
```

**Status:** ✅ Implementado  
**Flutter Current:** ❌ Não integrado

#### PUT `/coleta/movimento-conta/:id`
```
Body: { mov_tipo, mov_valor, mov_dt_emissao, ... }
Response: { success: true }
```

**Status:** ✅ Implementado  
**Flutter Current:** ❌ Não integrado

#### DELETE `/coleta/movimento-conta/:id`
```
Response: { success: true }
```

**Status:** ✅ Implementado  
**Flutter Current:** ❌ Não integrado

#### GET `/coleta/fluxo-caixa`
```
Parâmetros: data_inicio, data_fim
Response: { 
  data_inicio, data_fim, total_receitas, 
  total_despesas, saldo_liquido 
}
```

**Status:** ✅ Implementado  
**Flutter Current:** ❌ Não integrado

#### GET `/coleta/contas`
```
Response: [{ cnt_id, cnt_descricao, cnt_padrao, cnt_tipo }]
```

**Status:** ✅ Implementado  
**Flutter Current:** ❌ Não integrado

---

### 4. **Outros Controllers** (Parcialmente Documentados)

| Endpoint | Status | Flutter |
|----------|--------|---------|
| `/coleta/motoristas` | ✅ Impl | ❌ Não |
| `/coleta/colaboradores` | ✅ Impl | ❌ Não |
| `/coleta/veiculos` | ✅ Impl | ❌ Não |
| `/coleta/resfriadores` | ✅ Impl | ❌ Não |
| `/coleta/rotas` | ✅ Impl | ❌ Não |
| `/pessoa` | ✅ Impl | ❌ Não |
| `/images` | ✅ Impl | ❌ Não |

---

## 🎯 Status de Integração

### Crítico ❌

1. **Login via API**
   - Backend: POST `/auth/login` ✅
   - Flutter: Usa autenticação direta Firebird ❌
   - **Ação:** Integrar AuthService com `/auth/login`

2. **Endpoints CRUD**
   - Backend: 11 controllers com CRUD ✅
   - Flutter: ViewModels esperam APIs, mas não conseguem chamar ❌
   - **Ação:** Conectar ProdutorRepository, MotoristaRepository, etc com `/coleta/*` endpoints

3. **Autenticação Bearer Token**
   - Backend: Gera Bearer Token ✅
   - Flutter: Não suporta ❌
   - **Ação:** Implementar suporte a Bearer Token no ApiClient

---

## 🚀 Próximos Passos (Roadmap)

### Fase 1: Autenticação (1-2 dias)
- [ ] Modificar AuthService para chamar POST `/auth/login`
- [ ] Armazenar Bearer token retornado
- [ ] Adicionar Bearer token em todos os headers API
- [ ] Testar login via API

### Fase 2: Endpoints Principais (3-4 dias)
- [ ] Integrar ProdutorRepository com `/coleta/produtores`
- [ ] Integrar MotoristaRepository com `/coleta/motoristas`
- [ ] Integrar ColaboradorRepository com `/coleta/colaboradores`
- [ ] Integrar VeiculoRepository com `/coleta/veiculos`
- [ ] Testar CRUD completo

### Fase 3: Financeiro (2-3 dias)
- [ ] Integrar FinanceiroRepository com `/coleta/movimento-conta`
- [ ] Implementar dashboard de fluxo de caixa
- [ ] Testar relatórios financeiros

### Fase 4: Offline Sync (2-3 dias)
- [ ] Implementar sync de dados offline
- [ ] Carregar dados da API → SQLite local
- [ ] Sincronizar mudanças de volta ao servidor

### Fase 5: Testes & Polish (1-2 dias)
- [ ] Testes end-to-end
- [ ] Tratamento de erros
- [ ] Performance optimization

---

## 📝 Configuração Necessária

### No Flutter

#### 1. Configurar URL Base da API
```dart
// lib/core/api/http_client.dart
// ATUALMENTE: _baseUrl = 'http://localhost:3000'

// DEVE SER (porta padrão Horse Delphi):
_baseUrl = 'http://localhost:9000'; // ou IP do servidor
```

#### 2. Adicionar Suporte a Bearer Token
```dart
// AuthService precisa armazenar token:
String _bearerToken = '';

// E enviar em todos os headers:
Map<String, String> _getHeaders() {
  final headers = <String, String>{
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_bearerToken', // ← ADICIONAR
  };
  return headers;
}
```

#### 3. Modificar AuthService.login()
```dart
// ANTES:
await q.openCursor(
  sql: "SELECT USU_ID, USU_NOME FROM TB_USUARIO WHERE ...",
  parameters: [username, password],
);

// DEPOIS:
final response = await apiClient.post('/auth/login', body: {
  'login': username,
  'senha': password,
});

if (response.success) {
  final token = response.data['token'];
  apiClient.setBearerToken(token);
  // ... rest of logic
}
```

---

## 🔌 Como Conectar (Exemplo: ProdutorRepository)

### Antes (Sem API)
```dart
class ProdutorRepository {
  Future<List<PessoaModel>> listar() async {
    // Conecta direto ao SQLite local
  }
}
```

### Depois (Com API)
```dart
class ProdutorRepository {
  final ApiClient _api = ApiClient();
  
  Future<List<PessoaModel>> listar() async {
    final response = await _api.get('/coleta/produtores');
    
    if (response.success) {
      return (response.data as List)
          .map((e) => PessoaModel.fromJson(e))
          .toList();
    }
    throw Exception(response.error);
  }
  
  Future<void> criar(PessoaModel produtor) async {
    final response = await _api.post('/coleta/produtores', body: {
      'nome': produtor.nome,
      'endereco': produtor.endereco,
      'latitude': produtor.latitude,
      'longitude': produtor.longitude,
      'volume_medio_diario': produtor.volumeMedioDiario,
      'status': 'ATIVO',
    });
    
    if (!response.success) {
      throw Exception(response.error);
    }
  }
}
```

---

## ⚠️ Considerações

### 1. **Porta do Servidor**
- Backend usa **porta padrão Horse** (precisa verificar qual é)
- Flutter está configurado para `localhost:3000` ❌
- **Ação:** Verificar porta real em `Server.exe`

### 2. **CORS**
- Backend tem `THorseCore.Use(CORS)` ✅
- Flutter pode fazer requisições cross-origin ✅

### 3. **Autenticação**
- Backend usa Bearer Token (JWT-like) ✅
- Flutter precisa armazenar e enviar token em todos os headers ❌

### 4. **Sincronização**
- Backend é REST puro ✅
- Flutter tem SQLite local para cache ✅
- Sync automático **NÃO ESTÁ IMPLEMENTADO** ❌

---

## 🎯 Recomendação Imediata

**Prioridade 1:** Integrar autenticação via API
1. Testar qual é a porta real do servidor Horse
2. Modificar AuthService para chamar POST `/auth/login`
3. Armazenar e usar Bearer token em todas as requisições
4. Validar que login funciona via API em vez de direto no Firebird

**Prioridade 2:** Integrar endpoints CRUD
1. Começar com ProdutorRepository
2. Adaptar models para match a resposta da API
3. Testar listar → criar → atualizar → deletar
4. Replicar padrão para outros módulos

---

## 📊 Checklist de Implementação

- [ ] **Fase 1: Auth**
  - [ ] Verificar porta do servidor Horse
  - [ ] Modificar AuthService.login() para usar API
  - [ ] Armazenar Bearer token
  - [ ] Enviar token em headers
  - [ ] Testar login via API

- [ ] **Fase 2: CRUD**
  - [ ] Adaptar ProdutorRepository
  - [ ] Adaptar MotoristaRepository
  - [ ] Adaptar ColaboradorRepository
  - [ ] Adaptar VeiculoRepository
  - [ ] Testar CRUD completo

- [ ] **Fase 3: Financeiro**
  - [ ] Integrar FinanceiroRepository
  - [ ] Implementar dashboard

- [ ] **Fase 4: Offline**
  - [ ] Implementar sync engine
  - [ ] Testar sincronização

- [ ] **Fase 5: QA**
  - [ ] Testes end-to-end
  - [ ] Performance testing
  - [ ] Error handling

---

**Status:** ⚠️ **Integração pendente - Backend pronto, Frontend não conectado**

**Próximo passo:** Verificar porta real do servidor e iniciar integração de autenticação.
