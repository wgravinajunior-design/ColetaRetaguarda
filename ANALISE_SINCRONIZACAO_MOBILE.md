# 🔄 Análise: Sincronização Mobile ↔ Desktop (Flutter Retaguarda)

**Data:** 14 de julho de 2026  
**Status:** ⚠️ INCOMPLETA - Servidor HTTP não implementado  
**Objetivo:** Sincronizar dados entre app mobile e desktop via Flutter retaguarda

---

## 📋 Modelo Atual de Sincronização

### Arquitetura Esperada
```
┌─────────────────────────────────────────────────────────┐
│                    FIREBIRD (Central)                    │
│         (TB_PESSOA, TB_MOTORISTA, TB_VEICULO, etc)       │
└─────────────────────────────────────────────────────────┘
          ↑                                    ↑
          │                                    │
          │ (SQLite local               (SQLite local
          │  + Sync Queue)               + Sync Queue)
          │                                    │
    ┌─────┴──────────────────────────────────┴─────┐
    │                                               │
┌───▼──────────────────┐             ┌─────────────▼────┐
│ Flutter Retaguarda   │             │  App Mobile      │
│    (Desktop)         │             │    (MAUI/Flutter)│
│  - CRUD local        │             │  - CRUD local    │
│  - Sync Queue        │             │  - Sync Queue    │
│  - Sincroniza com    │             │  - Sincroniza    │
│    Firebird          │             │    com Firebird  │
└──────────────────────┘             └──────────────────┘
```

### Problema Identificado ⚠️
O Flutter retaguarda tem **SyncService** que tenta enviar para:
```dart
'/coleta/pessoas'        // POST/PUT/DELETE
'/coleta/motoristas'
'/coleta/veiculos'
'/coleta/rotas'
'/coleta/movimento-conta'
```

**MAS:** Esses endpoints **NÃO EXISTEM** em lugar nenhum!
- ❌ Backend Delphi não tem esses endpoints
- ❌ Flutter retaguarda não expõe servidor HTTP
- ❌ Não há API para mobile se conectar

---

## 🔴 Situação Crítica

### O SyncService está órfão

```dart
// lib/features/core/database/sync_service.dart:50
await _apiClient.post(endpoint, body: dados);  
// ↑ Envia para onde???
```

### Endpoints Esperados pelo SyncService

| Tabela | Endpoint | Método | Status |
|--------|----------|--------|--------|
| tb_pessoa | `/coleta/pessoas` | POST/PUT/DELETE | ❌ Não existe |
| tb_motorista | `/coleta/motoristas` | POST/PUT/DELETE | ❌ Não existe |
| tb_veiculo | `/coleta/veiculos` | POST/PUT/DELETE | ❌ Não existe |
| tb_rota | `/coleta/rotas` | POST/PUT/DELETE | ❌ Não existe |
| tb_movimento_conta | `/coleta/movimento-conta` | POST/PUT/DELETE | ❌ Não existe |

---

## 🎯 Opção 1: Usar Firebird Compartilhado (Recomendado)

### Como Funciona
```
Desktop (Flutter)
    ↓
    └→ Firebird (rede)
        ↑
        └← Mobile (MAUI)
```

### Vantagens
- ✅ Compartilhamento de dados centralizado
- ✅ Sem necessidade de servidor HTTP
- ✅ Transações diretas no banco
- ✅ Simples e direto

### Desvantagens
- ❌ Requer conexão de rede com Firebird
- ❌ Sem sincronização offline (tudo é real-time)
- ❌ Sem queue de operações

### Implementação
1. Desktop e Mobile conectam ao **mesmo Firebird**
2. Remover `SyncService` do desktop (não é necessário)
3. Mobile lê/escreve direto no Firebird
4. Sem API intermediária

---

## 🎯 Opção 2: Implementar Servidor HTTP no Flutter (Complexo)

### Como Funciona
```
Mobile
    ↓
    POST /api/pessoas
    PUT /api/pessoas/1
    DELETE /api/pessoas/1
    ↓
Flutter Retaguarda (Server Mode)
    ↓
    Firebird
```

### Vantagens
- ✅ Mobile pode estar offline (sincroniza depois)
- ✅ Queue local de operações
- ✅ Compatível com sync asíncrono

### Desvantagens
- ❌ Requer implementar servidor HTTP em Flutter
- ❌ Complexo de debug
- ❌ Porta precisa estar aberta no desktop
- ❌ Não há framework web em Flutter nativo

### Desafios Técnicos
1. **Flutter não tem servidor HTTP nativo**
   - Precisaria usar `shelf` ou `dart_frog`
   - Incompatível com Flutter UI padrão

2. **Conflito de portas**
   - App Flutter usa UI thread
   - Servidor usaria thread separate
   - Pode ter issues de performance

3. **Deve ser servidor separado**
   - Opção: Dart isolate com `shelf`
   - Opção: Separar em dois processes

---

## 🎯 Opção 3: Usar Backend Delphi + Flutter Retaguarda como Cliente (Intermediário)

### Como Funciona
```
Mobile
    ↓
    POST /auth/login (Delphi)
    GET /coleta/pessoas (Delphi)
    ↓
Backend Delphi (Horse)
    ↓
    Firebird
    ↑
    ↓
Flutter Retaguarda (Cliente)
    ↓
    Firebird
```

