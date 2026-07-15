# 🔗 COMO INTEGRAR OS EXTRAS NAS TELAS

**Data:** 15 de julho de 2026  
**Versão:** 1.22.0+

---

## 📋 CHECKLIST DE INTEGRAÇÃO

- [ ] 1. Atualizar pubspec.yaml (dependências)
- [ ] 2. Adicionar SyncStatusBar em telas principais
- [ ] 3. Integrar HistoricoColetasScreen no menu
- [ ] 4. Adicionar CameraViewModel em parada_screen
- [ ] 5. Integrar RejeitarParadaDialog
- [ ] 6. Adicionar ComprovantePdfService
- [ ] 7. Testar tudo compilando

---

## 1️⃣ ATUALIZAR PUBSPEC.YAML

**Adicionar dependências para extras:**

```yaml
dependencies:
  # Já existente:
  flutter:
  image: ^4.1.0
  intl: ^0.19.0
  provider: ^6.0.0
  http: ^1.1.0
  shared_preferences: ^2.2.0

  # Novo para compressão de imagem:
  image: ^4.1.0  # Já existe, confirmar versão

dev_dependencies:
  flutter_test:
    sdk: flutter
```

**Executar:**
```bash
flutter pub get
```

---

## 2️⃣ ADICIONAR SYNCSTATUSBAR NAS TELAS PRINCIPAIS

### Na tela de Coleta (coleta_rota_list_screen.dart):

```dart
import 'package:provider/provider.dart';
import '../widgets/sync_status_bar.dart';  // NEW

class ColetaRotaListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coleta')),
      body: Column(
        children: [
          const SyncStatusBar(),  // ← ADD AQUI
          Expanded(
            child: // seu conteúdo existente
          ),
        ],
      ),
    );
  }
}
```

### Na tela principal (main_screen.dart ou similar):

```dart
class MainScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Coleta'),
        actions: [
          // Adicionar contador de pending items
          Consumer<ColetaViewModel>(
            builder: (context, viewModel, _) {
              return FutureBuilder<int>(
                future: viewModel.getPendingCount(),
                builder: (context, snapshot) {
                  final pendingCount = snapshot.data ?? 0;
                  if (pendingCount == 0) return const SizedBox();
                  
                  return Badge(
                    label: Text('$pendingCount'),
                    child: IconButton(
                      icon: const Icon(Icons.cloud_upload),
                      onPressed: () {
                        // Disparar sync manual
                        context.read<ColetaViewModel>()
                          ._syncService.syncPendingItems();
                      },
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const SyncStatusBar(),  // ← ADD NO TOPO
          Expanded(
            child: // seu conteúdo
          ),
        ],
      ),
    );
  }
}
```

---

## 3️⃣ INTEGRAR HISTÓRICO NO MENU

### Adicionar opção no menu de navegação:

```dart
// No seu arquivo de rotas ou menu

class ColetaMenu {
  static final items = [
    NavigationItem(
      icon: Icons.home,
      label: 'Coleta',
      route: '/coleta',
    ),
    NavigationItem(
      icon: Icons.history,  // NEW
      label: 'Histórico',
      route: '/coleta/historico',
    ),
    NavigationItem(
      icon: Icons.report,
      label: 'Relatório',
      route: '/coleta/relatorio',
    ),
  ];
}
```

### Adicionar rota:

```dart
// Em seu arquivo de rotas (main.dart ou config/routes.dart)

import 'package:provider/provider.dart';
import 'features/coleta/screens/historico_coletas_screen.dart';
import 'features/coleta/viewmodels/historico_viewmodel.dart';

GoRoute(
  path: 'historico',
  builder: (context, state) => ChangeNotifierProvider(
    create: (_) => HistoricoViewModel(),
    child: const HistoricoColetasScreen(),
  ),
),
```

---

## 4️⃣ ADICIONAR CÂMERA + MÚLTIPLAS FOTOS

### Em coleta_parada_screen.dart:

```dart
import 'package:provider/provider.dart';
import '../viewmodels/camera_viewmodel.dart';
import '../widgets/foto_carrossel.dart';

class ColetaParadaScreen extends StatefulWidget {
  final ParadaModel parada;

  const ColetaParadaScreen({required this.parada});

  @override
  State<ColetaParadaScreen> createState() => _ColetaParadaScreenState();
}

class _ColetaParadaScreenState extends State<ColetaParadaScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.parada.pessoaNome ?? 'Coleta')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Seção de fotos com carrossel
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📸 Fotos da Coleta',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Consumer<CameraViewModel>(
                        builder: (context, cameraViewModel, _) {
                          return FotoCarrossel(
                            onUpload: () async {
                              final sucesso = await cameraViewModel
                                .uploadTodasFotos(widget.parada.id!);
                              if (sucesso && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('✅ Fotos enviadas com sucesso'),
                                  ),
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
              const SizedBox(height: 16),

              // Seção de assinatura (já existe)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🔐 Assinatura',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      // seu SignatureController aqui
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Botões de ação
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.close),
                      label: const Text('Rejeitar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () => _mostrarDialogRejeicao(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('Concluir'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      onPressed: () => _finalizarColeta(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarDialogRejeicao() async {
    // Import necessário
    import 'dialogs/rejeitar_parada_dialog.dart';

    final resultado = await mostrarDialogRejeicao(
      context,
      parada: widget.parada,
      onRejeitar: (motivo, justificativa) {
        // Chamar repository para salvar rejeição
        context.read<ColetaViewModel>().recusarColeta(
          parada: widget.parada,
          justificativa: justificativa,
        );
      },
    );

    if (resultado != null && mounted) {
      Navigator.pop(context, true);
    }
  }

  void _finalizarColeta() async {
    // Lógica existente de finalização
  }
}
```

