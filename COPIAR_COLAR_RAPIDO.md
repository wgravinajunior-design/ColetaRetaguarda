# ⚡ COPIAR & COLAR RÁPIDO

**Trechos prontos para copiar e colar nas suas telas**

---

## 1️⃣ ADICIONAR SYNCSTATUSBAR (Copiar em main.dart)

```dart
// Adicione ao body do seu Scaffold:

import '../features/coleta/widgets/sync_status_bar.dart';

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text('App')),
    body: Column(
      children: [
        const SyncStatusBar(),  // ← COPIE ESTA LINHA
        Expanded(
          child: // seu conteúdo existente
        ),
      ],
    ),
  );
}
```

---

## 2️⃣ ADICIONAR CONTADOR DE PENDING (Copiar em AppBar)

```dart
// No AppBar, adicione em actions:

AppBar(
  title: const Text('Coleta'),
  actions: [
    Consumer<ColetaViewModel>(
      builder: (context, viewModel, _) {
        return FutureBuilder<int>(
          future: viewModel.getPendingCount(),
          builder: (context, snapshot) {
            final count = snapshot.data ?? 0;
            return Badge(
              label: Text('$count'),
              isLabelVisible: count > 0,
              child: IconButton(
                icon: const Icon(Icons.cloud_upload),
                onPressed: count > 0 ? () {
                  // Sincronizar manualmente
                  context.read<ColetaViewModel>()._syncService.syncPendingItems();
                } : null,
              ),
            );
          },
        );
      },
    ),
  ],
)
```

---

## 3️⃣ ADICIONAR HISTÓRICO NO MENU

```dart
// 1. Adicione a rota (em seu main.dart ou routes.dart):

import 'features/coleta/screens/historico_coletas_screen.dart';
import 'features/coleta/viewmodels/historico_viewmodel.dart';

GoRoute(
  path: 'coleta/historico',
  builder: (context, state) => ChangeNotifierProvider(
    create: (_) => HistoricoViewModel(),
    child: const HistoricoColetasScreen(),
  ),
),

// 2. Adicione botão no menu:

ListTile(
  leading: const Icon(Icons.history),
  title: const Text('Histórico'),
  onTap: () => context.go('/coleta/historico'),
),
```

---

## 4️⃣ ADICIONAR MÚLTIPLAS FOTOS (Copiar em coleta_parada_screen)

```dart
// 1. Importe no topo:
import '../viewmodels/camera_viewmodel.dart';
import '../widgets/foto_carrossel.dart';

// 2. Adicione ao seu StatefulWidget:
class ColetaParadaScreen extends StatefulWidget {
  @override
  State<ColetaParadaScreen> createState() => _State();
}

class _State extends State<ColetaParadaScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChangeNotifierProvider(
        create: (_) => CameraViewModel(),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Sua UI existente...
              
              // ← ADICIONE AQUI:
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('📸 Fotos', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Consumer<CameraViewModel>(
                        builder: (context, cameraViewModel, _) {
                          return FotoCarrossel(
                            onUpload: () async {
                              final ok = await cameraViewModel
                                .uploadTodasFotos(widget.parada.id!);
                              if (ok && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('✅ Enviado')),
                                );
                              }
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

## 5️⃣ ADICIONAR DIALOG REJEIÇÃO (Copiar no botão Rejeitar)

```dart
// Importe no topo:
import '../dialogs/rejeitar_parada_dialog.dart';

// Copie para seu botão:
ElevatedButton.icon(
  icon: const Icon(Icons.close),
  label: const Text('Rejeitar'),
  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
  onPressed: () async {
    final resultado = await mostrarDialogRejeicao(
      context,
      parada: widget.parada,
      onRejeitar: (motivo, justificativa) {
        context.read<ColetaViewModel>().recusarColeta(
          parada: widget.parada,
          justificativa: justificativa,
        );
        Navigator.pop(context, true);
      },
    );
  },
)
```

---

## 6️⃣ ADICIONAR COMPROVANTE (Copiar no botão Ver)

```dart
// Importe no topo:
import '../../core/services/comprovante_pdf_service.dart';

