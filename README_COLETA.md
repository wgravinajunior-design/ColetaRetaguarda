# ColetaUp - v1.3.1 📱🌾

**Sistema Mobile Offline-First de Coleta de Leite com Geolocalização e Mapas**

---

## 🎯 Como Usar a Coleta

### 1️⃣ Menu → Coleta (🌾)
Clique no menu lateral em **Coleta**

### 2️⃣ Selecione uma Rota
Lista de rotas disponíveis com quantidade de paradas

### 3️⃣ Clique "Coletar" 
Abre tela com lista de todas as paradas

### 4️⃣ Estados de Parada:
- 🔴 **Pendente** - Ainda não visitada
- 🟡 **Em Andamento** - Coleta em progresso  
- 🟢 **Sucesso** - Coleta concluída
- ⚫ **Recusada** - Leite rejeitado

### 5️⃣ Clique em uma Parada (Fazenda)

#### Seção 1: Informações
- Nome do produtor
- CNPJ/CPF
- Endereço
- Coordenadas

#### Seção 2: Geolocalização (⭐ IMPORTANTE)
- **CLIQUE: "Capturar GPS Agora"**
- Registra coordenadas exatas
- Prova de presença no local
- Status: ✅ GPS Capturado (quando feito)

#### Seção 3: Dados de Coleta (Obrigatórios)
- **Temperatura (°C)** - Ex: 4.5
- **Volume (L)** - Ex: 50.0
- Mini mapa mostrando localização

#### Seção 4: Justificativa (Se Recusar)
- Motivo: "Temperatura alta", "Alizarol positivo", etc

### 6️⃣ Escolha Ação:

#### ✅ SUCESSO (🟢 Verde)
- ✔️ GPS capturado
- ✔️ Temperatura preenchida
- ✔️ Volume preenchido
- → Parada muda para 🟢

#### ❌ RECUSAR (⚫ Cinza)
- ✔️ Justificativa preenchida (obrigatória)
- → Parada muda para ⚫

---

## 🗺️ Ver Mapa da Rota

Na tela com lista de paradas:
- Clique ícone **🗺️** (top direita)
- Visualize todas as paradas:
  - 🔴 Pendentes
  - 🟡 Em Andamento
  - 🟢 Concluídas  
  - ⚫ Recusadas
- Clique marcador → Veja detalhes

---

## 📊 Indicadores Top

- **🟢 Sincronizado**: Dados enviados ✅
- **🟡 X Pendentes**: Aguardando sincronização ⏳
- **🔴 Offline**: Sem conexão (funciona localmente) 📱

---

## ⚠️ Checklist de Coleta

- [ ] GPS capturado (botão ✅)
- [ ] Temperatura inserida
- [ ] Volume inserido
- [ ] Justificativa (se recusar)
- [ ] Status do parada: 🟢 ou ⚫
- [ ] Parada anterior OK antes de avançar

---

**Desenvolvido por Go Up Sistemas**  
v1.3.1+5 | 2026-07-14
