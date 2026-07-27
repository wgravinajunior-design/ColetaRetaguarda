import 'package:flutter/material.dart';
import '../config/config_service.dart';
import 'db_connection.dart';
import 'firebird_schema_service.dart';

/// Confere a base Firebird escolhida nas Configurações e cria o que falta.
///
/// Antes esta tela mostrava o banco SQLite local, que serve só de apoio interno
/// (fila de sincronização e log do mobile) e se mantém sozinho. O que importa
/// numa instalação nova é a base do ERP: ela já traz TB_PESSOA, TB_USUARIO e
/// companhia, mas as tabelas da coleta são do sistema e precisam ser criadas.
class DatabaseInspectorScreen extends StatefulWidget {
  const DatabaseInspectorScreen({super.key});

  @override
  State<DatabaseInspectorScreen> createState() =>
      _DatabaseInspectorScreenState();
}

class _DatabaseInspectorScreenState extends State<DatabaseInspectorScreen> {
  final _schema = FirebirdSchemaService();

  bool _carregando = true;
  bool _aplicando = false;
  String? _erro;
  DiagnosticoSchema? _diagnostico;

  @override
  void initState() {
    super.initState();
    _conferir();
  }

  Future<void> _conferir() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final d = await _schema.conferir();
      if (mounted) setState(() => _diagnostico = d);
    } catch (e) {
      if (mounted) setState(() => _erro = '$e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _aplicar() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Atualizar a base'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Base: ${ConfigService().caminhoBase}'),
            const SizedBox(height: 12),
            const Text(
              'Serão criadas as tabelas e colunas que o sistema precisa e que '
              'ainda não existem.\n\n'
              'Nada é apagado: tabelas, colunas e dados já existentes ficam '
              'como estão.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Atualizar'),
          ),
        ],
      ),
    );
    if (confirmou != true) return;

    setState(() => _aplicando = true);
    try {
      final feito = await _schema.aplicar();
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Base atualizada'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: feito
                  .map(
                    (l) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            l.startsWith('FALHOU')
                                ? Icons.error_outline
                                : Icons.check,
                            size: 16,
                            color: l.startsWith('FALHOU')
                                ? Colors.red
                                : Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Falha ao atualizar: $e')));
      }
    } finally {
      if (mounted) setState(() => _aplicando = false);
      await _conferir();
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ConfigService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conferir banco de dados'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Conferir de novo',
            onPressed: _carregando ? null : _conferir,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _cartaoBase(config),
              const SizedBox(height: 16),
              if (_carregando)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_erro != null)
                _cartaoErro()
              else if (_diagnostico != null)
                ..._conteudo(_diagnostico!),
            ],
          ),
        ),
      ),
      bottomNavigationBar: (_diagnostico == null || _diagnostico!.tudoCerto)
          ? null
          : Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton.icon(
                icon: _aplicando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.build),
                label: Text(
                  _aplicando
                      ? 'Atualizando...'
                      : 'Criar o que falta nesta base',
                ),
                onPressed: _aplicando ? null : _aplicar,
              ),
            ),
    );
  }

  Widget _cartaoBase(ConfigService config) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storage, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Base conferida',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _linha('Servidor', '${config.host}:${config.porta}'),
            _linha('Arquivo', config.caminhoBase),
            _linha('Usuário', config.dbUsuario),
          ],
        ),
      ),
    );
  }

  Widget _linha(String rotulo, String valor) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            rotulo,
            style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
          ),
        ),
        Expanded(
          child: SelectableText(valor, style: const TextStyle(fontSize: 12.5)),
        ),
      ],
    ),
  );

  Widget _cartaoErro() => Card(
    color: Colors.red.shade50,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700),
              const SizedBox(width: 8),
              const Text(
                'Não foi possível ler a base',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(_erro!, style: const TextStyle(fontSize: 12.5)),
          const SizedBox(height: 8),
          Text(
            'Confira servidor, porta, caminho e credenciais em Configurações.',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      ),
    ),
  );

  List<Widget> _conteudo(DiagnosticoSchema d) {
    return [
      if (d.tudoCerto)
        Card(
          color: Colors.green.shade50,
          child: ListTile(
            leading: Icon(Icons.verified, color: Colors.green.shade700),
            title: const Text('Base pronta para uso'),
            subtitle: const Text(
              'Todas as tabelas e colunas do sistema estão presentes.',
            ),
          ),
        )
      else
        Card(
          color: Colors.orange.shade50,
          child: ListTile(
            leading: Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange.shade800,
            ),
            title: Text(
              '${d.pendencias} ${d.pendencias == 1 ? "pendência" : "pendências"} nesta base',
            ),
            subtitle: const Text('Use o botão abaixo para criar o que falta.'),
          ),
        ),

      if (d.dependenciasFaltando.isNotEmpty) ...[
        const SizedBox(height: 16),
        Card(
          color: Colors.red.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tabelas do ERP que não foram encontradas',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  d.dependenciasFaltando.join(', '),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  'O sistema não cria estas — elas vêm do ERP. Se estiverem '
                  'faltando, provavelmente a base escolhida não é a do ERP.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                ),
              ],
            ),
          ),
        ),
      ],

      const SizedBox(height: 16),
      Text('Tabelas do sistema', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      ...d.tabelas.map(_cartaoTabela),
    ];
  }

  Widget _cartaoTabela(SituacaoTabela t) {
    final (icone, cor, situacao) = t.ok
        ? (Icons.check_circle, Colors.green, 'Em dia')
        : t.existe
        ? (
            Icons.add_circle_outline,
            Colors.orange,
            '${t.colunasFaltando.length} coluna(s) a criar',
          )
        : (Icons.cancel_outlined, Colors.red, 'Tabela não existe');

    return Card(
      child: ListTile(
        leading: Icon(icone, color: cor),
        title: Text(
          t.tabela,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          t.colunasFaltando.isEmpty
              ? situacao
              : '$situacao: ${t.colunasFaltando.join(', ')}',
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}

/// Mantido por compatibilidade com quem ainda importa daqui.
Future<bool> baseAcessivel() async => DbConnection().testarConexao();