// Copie para seu botão:
ElevatedButton.icon(
  icon: const Icon(Icons.receipt),
  label: const Text('Comprovante'),
  onPressed: () {
    final comprovante = ComprovantePdfService.gerarComprovanteTexto(parada);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('📄 Comprovante'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: SelectableText(comprovante),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('Salvar'),
            onPressed: () async {
              final file = await ComprovantePdfService.salvarComprovante(parada);
              if (file != null && mounted) {
                Navigator.pop(ctx);
                NotificationToast.show('✅ Salvo');
              }
            },
          ),
        ],
      ),
    );
  },
)
```

---

## 7️⃣ ENABLE CAMERA VIEWMODEL (Copiar em main.dart)

```dart
// Importe no topo de main.dart:
import 'features/coleta/viewmodels/camera_viewmodel.dart';

// Adicione no MultiProvider do seu app:
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => ColetaViewModel()),
    ChangeNotifierProvider(create: (_) => HistoricoViewModel()),
    ChangeNotifierProvider(create: (_) => CameraViewModel()),  // ← ADD ESTA LINHA
    // seus outros providers...
  ],
  child: MaterialApp(...),
)
```

---

## 8️⃣ PUBSPEC.YAML (Copiar dependências)

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Já existem:
  image: ^4.1.0
  intl: ^0.19.0
  provider: ^6.0.0
  http: ^1.1.0
  shared_preferences: ^2.2.0
  
  # Verificar se tá tudo OK acima ^^
```

**Executar depois:**
```bash
flutter pub get
```

---

## 9️⃣ VERIFICAÇÃO RÁPIDA

Após implementar, rode:

```bash
# 1. Limpar
flutter clean

# 2. Atualizar dependências
flutter pub get

# 3. Compilar (vai achar erros de import se houver)
flutter run -d windows

# 4. Se compilou OK:
echo "✅ Tudo funcionando!"
```

---

## 🎯 ORDEM DE IMPLEMENTAÇÃO RECOMENDADA

**Dia 1 - Morning (2h):**
```
1. ✅ Adicionar SyncStatusBar
2. ✅ Adicionar Counter de Pending
3. ✅ Compilar e testar
```

**Dia 1 - Afternoon (2h):**
```
4. ✅ Adicionar Histórico ao Menu
5. ✅ Testar Histórico funciona
```

**Dia 2 - Morning (2h):**
```
6. ✅ Adicionar Múltiplas Fotos
7. ✅ Testar upload funciona
```

**Dia 2 - Afternoon (2h):**
```
8. ✅ Adicionar Dialog Rejeição
9. ✅ Adicionar Comprovante
10. ✅ Testar tudo integrado
```

**Dia 3 - Morning (1h):**
```
11. ✅ Testes offline/online
12. ✅ Testes múltiplas paradas
13. ✅ Go live!
```

---

## 🔴 ERROS COMUNS

### Erro: "SyncStatusBar não encontrado"
```
Solução: Verificar importação
import '../features/coleta/widgets/sync_status_bar.dart';
```

### Erro: "CameraViewModel não encontrado"
```
Solução: Adicionar no MultiProvider de main.dart
ChangeNotifierProvider(create: (_) => CameraViewModel()),
```

### Erro: "Photo não comprime"
```
Solução: Verificar pubspec.yaml
image: ^4.1.0
```

### Erro: "Histórico não mostra dados"
```
Solução: Certificar que HistoricoViewModel carregou
initState() → loadHoje()
```

---

## ✅ TESTE FINAL

**Checklist antes de produção:**

```
Desktop (Windows):
  ✅ Compilação OK
  ✅ SyncStatusBar visível
  ✅ Counter de pending funciona
  ✅ Histórico carrega
  ✅ Múltiplas fotos funcionam
  ✅ Rejeição com motivo salva
  ✅ Comprovante exibe/salva
  ✅ Offline → Online sync OK

Mobile (se tiver):
  ✅ Foto comprime até 2MB
  ✅ Upload com retry OK
  ✅ GPS valida proximidade
  ✅ Assinatura captura OK

User Acceptance:
  ✅ Supervisor aprova
  ✅ Motorista consegue usar
  ✅ Produtor satisfeito com comprovante
```

---

## 🎊 PRONTO!

Quando tudo compilar e funcionar:
```
✅ Sistema Coleta v1.22.0+ está pronto!
✅ Todos os extras implementados
✅ Documentação completa
✅ Pronto para produção
```

**Go live!** 🚀

---

**Última atualização:** 15 de julho 2026  
**Versão:** 1.22.0+  
**Status:** ✅ PRONTO PARA COPIAR E COLAR
