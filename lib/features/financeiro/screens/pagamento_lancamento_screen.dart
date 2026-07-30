import 'package:flutter/material.dart';
import '../models/pagamento_model.dart';
import '../models/movimento_model.dart';

/// Tela de Lançamento de Pagamentos
/// Permite registrar depósitos do laticínio e folha de pagamento
class PagamentoLancamentoScreen extends StatefulWidget {
  const PagamentoLancamentoScreen({super.key});

  @override
  State<PagamentoLancamentoScreen> createState() =>
      _PagamentoLancamentoScreenState();
}

class _PagamentoLancamentoScreenState extends State<PagamentoLancamentoScreen> {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // Depósito
  late TextEditingController _depositoController;
  late TextEditingController _dataDepositoController;
  late TextEditingController _obsDepositoController;

  // Folha de Pagamento
  late TextEditingController _folhaDataController;
  late TextEditingController _folhaObsController;

  List<ItemPagamentoModel> _itensDepositoSelecionados = [];
  List<ItemPagamentoModel> _itensFolhaSelecionados = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _depositoController = TextEditingController();
    _dataDepositoController = TextEditingController(
      text: DateTime.now().toString().split(' ')[0],
    );
    _obsDepositoController = TextEditingController();
    _folhaDataController = TextEditingController(
      text: DateTime.now().toString().split(' ')[0],
    );
    _folhaObsController = TextEditingController();
  }

  @override
  void dispose() {
    _depositoController.dispose();
    _dataDepositoController.dispose();
    _obsDepositoController.dispose();
    _folhaDataController.dispose();
    _folhaObsController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lançamento de Pagamentos'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Depósito Laticínio'),
            Tab(text: 'Folha de Pagamento'),
            Tab(text: 'Histórico'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDepositoTab(),
          _buildFolhaPagamentoTab(),
          _buildHistoricoTab(),
        ],
      ),
    );
  }

  /// TAB 1: DEPÓSITO DO LATICÍNIO
  Widget _buildDepositoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Depósito do Laticínio',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Registre o valor total depositado pelo laticínio e o sistema distribuirá automaticamente entre os produtores conforme o volume de coleta.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Valor Total
            TextFormField(
              controller: _depositoController,
              decoration: const InputDecoration(
                labelText: 'Valor Total Depositado',
                hintText: '0.00',
                prefixText: 'R\$ ',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (v) =>
                  (v?.isEmpty ?? true) ? 'Insira o valor' : null,
            ),
            const SizedBox(height: 16),

            // Data
            TextFormField(
              controller: _dataDepositoController,
              decoration: const InputDecoration(
                labelText: 'Data do Depósito',
                border: OutlineInputBorder(),
              ),
              readOnly: true,
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  _dataDepositoController.text =
                      date.toString().split(' ')[0];
                }
              },
            ),
            const SizedBox(height: 16),

            // Observações
            TextFormField(
              controller: _obsDepositoController,
              decoration: const InputDecoration(
                labelText: 'Observações',
                hintText: 'Ex: Depósito referente à coleta de 15/07',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Preview de Distribuição
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Distribuição (Simulação)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDistribuicaoPreview(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Botões
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _salvarDeposito(),
                    icon: const Icon(Icons.check),
                    label: const Text('Confirmar Depósito'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _limparFormDeposito(),
                  icon: const Icon(Icons.clear),
                  label: const Text('Limpar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// TAB 2: FOLHA DE PAGAMENTO
  Widget _buildFolhaPagamentoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Info
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Folha de Pagamento',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Controle de Valor Total - Descontos = Valor Repassado aos Produtores',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Data
          TextFormField(
            controller: _folhaDataController,
            decoration: const InputDecoration(
              labelText: 'Período de Referência',
              border: OutlineInputBorder(),
            ),
            readOnly: true,
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                _folhaDataController.text = date.toString().split(' ')[0];
              }
            },
          ),
          const SizedBox(height: 16),

          // Sumário
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _buildItemFolha('Valor Total a Repassar', 0, Colors.green),
                  const Divider(),
                  _buildItemFolha('(-) Descontos', 0, Colors.red),
                  const Divider(thickness: 2),
                  _buildItemFolha('(=) Valor Líquido', 0, Colors.blue),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Detalhamento por Produtor
          const Text(
            'Detalhamento por Produtor',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildTabelaProdutoresComDescontos(),
          const SizedBox(height: 24),

          // Observações
          TextFormField(
            controller: _folhaObsController,
            decoration: const InputDecoration(
              labelText: 'Observações',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),

          // Botões
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _salvarFolhaPagamento(),
                  icon: const Icon(Icons.check),
                  label: const Text('Confirmar Folha'),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _limparFormFolha(),
                icon: const Icon(Icons.clear),
                label: const Text('Limpar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// TAB 3: HISTÓRICO
  Widget _buildHistoricoTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Histórico de Pagamentos',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        // TODO: Carregar histórico do banco
        const Center(
          child: Text('Nenhum pagamento registrado'),
        ),
      ],
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────

  Widget _buildDistribuicaoPreview() {
    return Column(
      children: [
        _buildItemDistribuicao('Produtor A (500L)', 250.00),
        _buildItemDistribuicao('Produtor B (300L)', 150.00),
        _buildItemDistribuicao('Produtor C (200L)', 100.00),
      ],
    );
  }

  Widget _buildItemDistribuicao(String nome, double valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(nome),
          Text('R\$ ${valor.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  Widget _buildItemFolha(String label, double valor, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        Text(
          'R\$ ${valor.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildTabelaProdutoresComDescontos() {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(2),
        3: FlexColumnWidth(2),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade200),
          children: const [
            Padding(
              padding: EdgeInsets.all(8),
              child: Text('Produtor', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Text('Valor Leite', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Text('Desconto', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Text('Repassar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        // TODO: Adicionar linhas dinâmicas
        TableRow(
          children: [
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Produtor A'),
            ),
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('R\$ 500.00'),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: '0.00',
                  border: InputBorder.none,
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('R\$ 500.00', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }

  void _salvarDeposito() {
    if (_formKey.currentState?.validate() ?? false) {
      // TODO: Salvar depósito no banco
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Depósito salvo com sucesso!')),
      );
    }
  }

  void _salvarFolhaPagamento() {
    // TODO: Salvar folha de pagamento no banco
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Folha de pagamento salva com sucesso!')),
    );
  }

  void _limparFormDeposito() {
    _depositoController.clear();
    _obsDepositoController.clear();
    _dataDepositoController.text = DateTime.now().toString().split(' ')[0];
  }

  void _limparFormFolha() {
    _folhaObsController.clear();
    _folhaDataController.text = DateTime.now().toString().split(' ')[0];
  }
}
