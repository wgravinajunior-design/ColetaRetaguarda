import 'package:flutter/material.dart';
import '../app_info.dart';
import 'update_service.dart';

/// Renderiza o subconjunto de Markdown que as notas de release usam
/// (títulos `##`, itens `-`, `**negrito**`, tabelas), sem trazer um pacote só
/// para isso.
class _NotasRelease extends StatelessWidget {
  const _NotasRelease(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    final linhas = texto.split('\n');
    final widgets = <Widget>[];

    for (final linha in linhas) {
      final t = linha.trim();
      if (t.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }
      // Linhas de tabela viram texto simples: manter o pipe polui a leitura.
      if (t.startsWith('|')) {
        final celulas = t
            .split('|')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty && !RegExp(r'^-+$').hasMatch(c))
            .toList();
        if (celulas.isEmpty) continue;
        widgets.add(_paragrafo(context, celulas.join(' — '), recuo: 12));
        continue;
      }
      if (t.startsWith('###') || t.startsWith('##')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(
              t.replaceAll(RegExp(r'^#+\s*'), ''),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
          ),
        );
        continue;
      }
      if (t.startsWith('- ') || t.startsWith('* ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  ', style: TextStyle(height: 1.4)),
                Expanded(child: _rico(context, t.substring(2))),
              ],
            ),
          ),
        );
        continue;
      }
      widgets.add(_paragrafo(context, t));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _paragrafo(BuildContext context, String t, {double recuo = 0}) =>
      Padding(
        padding: EdgeInsets.only(left: recuo, bottom: 4),
        child: _rico(context, t),
      );

  /// Aplica **negrito** e `código` inline.
  Widget _rico(BuildContext context, String t) {
    final spans = <TextSpan>[];
    final padrao = RegExp(r'\*\*(.+?)\*\*|`(.+?)`');
    var indice = 0;

    for (final m in padrao.allMatches(t)) {
      if (m.start > indice) {
        spans.add(TextSpan(text: t.substring(indice, m.start)));
      }
      if (m.group(1) != null) {
        spans.add(
          TextSpan(
            text: m.group(1),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: m.group(2),
            style: TextStyle(
              fontFamily: 'monospace',
              backgroundColor: Colors.grey.shade200,
              fontSize: 12.5,
            ),
          ),
        );
      }
      indice = m.end;
    }
    if (indice < t.length) spans.add(TextSpan(text: t.substring(indice)));

    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(
          context,
        ).style.copyWith(height: 1.45, fontSize: 13.5),
        children: spans,
      ),
    );
  }
}

/// Verificação pedida pelo usuário, com resposta visível nos dois desfechos.
///
/// A checagem da abertura é silenciosa quando não há novidade — o que faz
/// parecer que nada aconteceu. Aqui sempre há retorno.
Future<void> verificarAtualizacaoManualmente(BuildContext context) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 16),
          Text('Procurando atualizações...'),
        ],
      ),
    ),
  );

  final nova = await UpdateService.verificar();

  if (!context.mounted) return;
  Navigator.of(context).pop(); // fecha o "procurando"

  if (nova == null) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600),
            const SizedBox(width: 10),
            const Text('Tudo em dia'),
          ],
        ),
        content: Text('Você já está na versão mais recente ($appVersao).'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
    return;
  }

  await DialogoAtualizacao.mostrar(context, nova);
}

/// Oferece a atualização encontrada e, se aceita, baixa e aplica.
class DialogoAtualizacao extends StatefulWidget {
  const DialogoAtualizacao({required this.versao, super.key});

  final VersaoDisponivel versao;

  static Future<void> mostrar(BuildContext context, VersaoDisponivel v) =>
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => DialogoAtualizacao(versao: v),
      );

  @override
  State<DialogoAtualizacao> createState() => _DialogoAtualizacaoState();
}

class _DialogoAtualizacaoState extends State<DialogoAtualizacao> {
  double? _progresso;
  String? _erro;

  Future<void> _atualizar() async {
    setState(() {
      _progresso = 0;
      _erro = null;
    });
    try {
      final pacote = await UpdateService.baixar(
        widget.versao,
        aoProgredir: (p) {
          if (mounted) setState(() => _progresso = p);
        },
      );
      // Marca antes de reiniciar: ao voltar, o app mostra as novidades.
      await UpdateService.marcarVersaoVista(appVersao);
      await UpdateService.aplicar(pacote);
    } catch (e) {
      if (mounted) {
        setState(() {
          _progresso = null;
          _erro = 'Não foi possível atualizar: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final baixando = _progresso != null;
    final mb = widget.versao.tamanhoBytes / 1048576;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.system_update, color: Colors.blue.shade700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Atualização disponível',
                  style: TextStyle(fontSize: 17),
                ),
                Text(
                  'Versão ${widget.versao.versao} · você está na $appVersao',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _NotasRelease(widget.versao.notas),
              if (_erro != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  color: Colors.red.shade50,
                  child: Text(
                    _erro!,
                    style: TextStyle(color: Colors.red.shade900, fontSize: 12),
                  ),
                ),
              ],
              if (baixando) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(value: _progresso),
                const SizedBox(height: 6),
                Text(
                  'Baixando... ${((_progresso ?? 0) * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  'O sistema fecha e reabre sozinho ao terminar.',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: baixando
          ? null
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Agora não'),
              ),
              ElevatedButton.icon(
                onPressed: _atualizar,
                icon: const Icon(Icons.download),
                label: Text('Atualizar (${mb.toStringAsFixed(0)} MB)'),
              ),
            ],
    );
  }
}

/// Mostra as melhorias logo depois de uma atualização.
class DialogoNovidades extends StatelessWidget {
  const DialogoNovidades({required this.notas, super.key});

  final String notas;

  static Future<void> mostrar(BuildContext context, String notas) => showDialog(
    context: context,
    builder: (_) => DialogoNovidades(notas: notas),
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.auto_awesome, color: Colors.green.shade700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sistema atualizado',
                  style: TextStyle(fontSize: 17),
                ),
                Text(
                  'Versão $appVersao · veja o que mudou',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Faixa com a build instalada: é a primeira pergunta de quem
              // acabou de atualizar.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.verified,
                      size: 18,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Build $appVersao instalada',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              _NotasRelease(notas),
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Entendi'),
        ),
      ],
    );
  }
}
