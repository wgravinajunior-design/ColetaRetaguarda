import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/app_info.dart';
import '../core/config/config_service.dart';
import '../core/database/database_inspector_screen.dart';

/// Tela única de configuração do sistema.
///
/// Concentra o que antes estava espalhado pela tela de login (diagnóstico do
/// banco, logo) — lá ficou só o essencial para entrar.
class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _hostController;
  late TextEditingController _portaController;
  late TextEditingController _caminhoBaseController;
  late TextEditingController _usuarioController;
  late TextEditingController _senhaController;
  String _logoPath = '';

  bool _isTesting = false;
  bool _mostrarSenha = false;

  @override
  void initState() {
    super.initState();
    final config = ConfigService();
    _hostController = TextEditingController(text: config.host);
    _portaController = TextEditingController(text: config.porta);
    _caminhoBaseController = TextEditingController(text: config.caminhoBase);
    _usuarioController = TextEditingController(text: config.dbUsuario);
    _senhaController = TextEditingController(text: config.dbSenha);
    _logoPath = config.logoPath;
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portaController.dispose();
    _caminhoBaseController.dispose();
    _usuarioController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() => _logoPath = result.files.single.path!);
    }
  }

  Future<void> _pickBase() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['fdb', 'FDB'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _caminhoBaseController.text = result.files.single.path!);
    }
  }

  Future<void> _testConnection() async {
    setState(() => _isTesting = true);

    final host = _hostController.text;
    // Padrão do Firebird; antes caía em 3000, que é porta de aplicação.
    final port = int.tryParse(_portaController.text) ?? 3050;

    try {
      // Socket direto: confirma que o servidor responde naquele host e porta,
      // sem depender de a base já estar acessível.
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 3),
      );
      socket.destroy();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conexão bem sucedida! Porta aberta.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível alcançar $host:$port.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    final config = ConfigService();
    config.host = _hostController.text;
    config.porta = _portaController.text;
    config.caminhoBase = _caminhoBaseController.text;
    config.dbUsuario = _usuarioController.text;
    config.dbSenha = _senhaController.text;
    config.logoPath = _logoPath;

    await config.saveConfig();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configurações salvas com sucesso!')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _secao('Banco de dados', Icons.storage),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _hostController,
                                decoration: const InputDecoration(
                                  labelText: 'Host (IP ou nome do servidor)',
                                  isDense: true,
                                ),
                                validator: (v) =>
                                    v!.isEmpty ? 'Obrigatório' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _portaController,
                                decoration: const InputDecoration(
                                  labelText: 'Porta',
                                  isDense: true,
                                  helperText: 'Padrão: 3050',
                                ),
                                keyboardType: TextInputType.number,
                                validator: (v) =>
                                    v!.isEmpty ? 'Obrigatório' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _caminhoBaseController,
                          decoration: InputDecoration(
                            labelText: 'Caminho da base (.FDB)',
                            isDense: true,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.folder_open),
                              tooltip: 'Procurar arquivo',
                              onPressed: _pickBase,
                            ),
                          ),
                          validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _usuarioController,
                                decoration: const InputDecoration(
                                  labelText: 'Usuário',
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _senhaController,
                                obscureText: !_mostrarSenha,
                                decoration: InputDecoration(
                                  labelText: 'Senha',
                                  isDense: true,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _mostrarSenha
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(
                                      () => _mostrarSenha = !_mostrarSenha,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: _isTesting ? null : _testConnection,
                              icon: _isTesting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.wifi),
                              label: const Text('Testar conexão'),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.fact_check_outlined),
                              label: const Text('Conferir banco'),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const DatabaseInspectorScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                _secao('Aparência', Icons.image_outlined),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                          ),
                          child:
                              _logoPath.isNotEmpty &&
                                  File(_logoPath).existsSync()
                              ? Image.file(File(_logoPath), fit: BoxFit.contain)
                              : const Icon(
                                  Icons.image,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Logo do sistema',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Aparece na tela de login e nas impressões.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: _pickLogo,
                                icon: const Icon(Icons.upload_file, size: 18),
                                label: const Text('Selecionar'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                _secao('Sobre', Icons.info_outline),
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.business_center,
                      color: Colors.blue,
                    ),
                    title: const Text('ColetaUp'),
                    subtitle: Text('Versão $appVersao · Go Up Sistemas'),
                  ),
                ),

                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _saveConfig,
                      icon: const Icon(Icons.save),
                      label: const Text('Salvar'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _secao(String titulo, IconData icone) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        children: [
          Icon(icone, size: 18, color: Colors.blue.shade700),
          const SizedBox(width: 6),
          Text(
            titulo,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
