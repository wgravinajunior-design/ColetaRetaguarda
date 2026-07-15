# 📚 Documentação Completa de Endpoints - Backend Integrado

**Versão:** 1.17.0+  
**Porta:** 8080  
**Base URL:** `http://localhost:8080` ou `http://<IP>:8080` para mobile

---

## 🔐 Autenticação

Todos os endpoints (exceto `/auth/login` e `/health`) requerem um **Bearer Token** no header `Authorization`.

### Obter Token

**Endpoint:** `POST /auth/login`

**Headers:**
```
Content-Type: application/json
```

**Body:**
```json
{
  "login": "1",
  "senha": "admin123"
}
```

**Resposta (200 OK):**
```json
{
  "success": true,
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "id": "1",
  "nome": "Administrador",
  "perfil": "ADMIN"
}
```

**Resposta (401 Unauthorized):**
```json
{
  "error": "Credenciais inválidas",
  "success": false
}
```

### Usar Token em Requisições

```bash
curl -H "Authorization: Bearer <token>" http://localhost:8080/coleta/pessoas
```

### Informações do Token

- **Tipo:** JWT (HS256)
- **Expiração:** 24 horas
- **Refresh:** Fazer novo login
- **Claims:** `sub` (ID), `name` (nome), `perfil` (perfil), `iat` (emissão), `exp` (expiração)

---

## 🏥 Health Check

### Endpoint: `GET /health`

Verifica se o servidor está funcionando.

**Resposta (200 OK):**
```json
{
  "status": "ok",
  "server": "Coleta Retaguarda"
}
```

---

## 👥 Pessoas (Produtores)

### Listar Pessoas

**Endpoint:** `GET /coleta/pessoas`

**Headers:**
```
Authorization: Bearer <token>
```

**Resposta (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "nome": "Laticínio ABC",
      "endereco": "Rua das Flores, 123",
      "latitude": -20.5,
      "longitude": -45.3,
      "volume_medio": 150.5,
      "hr_coleta": "06:00",
      "km": 25.5,
      "status": "ATIVO"
    }
  ]
}
```

**Resposta (401 Unauthorized):**
```json
{
  "error": "Token inválido ou expirado",
  "success": false
}
```

---

### Criar Pessoa

**Endpoint:** `POST /coleta/pessoas`

**Headers:**
```
Content-Type: application/json
Authorization: Bearer <token>
```

**Body:**
```json
{
  "nome": "Novo Produtor",
  "endereco": "Rua X, 456",
  "latitude": -20.8,
  "longitude": -45.6,
  "volume_medio": 200.0,
  "hr_coleta": "07:00",
  "km": 30.0
}
```

**Resposta (201 Created):**
```json
{
  "success": true,
  "id": 2
}
```

**Resposta (400 Bad Request):**
```json
{
  "error": "Campo obrigatório faltando",
  "success": false
}
```

---

### Atualizar Pessoa

**Endpoint:** `PUT /coleta/pessoas/:id`

**Headers:**
```
Content-Type: application/json
Authorization: Bearer <token>
```

**Body:**
```json
{
  "nome": "Produtor Atualizado",
  "endereco": "Rua Y, 789",
  "latitude": -20.9,
  "longitude": -45.7,
  "volume_medio": 250.0,
  "hr_coleta": "08:00",
  "km": 35.0
}
```

**Resposta (200 OK):**
```json
{
  "success": true
}
```

---

### Deletar Pessoa

**Endpoint:** `DELETE /coleta/pessoas/:id`

**Headers:**
```
Authorization: Bearer <token>
```

**Resposta (200 OK):**
```json
{
  "success": true
}
```

---

## 🚗 Motoristas

### Listar Motoristas

**Endpoint:** `GET /coleta/motoristas`

**Resposta (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "nome": "João Silva",
      "endereco": "Rua A, 100",
      "latitude": -20.5,
      "longitude": -45.3,
      "status": "ATIVO"
    }
  ]
}
```

---

### Criar Motorista

**Endpoint:** `POST /coleta/motoristas`

**Headers:**
```
Content-Type: application/json
Authorization: Bearer <token>
```

**Body:**
```json
{
  "nome": "Maria Santos",
  "endereco": "Rua B, 200",
  "latitude": -20.6,
  "longitude": -45.4
}
```

**Resposta (201 Created):**
```json
{
  "success": true,
  "id": 2
}
```

---

### Atualizar Motorista

**Endpoint:** `PUT /coleta/motoristas/:id`

**Body:**
```json
{
  "nome": "Maria Santos Atualizado",
  "endereco": "Rua C, 300",
  "latitude": -20.7,
  "longitude": -45.5
}
```

