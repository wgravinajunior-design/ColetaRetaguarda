# 🧪 Teste Prático do Backend Integrado

**Versão:** 1.18.0+  
**Data:** 15 de julho de 2026

---

## 🚀 Pré-requisitos

- Flutter Desktop rodando em Windows/Linux/Mac
- Banco Firebird acessível
- Usuário `1` com senha `admin123` na tabela `TB_USUARIO`
- Cliente HTTP: `curl`, `Postman`, ou semelhante

---

## 1️⃣ Iniciar o Servidor

### Opção A: Compilar e rodar
```bash
cd flutter_retaguarda
flutter run -d windows  # ou linux, macos
```

### Opção B: Verificar se está rodando
```bash
curl http://localhost:8080/health
```

**Resposta esperada:**
```json
{
  "status": "ok",
  "server": "Coleta Retaguarda"
}
```

---

## 2️⃣ Testar Autenticação (Login)

```bash
curl -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{"login":"1","senha":"admin123"}'
```

**Resposta (200 OK):**
```json
{
  "success": true,
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwibmFtZSI6IkFkbWluaXN0cmFkb3IiLCJwZXJmaWwiOiJBRE1JTiIsImlhdCI6MTcyNjM1MDAwMCwiZXhwIjoxNzI2NDM2NDAwfQ.s7kq9G8h3K0...",
  "id": "1",
  "nome": "Administrador",
  "perfil": "ADMIN"
}
```

**Salve o token para próximas requisições:**
```bash
TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

---

## 3️⃣ Testar GET (Listar Pessoas)

```bash
curl http://localhost:8080/coleta/pessoas \
  -H "Authorization: Bearer $TOKEN"
```

**Resposta esperada:**
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

### Verificar Cache
```bash
# 1ª chamada: X-Cache: MISS
curl -i http://localhost:8080/coleta/pessoas \
  -H "Authorization: Bearer $TOKEN" 2>/dev/null | grep X-Cache

# 2ª chamada: X-Cache: HIT (mais rápido!)
curl -i http://localhost:8080/coleta/pessoas \
  -H "Authorization: Bearer $TOKEN" 2>/dev/null | grep X-Cache
```

---

## 4️⃣ Testar Compressão Gzip

```bash
# Sem compressão
time curl http://localhost:8080/coleta/pessoas \
  -H "Authorization: Bearer $TOKEN" > /tmp/sem_gzip.json 2>&1

# Com compressão
time curl -H "Accept-Encoding: gzip" \
  http://localhost:8080/coleta/pessoas \
  -H "Authorization: Bearer $TOKEN" > /tmp/com_gzip.json 2>&1

