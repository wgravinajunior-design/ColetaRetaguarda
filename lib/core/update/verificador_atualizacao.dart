import 'package:flutter/material.dart';
import '../app_info.dart';
import 'update_dialogs.dart';
import 'update_service.dart';

/// Roda uma vez na abertura do sistema: mostra as novidades da versão recém
/// instalada e, em seguida, avisa se há uma versão mais nova.
///
/// Envolve a árvore de telas para ter um `BuildContext` sob o `MaterialApp`,
/// já que ambos abrem diálogos.
class VerificadorAtualizacao extends StatefulWidget {
  const VerificadorAtualizacao({required this.child, super.key});

  final Widget child;

  @override
  State<VerificadorAtualizacao> createState() => _VerificadorAtualizacaoState();
}

class _VerificadorAtualizacaoState extends State<VerificadorAtualizacao> {
  /// Sem isto, cada reconstrução do `builder` do MaterialApp dispararia a
  /// checagem de novo.
  static bool _jaRodou = false;

  @override
  void initState() {
    super.initState();
    if (_jaRodou) return;
    _jaRodou = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _rodar());
  }

  Future<void> _rodar() async {
    await _mostrarNovidadesSeAtualizou();
    if (mounted) await _verificarNovaVersao();
  }

  /// O arquivo guarda a versão anterior. Se ela existe e é diferente da atual,
  /// acabamos de atualizar — é a deixa para exibir as melhorias.
  Future<void> _mostrarNovidadesSeAtualizou() async {
    final anterior = await UpdateService.versaoVista();
    if (anterior == null) {
      // Primeira execução: só registra, sem popup de novidades.
      await UpdateService.marcarVersaoVista(appVersao);
      return;
    }
    if (anterior == appVersao) return;

    final notas = await UpdateService.notasDaVersaoAtual();
    await UpdateService.marcarVersaoVista(appVersao);
    if (!mounted || notas == null || notas.trim().isEmpty) return;
    await DialogoNovidades.mostrar(context, notas);
  }

  Future<void> _verificarNovaVersao() async {
    final nova = await UpdateService.verificar();
    if (!mounted || nova == null) return;
    await DialogoAtualizacao.mostrar(context, nova);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