### Vantagens
- ✅ Backend robusto (Delphi + Horse)
- ✅ API bem documentada
- ✅ Suporta autenticação
- ✅ Ambos (desktop e mobile) usam mesma API

### Desvantagens
- ❌ Requer servidor Delphi rodando sempre
- ❌ Backend para desktop também fica dependente do servidor

---

## 💡 Recomendação

### Para Sua Situação
**Opção 1: Firebird Compartilhado** é a mais simples:

```dart
// Desktop (flutter_retaguarda)
final db = await DbConnection().db;  // Conecta ao Firebird

// Mobile (MAUI/Flutter)
final db = await DbConnection().db;  // Mesmo Firebird

// Ambos acessam: TB_PESSOA, TB_MOTORISTA, etc
```

**Ações:**
1. ✅ Remover `SyncService` (não é necessário)
2. ✅ Configurar mobile para acessar Firebird via rede
3. ✅ Usar transações para evitar conflitos
4. ✅ Implementar lock otimista (versioning)

---

## 🔧 Se Quiser Usar SyncService (Opção 2)

Se insistir em implementar servidor HTTP:

### 1. Criar Servidor Dart Isolado
```dart
// lib/services/api_server.dart
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;

void startApiServer() async {
  final handler = shelf.Router()
    ..get('/api/pessoas', _getPessoas)
    ..post('/api/pessoas', _createPessoa)
    ..put('/api/pessoas/<id>', _updatePessoa)
    ..delete('/api/pessoas/<id>', _deletePessoa);

  await shelf_io.serve(handler, 'localhost', 8080);
}

shelf.Response _getPessoas(shelf.Request request) {
  // Implementar
}
```

### 2. Iniciar Server na Main
```dart
void main() async {
  // Iniciar servidor em thread separada
  Isolate.spawn(startApiServer);
  
  // Iniciar app UI
  runApp(const ColetaRetaguardaApp());
}
```

### 3. Atualizar SyncService
```dart
// Mudar para localhost:8080
final response = await _apiClient.post(endpoint, body: dados);
```

### 4. Adicionar Dependências
```yaml
dependencies:
  shelf: ^1.4.0
  shelf_router: ^1.1.0
```

---

## ⚠️ Problemas do SyncService Atual

### 1. Endpoint Inválido
```dart
// Tenta enviar para /coleta/pessoas mas:
// - Backend Delphi não tem esse endpoint
// - Flutter retaguarda não expõe servidor
// → FALHA GARANTIDA
```

### 2. BaseURL Incorreta
```dart
// lib/core/api/http_client.dart:72
_baseUrl = 'http://localhost:3000';  // ❌ Horse usa 9000 ou outro

// Deveria ser:
_baseUrl = 'http://localhost:8080';  // Para servidor Flutter
```

### 3. Bearer Token não Salvo
```dart
// SyncService não armazena token após login
// Todas as requisições vão falhar (401 Unauthorized)
```

---

## 📊 Checklist: O Que Implementar

### Se Seguir Opção 1 (Recomendado)
- [ ] Remover SyncService (desnecessário)
- [ ] Configurar mobile para acessar Firebird remoto
- [ ] Implementar lock de dados (versioning)
- [ ] Testes de concorrência

### Se Seguir Opção 2 (Complexo)
- [ ] Adicionar `shelf` ao pubspec.yaml
- [ ] Implementar servidor Dart isolado
- [ ] Criar endpoints REST
- [ ] Integrar com banco de dados
- [ ] Testes de servidor
- [ ] Documenta endpoints

### Se Seguir Opção 3 (Melhor Prática)
- [ ] Confirmar que Backend Delphi está rodando
- [ ] Integrar Flutter com endpoints Delphi
- [ ] Mobile usa endpoints Delphi também
- [ ] Documentar endpoints

---

## 🎯 Próximas Ações

### Imediato (Esta Semana)
1. **Decidir qual opção usar**
   - Opção 1: Firebird compartilhado (mais simples)
   - Opção 2: Servidor HTTP em Flutter (mais complexo)
   - Opção 3: Backend Delphi (mais robusto)

2. **Desabilitar SyncService temporariamente**
   - Comentar chamadas a `syncPendingItems()`
   - Testes locais funcionarem sem API

3. **Verificar conectividade Firebird**
   - Desktop consegue conectar?
   - Mobile conseguiria?

### Depois (Próximas 2 Semanas)
- Implementar solução escolhida
- Testes end-to-end
- Documentar fluxo de sincronização

---

## 📝 Conclusão

**Situação Atual:**
- ❌ SyncService está órfão (endpoints não existem)
- ❌ Servidor HTTP não implementado
- ❌ Mobile não tem como se conectar

**Recomendação:**
- ✅ Use Firebird compartilhado (mais simples)
- ✅ Remova SyncService
- ✅ Ambos (desktop e mobile) acessam mesmo banco

**Prazo para decisão:** Antes de continuar desenvolvimento

---

**Status:** ⚠️ **Bloqueado - Aguardando decisão sobre modelo de sincronização**