---

## 5️⃣ INTEGRAR DIALOG REJEIÇÃO

### Na tela de ação (adicionar botão):

```dart
// Em qualquer tela com menu de ações para parada

import '../dialogs/rejeitar_parada_dialog.dart';

// No widget de ação:
PopupMenuButton(
  itemBuilder: (context) => [
    PopupMenuItem(
      child: const Text('Concluir'),
      onTap: () => _finalizarColeta(),
    ),
    PopupMenuItem(
      child: const Text('Rejeitar'),
      onTap: () => _mostrarDialogRejeicao(),
    ),
  ],
)

Future<void> _mostrarDialogRejeicao() async {
  final resultado = await mostrarDialogRejeicao(
    context,
    parada: parada,
    onRejeitar: (motivo, justificativa) {
      viewModel.recusarColeta(
        parada: parada,
        justificativa: justificativa,
      );
    },
  );
}
```

---

## 6️⃣ ADICIONAR COMPROVANTE

### Adicionar botão para gerar/compartilhar comprovante:

```dart
import '../../core/services/comprovante_pdf_service.dart';

// Na tela de detalhes da coleta:

TextButton.icon(
  icon: const Icon(Icons.receipt),
  label: const Text('Comprovante'),
  onPressed: () => _mostrarComprovante(),
)

void _mostrarComprovante() {
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
          icon: const Icon(Icons.file_download),
          label: const Text('Salvar'),
          onPressed: () async {
            final file = await ComprovantePdfService.salvarComprovante(parada);
            if (file != null && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Salvo em: ${file.path}')),
              );
            }
          },
        ),
      ],
    ),
  );
}
```

---

## 7️⃣ EXEMPLO COMPLETO: PARADA SCREEN

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/parada_model.dart';
import '../viewmodels/coleta_viewmodel.dart';
import '../viewmodels/camera_viewmodel.dart';
import '../widgets/foto_carrossel.dart';
import '../widgets/sync_status_bar.dart';
import '../dialogs/rejeitar_parada_dialog.dart';
import '../../core/services/comprovante_pdf_service.dart';

class ColetaParadaScreenAtualizado extends StatefulWidget {
  final ParadaModel parada;

  const ColetaParadaScreenAtualizado({required this.parada});

  @override
  State<ColetaParadaScreenAtualizado> createState() =>
      _ColetaParadaScreenState();
}

class _ColetaParadaScreenState extends State<ColetaParadaScreenAtualizado> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.parada.pessoaNome ?? 'Coleta'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // ✅ Status bar de sincronização
          const SyncStatusBar(),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Info parada
                  _buildParadaCard(),
                  const SizedBox(height: 16),

                  // ✅ Múltiplas fotos com carrossel
                  _buildFotosSection(),
                  const SizedBox(height: 16),

                  // Assinatura
                  _buildAssinaturaSection(),
                  const SizedBox(height: 16),

                  // Botões de ação
                  _buildBottomActions(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParadaCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.parada.pessoaNome ?? 'Parada',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(widget.parada.endereco ?? ''),
            const SizedBox(height: 8),
            Text(widget.parada.cnpjCpf ?? ''),
          ],
        ),
      ),
    );
  }

  Widget _buildFotosSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📸 Fotos da Coleta',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Consumer<CameraViewModel>(
              builder: (context, cameraViewModel, _) {
                return FotoCarrossel(
                  onUpload: () async {
                    final sucesso =
                        await cameraViewModel.uploadTodasFotos(widget.parada.id!);
                    if (sucesso && mounted) {
                      NotificationToast.show('✅ Fotos enviadas!');
                    }
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssinaturaSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🔐 Assinatura',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            // seu SignatureController aqui
            Container(
              height: 200,
              color: Colors.grey.shade200,
              child: const Center(child: Text('Signature Widget')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.close),
                label: const Text('Rejeitar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                onPressed: _mostrarDialogRejeicao,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Concluir'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                onPressed: _finalizarColeta,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.receipt),
            label: const Text('Ver Comprovante'),
            onPressed: _mostrarComprovante,
          ),
        ),
      ],
    );
  }

  void _mostrarDialogRejeicao() async {
    await mostrarDialogRejeicao(
      context,
      parada: widget.parada,
      onRejeitar: (motivo, justificativa) {
        context.read<ColetaViewModel>().recusarColeta(
          parada: widget.parada,
          justificativa: justificativa,
        );
      },
    );
  }

  void _finalizarColeta() {
    // Lógica existente
  }

  void _mostrarComprovante() {
    final comprovante =
        ComprovantePdfService.gerarComprovanteTexto(widget.parada);

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
            icon: const Icon(Icons.file_download),
            label: const Text('Salvar'),
            onPressed: () async {
              final file =
                  await ComprovantePdfService.salvarComprovante(widget.parada);
              if (file != null && mounted) {
                Navigator.pop(ctx);
                NotificationToast.show('✅ Salvo: ${file.path}');
              }
            },
          ),
        ],
      ),
    );
  }
}
```

---

## ✅ CHECKLIST DE TESTE

- [ ] Compilar sem erros: `flutter run -d windows`
- [ ] Testar SyncStatusBar (offline/online)
- [ ] Testar histórico (filtros, CSV)
- [ ] Testar múltiplas fotos (upload, carrossel)
- [ ] Testar rejeição com motivo
- [ ] Testar comprovante (exibir, salvar)
- [ ] Testar indicador de sync
- [ ] Testar offline → online (auto-sync)

---

**Versão:** 1.22.0+  
**Data:** 15 de julho de 2026  
**Status:** ✅ GUIA COMPLETO DE INTEGRAÇÃO