# Comparar tamanhos
ls -lh /tmp/*.json
```

**Resultado esperado:**
- Sem gzip: 1KB → 1000 bytes
- Com gzip: 1KB → 200-300 bytes (70% redução)

---

## 5️⃣ Testar Rate Limiting

### Script para bloquear IP
```bash
#!/bin/bash
echo "Testando rate limiting (5 req/min)..."

for i in {1..10}; do
  echo -n "Requisição $i: "
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health)
  echo "HTTP $STATUS"
  
  if [ "$STATUS" = "429" ]; then
    echo "✓ Bloqueado (esperado após 5 tentativas)"
    break
  fi
  
  sleep 0.2
done
```

**Resposta após 5 requisições:**
```json
{
  "error": "Muitas tentativas. Tente novamente em 15 minutos.",
  "success": false
}
```

---

## 6️⃣ Testar POST (Criar Pessoa)

```bash
curl -X POST http://localhost:8080/coleta/pessoas \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "nome": "Novo Produtor XYZ",
    "endereco": "Rua das Acácias, 456",
    "latitude": -20.8,
    "longitude": -45.6,
    "volume_medio": 200.0,
    "hr_coleta": "07:00",
    "km": 30.0
  }'
```

**Resposta esperada (201 Created):**
```json
{
  "success": true,
  "id": 2
}
```

---

## 7️⃣ Testar PUT (Atualizar Pessoa)

```bash
curl -X PUT http://localhost:8080/coleta/pessoas/2 \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "nome": "Produtor Atualizado",
    "endereco": "Nova rua, 789",
    "latitude": -20.9,
    "longitude": -45.7,
    "volume_medio": 250.0,
    "hr_coleta": "08:00",
    "km": 35.0
  }'
```

**Resposta esperada (200 OK):**
```json
{
  "success": true
}
```

---

## 8️⃣ Testar DELETE (Deletar Pessoa)

```bash
curl -X DELETE http://localhost:8080/coleta/pessoas/2 \
  -H "Authorization: Bearer $TOKEN"
```

**Resposta esperada (200 OK):**
```json
{
  "success": true
}
```

---

## 9️⃣ Testar Erros

### Token Inválido
```bash
curl http://localhost:8080/coleta/pessoas \
  -H "Authorization: Bearer INVALID_TOKEN"
```

**Resposta (401 Unauthorized):**
```json
{
  "error": "Token inválido ou expirado",
  "success": false
}
```

### Sem Token
```bash
curl http://localhost:8080/coleta/pessoas
```

**Resposta (401 Unauthorized):**
```json
{
  "error": "Token inválido ou expirado",
  "success": false
}
```

### ID Inválido
```bash
curl -X DELETE http://localhost:8080/coleta/pessoas/abc \
  -H "Authorization: Bearer $TOKEN"
```

**Resposta (400 Bad Request):**
```json
{
  "error": "ID inválido",
  "success": false
}
```

---

## 🔟 Testar CORS (Mobile)

Simule requisição cross-origin:

```bash
curl -X OPTIONS http://localhost:8080/coleta/pessoas \
  -H "Origin: http://mobile-app" \
  -v
```

**Headers esperados:**
```
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS
Access-Control-Allow-Headers: Content-Type, Authorization
```

---

## 📊 Métricas de Performance

### Criar script de teste
```bash
#!/bin/bash
echo "Performance Test - Backend Integrado"

# 1. GET (com cache)
echo -n "GET /coleta/pessoas (cache): "
time curl -s http://localhost:8080/coleta/pessoas \
  -H "Authorization: Bearer $TOKEN" > /dev/null

# 2. POST (sem cache)
echo -n "POST /coleta/pessoas: "
time curl -s -X POST http://localhost:8080/coleta/pessoas \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"nome":"Test","endereco":"Rua X",...}' > /dev/null

# 3. Compressão
echo -n "GET com gzip: "
time curl -s -H "Accept-Encoding: gzip" \
  http://localhost:8080/coleta/pessoas \
  -H "Authorization: Bearer $TOKEN" > /dev/null
```

---

## ✅ Checklist de Validação

- [ ] Health check retorna 200 OK
- [ ] Login retorna token válido
- [ ] GET retorna dados com X-Cache: MISS
- [ ] GET cache hit: X-Cache: HIT
- [ ] POST cria nova pessoa com ID
- [ ] PUT atualiza pessoa existente
- [ ] DELETE marca pessoa como inativa
- [ ] Rate limiting bloqueia após 5 req/min
- [ ] Compressão reduz 70% tráfego
- [ ] CORS headers presentes
- [ ] Sem token → 401 Unauthorized
- [ ] Token expirado → 401 Unauthorized
- [ ] ID inválido → 400 Bad Request

---

## 🚨 Troubleshooting

### "Connection refused"
```bash
# Verificar se servidor está rodando
curl http://localhost:8080/health

# Conferir porta
netstat -an | grep 8080
```

### "Token inválido"
- Renove token: `curl -X POST ... /auth/login`
- Verifique payload JWT: online JWT decoder

### "Rate limit bloqueado"
- Aguarde 15 minutos ou
- Use VPN/proxy diferente (novo IP)

### "Cache não funciona"
- Apenas GET é cacheado
- Cache válido 5 minutos
- Modifique `_cacheDuration` para testar

---

## 📞 Próximas Etapas

1. ✅ Backend funcionando
2. ✅ Rate limiting ativo
3. ✅ Compressão ativa
4. ✅ Cache ativo
5. ⏳ Testar mobile sync
6. ⏳ Testar E2E

---

**Bom teste! 🎉**

---

**Versão:** 1.18.0+  
**Data:** 15 de julho de 2026  
**Status:** ✅ Pronto para testar
