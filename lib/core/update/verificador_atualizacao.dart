import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../app_info.dart';
import 'update_dialogs.dart';
import 'update_service.dart';

/// Uma vez por execução do sistema.
bool _jaRodou = false;

/// Na abertura: mostra as novidades da versão recém instalada e, em seguida,
/// avisa se há uma versão mais nova.
///
/// Chame de uma tela — a de login — e não do `builder` do `MaterialApp`.
/// Ali o contexto fica **acima** do Navigator (o `child` do builder é o próprio
/// Navigator), então `showDialog` não encontra a quem se pendurar e falha em
/// silêncio: era por isso que o aviso de atualização nunca aparecia.
Future<void> verificarAtualizacaoAoAbrir(BuildContext context) async {
  if (_jaRodou) return;
  _jaRodou = true;

  try {
    // Acabou de atualizar? O arquivo guarda a versão anterior; se ela existe
    // e difere da atual, é a deixa para exibir as melhorias.
    final anterior = await UpdateService.versaoVista();
    if (anterior == null) {
      // Primeira execução: só registra, sem popup de novidades.
      await UpdateService.marcarVersaoVista(appVersao);
    } else if (anterior != appVersao) {
      final notas = await UpdateService.notasDaVersaoAtual();
      await UpdateService.marcarVersaoVista(appVersao);
      if (context.mounted && notas != null && notas.trim().isNotEmpty) {
        await DialogoNovidades.mostrar(context, notas);
      }
    }

    if (!context.mounted) return;
    final nova = await UpdateService.verificar();
    if (!context.mounted || nova == null) return;
    await DialogoAtualizacao.mostrar(context, nova);
  } catch (e, s) {
    // Uma falha aqui não pode impedir o uso do sistema — mas precisa aparecer
    // no log, senão some sem deixar rastro, como aconteceu antes.
    debugPrint('Falha ao verificar atualização: $e\n$s');
  }
}
