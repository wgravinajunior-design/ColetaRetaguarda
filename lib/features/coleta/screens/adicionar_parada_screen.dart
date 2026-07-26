import 'package:flutter/material.dart';
import '../models/parada_model.dart';
import '../repositories/parada_repository.dart';
import '../../produtores/models/pessoa_model.dart';
import '../../produtores/repositories/pessoa_repository.dart';
import '../../core/utils/documento_validator.dart';

class AdicionarParadaScreen extends StatefulWidget {
  final int rotaId;
  final int sequencia;

  const AdicionarParadaScreen({
    super.key,
    required this.rotaId,
    required this.sequencia,
  });

  @override
  State<AdicionarParadaScreen> createState() => _AdicionarParadaScreenState();
}

class _AdicionarParadaScreenState extends State<AdicionarParadaScreen> {
  final _repository = ParadaRepository();
  final _pessoaRepository = PessoaRepository();

  // Controllers dos campos separados
  final _nomeController = TextEditingController();
  final _cnpjController = TextEditingController();
  final _enderecoController = TextEditingController();
  final _numeroController = TextEditingController();
  final _complementoController = TextEditingController();
  final _bairroController = TextEditingController();
  final _cepController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  final _buscaController = TextEditingController();

  bool _isLoading = false;
  bool _carregandoProdutores = false;
  List<PessoaModel> _produtores = [];
  List<PessoaModel> _produtoresFiltrados = [];
  PessoaModel? _produtorSelecionado;

  @override
  void initState() {
    super.initState();
    _carregarProdutores();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _cnpjController.dispose();
    _enderecoController.dispose();
    _numeroController.dispose();
    _complementoController.dispose();
    _bairroController.dispose();
    _cepController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _buscaController.dispose();
    super.dispose();
  }

  Future<void> _carregarProdutores() async {
    setState(() => _carregandoProdutores = true);
    try {
      final produtores = await _pessoaRepository.getProdutores();
      setState(() {
        _produtores = produtores;
        _produtoresFiltrados = produtores;
      });
    } catch (e) {
      // ignora - mantem lista vazia
    } finally {
      if (mounted) setState(() => _carregandoProdutores = false);
    }
  }

  void _filtrarProdutores(String query) {
    final q = query.toLowerCase();
    setState(() {
      _produtoresFiltrados = _produtores.where((p) {
        return p.rSocialNome.toLowerCase().contains(q) ||
            p.fantasiaApelido.toLowerCase().contains(q) ||
            p.cnpjCpf.toLowerCase().contains(q);
      }).toList();
    });
  }

  void _selecionarProdutor(PessoaModel produtor) {
    setState(() {
      _produtorSelecionado = produtor;
      _nomeController.text = produtor.rSocialNome.isNotEmpty
          ? produtor.rSocialNome
          : produtor.fantasiaApelido;
      _cnpjController.text = produtor.cnpjCpf;
      _enderecoController.text = produtor.endereco;
      _numeroController.text = produtor.numero;
      _complementoController.text = produtor.complemento;
      _bairroController.text = produtor.bairro;
      _cepController.text = produtor.cep;
    });
  }

  void _limparSelecao() {
    setState(() {
      _produtorSelecionado = null;
      _nomeController.clear();
      _cnpjController.clear();
      _enderecoController.clear();
      _numeroController.clear();
      _complementoController.clear();
      _bairroController.clear();
      _cepController.clear();
      _buscaController.clear();
      _produtoresFiltrados = _produtores;
    });
  }

  String _montarEnderecoCompleto() {
    final partes = <String>[];
    if (_enderecoController.text.isNotEmpty)
      partes.add(_enderecoController.text);
    if (_numeroController.text.isNotEmpty)
      partes.add('nº ${_numeroController.text}');
    if (_complementoController.text.isNotEmpty)
      partes.add(_complementoController.text);
    if (_bairroController.text.isNotEmpty) partes.add(_bairroController.text);
    if (_cepController.text.isNotEmpty)
      partes.add('CEP ${_cepController.text}');
    return partes.join(', ');
  }

