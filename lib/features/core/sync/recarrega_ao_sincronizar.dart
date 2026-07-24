import 'package:flutter/material.dart';
import 'sync_activity_service.dart';

/// Recarrega a tela sozinha quando o celular grava algo no ERP.
///
/// Envolva o corpo da tela e informe como recarregar:
///
/// ```dart
/// RecarregaAoSincronizar(
///   aoAlterar: () => viewModel.loadProdutores(),
///   child: ...,
/// )
/// ```
///
/// Observa [SyncActivityService.revisaoDados], que só muda em gravação
/// bem-sucedida vinda do mobile — leituras não disparam recarga. Antes disso
/// era preciso sair da tela e voltar, e mesmo assim o cache de 10 minutos dos
/// ViewModels podia devolver o valor antigo.
class RecarregaAoSincronizar extends StatefulWidget {
  const RecarregaAoSincronizar({
    required this.child,
    required this.aoAlterar,
    super.key,
  });

  final Widget child;
  final VoidCallback aoAlterar;

  @override
  State<RecarregaAoSincronizar> createState() => _RecarregaAoSincronizarState();
}

class _RecarregaAoSincronizarState extends State<RecarregaAoSincronizar> {
  final _service = SyncActivityService();
  late int _revisaoVista;

  @override
  void initState() {
    super.initState();
    _revisaoVista = _service.revisaoDados;
    _service.addListener(_aoMudar);
  }

  @override
  void dispose() {
    _service.removeListener(_aoMudar);
    super.dispose();
  }

  void _aoMudar() {
    if (!mounted) return;
    final atual = _service.revisaoDados;
    if (atual == _revisaoVista) return;
    _revisaoVista = atual;

    // Sai do ciclo de notificação antes de mexer no ViewModel, senão o
    // notifyListeners() da recarga acontece durante um build em andamento.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.aoAlterar();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
