import 'package:flutter/material.dart';
import 'sqlite_service.dart';
import 'db_migration.dart';

/// Tela de diagnóstico do banco de dados local.
/// Permite conferir as tabelas e campos criados (útil antes de fazer login,
/// para validar se as migrações rodaram corretamente).
class DatabaseInspectorScreen extends StatefulWidget {
  const DatabaseInspectorScreen({super.key});

  @override
  State<DatabaseInspectorScreen> createState() => _DatabaseInspectorScreenState();
}

class _DatabaseInspectorScreenState extends State<DatabaseInspectorScreen> {
  final _sqlite = SqliteService();
  bool _loading = true;
  String? _erro;

  String _dbPath = '';
  int _versao = 0;
  List<_TabelaInfo> _tabelas = [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _loading = true;
      _erro = null;
    });

    try {
      final path = await _sqlite.getDbPath();
      final versao = await _sqlite.versaoAtual();
      final nomesTabelas = await _sqlite.listarTabelas();

      final tabelas = <_TabelaInfo>[];
      for (final nome in nomesTabelas) {
        final campos = await _sqlite.listarCampos(nome);
        final total = await _sqlite.contarRegistros(nome);
        tabelas.add(_TabelaInfo(
          nome: nome,
          campos: campos,
          totalRegistros: total,
        ));
      }

      setState(() {
        _dbPath = path;
        _versao = versao;
        _tabelas = tabelas;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _erro = 'Erro ao ler o banco: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnóstico do Banco'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recarregar',
            onPressed: _carregar,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_erro!, style: const TextStyle(color: Colors.red)),
                ))
              : _buildConteudo(),
    );
  }

  Widget _buildConteudo() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildResumo(),
        const SizedBox(height: 8),
        _buildBotaoRecriar(),
        const SizedBox(height: 12),
        ..._tabelas.map(_buildTabelaCard),
      ],
    );
  }

  Widget _buildBotaoRecriar() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.blue.shade700,
          side: BorderSide(color: Colors.blue.shade300),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        icon: const Icon(Icons.upgrade),
        label: const Text('Atualizar schema (adiciona campos faltantes)'),
        onPressed: _confirmarAtualizar,
      ),
    );
  }

  Future<void> _confirmarAtualizar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.upgrade, color: Colors.blue),
            SizedBox(width: 8),
            Text('Atualizar schema?'),
          ],
        ),
        content: const Text(
          'Serão criadas as tabelas que faltam e adicionadas as colunas novas '
          'do schema mais recente.\n\n'
          'É uma operação SEGURA e ADITIVA: nenhum dado é apagado e nenhum campo '
          'original é removido.\n\n'
          'Deseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Atualizar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _loading = true);
    try {
      await _sqlite.atualizarSchema();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Schema atualizado com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _carregar();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar schema: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildResumo() {
    final totalCampos = _tabelas.fold<int>(0, (s, t) => s + t.campos.length);
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storage, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Banco de Dados Local',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _linhaResumo('Versão do schema (atual)', '$_versao'),
            _linhaResumo('Versão esperada (código)', '$dbVersion'),
            _linhaResumo('Tabelas', '${_tabelas.length}'),
            _linhaResumo('Total de campos', '$totalCampos'),
            const SizedBox(height: 8),
            if (_versao != dbVersion)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Schema desatualizado! Esperado v$dbVersion, banco está em v$_versao.',
                        style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.check_circle, color: Colors.green, size: 18),
                    SizedBox(width: 6),
                    Text('Schema atualizado', style: TextStyle(fontSize: 12, color: Colors.green)),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              _dbPath,
              style: TextStyle(fontSize: 10, color: Colors.grey[600], fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linhaResumo(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
          Text(valor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildTabelaCard(_TabelaInfo tabela) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ExpansionTile(
        leading: const Icon(Icons.table_chart, color: Colors.blueGrey),
        title: Text(
          tabela.nome,
          style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'),
        ),
        subtitle: Text('${tabela.campos.length} campos • ${tabela.totalRegistros} registros'),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: tabela.campos.map((campo) {
                final nome = campo['name'] as String? ?? '';
                final tipo = campo['type'] as String? ?? '';
                final pk = (campo['pk'] as int? ?? 0) > 0;
                final notNull = (campo['notnull'] as int? ?? 0) > 0;
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    children: [
                      if (pk)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.key, size: 14, color: Colors.amber),
                        ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          nome,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          tipo.isEmpty ? '—' : tipo,
                          style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                        ),
                      ),
                      if (notNull)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'NOT NULL',
                            style: TextStyle(fontSize: 9, color: Colors.red.shade700),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _TabelaInfo {
  final String nome;
  final List<Map<String, dynamic>> campos;
  final int totalRegistros;

  _TabelaInfo({
    required this.nome,
    required this.campos,
    required this.totalRegistros,
  });
}