  Future<void> _salvarParada() async {
    if (_nomeController.text.isEmpty || _enderecoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um produtor ou preencha nome e endereço'),
        ),
      );
      return;
    }

    // Valida CPF/CNPJ quando preenchido (obrigatório apenas em cadastro manual)
    final erroDoc = DocumentoValidator.mensagemErro(_cnpjController.text);
    if (erroDoc != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(erroDoc), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final latitude =
          double.tryParse(_latitudeController.text.replaceAll(',', '.')) ??
          -19.8157;
      final longitude =
          double.tryParse(_longitudeController.text.replaceAll(',', '.')) ??
          -43.9542;

      final novaParada = ParadaModel(
        rotaId: widget.rotaId,
        pessoaId: _produtorSelecionado?.id,
        pessoaNome: _nomeController.text,
        cnpjCpf: _cnpjController.text,
        endereco: _montarEnderecoCompleto(),
        latitude: latitude,
        longitude: longitude,
        status: 'P',
      );

      final parada = await _repository.criarParada(novaParada);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parada adicionada com sucesso!')),
        );
        Navigator.pop(context, parada);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adicionar Parada'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== SEÇÃO 1: BUSCAR PRODUTOR =====
            _buildSecao(
              titulo: 'Buscar Produtor',
              icone: Icons.search,
              child: _produtorSelecionado == null
                  ? _buildBuscaProdutor()
                  : _buildProdutorSelecionado(),
            ),
            const SizedBox(height: 16),

            // ===== SEÇÃO 2: DADOS DO PRODUTOR =====
            _buildSecao(
              titulo: 'Dados do Produtor',
              icone: Icons.person,
              child: Column(
                children: [
                  _buildCampo(
                    controller: _nomeController,
                    label: 'Nome / Razão Social',
                    icone: Icons.person_outline,
                  ),
                  const SizedBox(height: 12),
                  _buildCampo(
                    controller: _cnpjController,
                    label: 'CNPJ / CPF',
                    icone: Icons.badge_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ===== SEÇÃO 3: ENDEREÇO =====
            _buildSecao(
              titulo: 'Endereço',
              icone: Icons.location_on,
              child: Column(
                children: [
                  _buildCampo(
                    controller: _enderecoController,
                    label: 'Logradouro (Rua / Estrada)',
                    icone: Icons.signpost_outlined,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: _buildCampo(
                          controller: _numeroController,
                          label: 'Número',
                          icone: Icons.tag,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _buildCampo(
                          controller: _complementoController,
                          label: 'Complemento',
                          icone: Icons.add_location_alt_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildCampo(
                          controller: _bairroController,
                          label: 'Bairro',
                          icone: Icons.holiday_village_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: _buildCampo(
                          controller: _cepController,
                          label: 'CEP',
                          icone: Icons.markunread_mailbox_outlined,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ===== SEÇÃO 4: GEOLOCALIZAÇÃO =====
            _buildSecao(
              titulo: 'Geolocalização',
              icone: Icons.gps_fixed,
              child: Row(
                children: [
                  Expanded(
                    child: _buildCampo(
                      controller: _latitudeController,
                      label: 'Latitude',
                      icone: Icons.my_location,
                      hint: '-19.8157',
                      teclado: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCampo(
                      controller: _longitudeController,
                      label: 'Longitude',
                      icone: Icons.my_location,
                      hint: '-43.9542',
                      teclado: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ===== BOTÃO SALVAR =====
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.check, color: Colors.white),
                label: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Salvar Parada',
                        style: TextStyle(color: Colors.white),
                      ),
                onPressed: _isLoading ? null : _salvarParada,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== WIDGETS AUXILIARES =====

  Widget _buildSecao({
    required String titulo,
    required IconData icone,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue.shade100, width: 1),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: Row(
              children: [
                Icon(icone, color: Colors.blue.shade600, size: 20),
                const SizedBox(width: 8),
                Text(
                  titulo,
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(12), child: child),
        ],
      ),
    );
  }

  Widget _buildBuscaProdutor() {
    return Column(
      children: [
        TextField(
          controller: _buscaController,
          onChanged: _filtrarProdutores,
          decoration: InputDecoration(
            hintText: 'Digite nome ou CNPJ/CPF...',
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Recarregar',
              onPressed: _carregarProdutores,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_carregandoProdutores)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          )
        else if (_produtoresFiltrados.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Nenhum produtor encontrado',
              style: TextStyle(color: Colors.grey[600]),
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _produtoresFiltrados.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final p = _produtoresFiltrados[index];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Icon(
                      Icons.agriculture,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    p.rSocialNome.isNotEmpty
                        ? p.rSocialNome
                        : p.fantasiaApelido,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    '${p.cnpjCpf}${p.bairro.isNotEmpty ? ' • ${p.bairro}' : ''}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => _selecionarProdutor(p),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildProdutorSelecionado() {
    final p = _produtorSelecionado!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.green.shade100,
            child: Icon(Icons.check_circle, color: Colors.green.shade700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.rSocialNome.isNotEmpty ? p.rSocialNome : p.fantasiaApelido,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  p.cnpjCpf,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          TextButton.icon(
            icon: const Icon(Icons.swap_horiz, size: 18),
            label: const Text('Trocar'),
            onPressed: _limparSelecao,
          ),
        ],
      ),
    );
  }

  Widget _buildCampo({
    required TextEditingController controller,
    required String label,
    required IconData icone,
    String? hint,
    TextInputType? teclado,
  }) {
    return TextField(
      controller: controller,
      keyboardType: teclado,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icone, size: 20),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}
