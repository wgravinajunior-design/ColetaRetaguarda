import 'package:flutter/material.dart';
import '../models/parada_model.dart';
import '../repositories/parada_repository.dart';
import '../services/comprovante_service.dart';
import '../../financeiro/models/movimento_model.dart';
import '../../financeiro/repositories/financeiro_repository.dart';
import '../../core/database/firebird_service.dart';

/// Agrupa as coletas concluídas por produtor e calcula o pagamento
/// com base num preço por litro configurável.
class PagamentoProdutor {
  final int? pessoaId;
  final String nome;
  final String cnpjCpf;
  int qtdColetas;
  double totalLitros;

  PagamentoProdutor({
    required this.pessoaId,
    required this.nome,
    required this.cnpjCpf,
    this.qtdColetas = 0,
    this.totalLitros = 0,
  });
}

class PagamentosScreen extends StatefulWidget {
  const PagamentosScreen({super.key});

  @override
  State<PagamentosScreen> createState() => _PagamentosScreenState();
}

class _PagamentosScreenState extends State<PagamentosScreen> {
  final _precoController = TextEditingController(text: '2,50');
  bool _loading = true;
  bool _lancando = false;
  List<PagamentoProdutor> _pagamentos = [];
  List<ContaRef> _contas = [];
  int? _contaSaidaId;

  double get _precoLitro =>
      double.tryParse(_precoController.text.replaceAll(',', '.')) ?? 0;

  double get _totalGeral =>
      _pagamentos.fold(0.0, (s, p) => s + p.totalLitros * _precoLitro);

  double get _litrosGeral =>
      _pagamentos.fold(0.0, (s, p) => s + p.totalLitros);

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _precoController.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    // Carrega as contas (caixa/banco) para a conta de saída
    try {
      final contas = await FinanceiroRepository().getContas();
      _contas = contas;
      _contaSaidaId ??= contas.isNotEmpty ? contas.first.id : null;
    } catch (_) {}
    // Somente coletas concluídas (status C)
    final coletas = await ParadaRepository().getTodasColetas(status: 'C');

    final mapa = <String, PagamentoProdutor>{};
    for (final ParadaModel c in coletas) {
      final chave = c.pessoaId?.toString() ?? c.pessoaNome;
      final p = mapa.putIfAbsent(
        chave,
        () => PagamentoProdutor(
          pessoaId: c.pessoaId,
          nome: c.pessoaNome,
          cnpjCpf: c.cnpjCpf,
        ),
      );
      p.qtdColetas += 1;
      p.totalLitros += c.volume ?? 0;
    }

    if (!mounted) return;
    setState(() {
      _pagamentos = mapa.values.toList()
        ..sort((a, b) => b.totalLitros.compareTo(a.totalLitros));
      _loading = false;
    });
  }

  Future<void> _lancarNoFinanceiro() async {
    if (_pagamentos.isEmpty || _precoLitro <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um preço por litro válido')),
      );
      return;
    }
    if (_contaSaidaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a conta de saída'), backgroundColor: Colors.red),
      );
      return;
    }

    final contaNome = _contas.firstWhere((c) => c.id == _contaSaidaId,
        orElse: () => const ContaRef(id: 0, descricao: '-', tipo: 'C')).descricao;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Lançar pagamentos?'),
        content: Text(
          'Serão criados ${_pagamentos.length} lançamentos de despesa na conta '
          '"$contaNome", totalizando R\$ ${_totalGeral.toStringAsFixed(2)}.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Lançar')),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _lancando = true);
    final repo = FinanceiroRepository();
    final hoje = DateTime.now().toIso8601String().substring(0, 10);
    int criados = 0;

    for (final p in _pagamentos) {
      final valor = p.totalLitros * _precoLitro;
      if (valor <= 0) continue;
      await repo.createMovimento(MovimentoModel(
        tipo: 'D', // Despesa (pagamento ao produtor)
        status: 'P',
        conta: _contaSaidaId!,
        valor: valor,
        dtEmissao: hoje,
        origem: 'COLETA',
        historico:
            'Pagamento coleta leite - ${p.nome} (${p.totalLitros.toStringAsFixed(0)}L x R\$ ${_precoLitro.toStringAsFixed(2)})',
      ));
      criados++;
    }

    if (!mounted) return;
    setState(() => _lancando = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ $criados lançamentos criados no financeiro'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _imprimirRelatorio() {
    ComprovanteService().imprimirRelatorioPagamentos(
      pagamentos: _pagamentos,
      precoLitro: _precoLitro,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pagamentos por Produtor'),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _carregar),
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Imprimir relatório',
            onPressed: _pagamentos.isEmpty ? null : _imprimirRelatorio,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildTopo(),
                const Divider(height: 1),
                Expanded(child: _buildLista()),
                _buildRodape(),
              ],
            ),
    );
  }

  Widget _buildTopo() {
    return Container(
      color: Colors.blue.shade50,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _precoController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Preço por litro (R\$)',
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${_litrosGeral.toStringAsFixed(0)} L',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('${_pagamentos.length} produtores',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Conta de saída dos pagamentos
          DropdownButtonFormField<int>(
            initialValue: _contaSaidaId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Conta de saída (pagamento)',
              prefixIcon: Icon(Icons.account_balance_wallet),
              border: OutlineInputBorder(),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
            ),
            items: _contas
                .map((c) => DropdownMenuItem(
                      value: c.id,
                      child: Text('${c.descricao} (${c.isBanco ? 'Banco' : 'Caixa'})'),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _contaSaidaId = v),
            hint: _contas.isEmpty ? const Text('Nenhuma conta') : null,
          ),
        ],
      ),
    );
  }

  Widget _buildLista() {
    if (_pagamentos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.payments_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('Nenhuma coleta concluída para pagar', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: _pagamentos.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final p = _pagamentos[index];
        final valor = p.totalLitros * _precoLitro;
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green.shade100,
              child: Icon(Icons.agriculture, color: Colors.green.shade700),
            ),
            title: Text(p.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              '${p.cnpjCpf.isNotEmpty ? '${p.cnpjCpf} • ' : ''}'
              '${p.qtdColetas} coleta(s) • ${p.totalLitros.toStringAsFixed(0)} L',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Text(
              'R\$ ${valor.toStringAsFixed(2)}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green.shade800),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRodape() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total a pagar', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text(
                  'R\$ ${_totalGeral.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.green),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: _lancando
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.account_balance_wallet, color: Colors.white),
            label: const Text('Lançar no financeiro', style: TextStyle(color: Colors.white)),
            onPressed: _lancando ? null : _lancarNoFinanceiro,
          ),
        ],
      ),
    );
  }
}