**Resposta (200 OK):**
```json
{
  "success": true
}
```

---

### Deletar Motorista

**Endpoint:** `DELETE /coleta/motoristas/:id`

**Resposta (200 OK):**
```json
{
  "success": true
}
```

---

## 🚙 Veículos

### Listar Veículos

**Endpoint:** `GET /coleta/veiculos`

**Resposta (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "placa": "ABC1234",
      "descricao": "Caminhão Tanque 1",
      "status": "ATIVO"
    }
  ]
}
```

---

### Criar Veículo

**Endpoint:** `POST /coleta/veiculos`

**Body:**
```json
{
  "placa": "XYZ5678",
  "descricao": "Caminhão Tanque 2"
}
```

**Resposta (201 Created):**
```json
{
  "success": true,
  "id": 2
}
```

---

### Atualizar Veículo

**Endpoint:** `PUT /coleta/veiculos/:id`

**Body:**
```json
{
  "placa": "XYZ9999",
  "descricao": "Caminhão Tanque 2 Atualizado"
}
```

---

### Deletar Veículo

**Endpoint:** `DELETE /coleta/veiculos/:id`

---

## 🗺️ Rotas

### Listar Rotas

**Endpoint:** `GET /coleta/rotas`

**Resposta (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "descricao": "Rota Sul",
      "km": 150.5,
      "status": "ATIVO"
    }
  ]
}
```

---

### Criar Rota

**Endpoint:** `POST /coleta/rotas`

**Body:**
```json
{
  "descricao": "Rota Norte",
  "km": 200.0
}
```

**Resposta (201 Created):**
```json
{
  "success": true,
  "id": 2
}
```

---

### Atualizar Rota

**Endpoint:** `PUT /coleta/rotas/:id`

**Body:**
```json
{
  "descricao": "Rota Centro",
  "km": 175.5
}
```

---

### Deletar Rota

**Endpoint:** `DELETE /coleta/rotas/:id`

---

## 🔧 Tratamento de Erros

### Erro 400 - Bad Request

```json
{
  "error": "ID inválido",
  "success": false
}
```

### Erro 401 - Unauthorized

```json
{
  "error": "Token inválido ou expirado",
  "success": false
}
```

### Erro 500 - Internal Server Error

```json
{
  "error": "Erro ao listar pessoas: <detalhes>",
  "success": false
}
```

---

## 📡 CORS

Todos os endpoints têm CORS habilitado:

```
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS
Access-Control-Allow-Headers: Content-Type, Authorization
```

---

## 🧪 Exemplos com cURL

### Login
```bash
curl -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{"login":"1","senha":"admin123"}'
```

### Listar Pessoas
```bash
curl http://localhost:8080/coleta/pessoas \
  -H "Authorization: Bearer eyJhbGc..."
```

### Criar Pessoa
```bash
curl -X POST http://localhost:8080/coleta/pessoas \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer eyJhbGc..." \
  -d '{
    "nome":"Produtor Novo",
    "endereco":"Rua X",
    "latitude":-20.5,
    "longitude":-45.3,
    "volume_medio":100,
    "hr_coleta":"06:00",
    "km":25
  }'
```

### Atualizar Pessoa
```bash
curl -X PUT http://localhost:8080/coleta/pessoas/1 \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer eyJhbGc..." \
  -d '{"nome":"Atualizado"}'
```

### Deletar Pessoa
```bash
curl -X DELETE http://localhost:8080/coleta/pessoas/1 \
  -H "Authorization: Bearer eyJhbGc..."
```

---

## 📝 Notas

### JWT Token
- **Expiração:** 24 horas após emissão
- **Algoritmo:** HS256
- **Formato:** 3 partes separadas por ponto (header.payload.signature)

### Status Codes
- **200:** Sucesso (GET, PUT, DELETE)
- **201:** Criado com sucesso (POST)
- **400:** Requisição inválida
- **401:** Não autenticado ou token expirado
- **500:** Erro do servidor

### Campos Obrigatórios
- **Pessoas:** nome, endereco
- **Motoristas:** nome, endereco
- **Veículos:** placa, descricao
- **Rotas:** descricao

---

## 🚀 Guia Rápido de Uso

1. **Fazer Login**
   ```bash
   curl -X POST http://localhost:8080/auth/login \
     -H "Content-Type: application/json" \
     -d '{"login":"1","senha":"admin123"}'
   ```

2. **Copiar token da resposta**

3. **Usar em requisições**
   ```bash
   curl http://localhost:8080/coleta/pessoas \
     -H "Authorization: Bearer <TOKEN_AQUI>"
   ```

---

**Última atualização:** 14 de julho de 2026
