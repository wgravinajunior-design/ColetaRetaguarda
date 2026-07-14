import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../core/config/config_service.dart';

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
  String _logoPath = '';
  
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    final config = ConfigService();
    _hostController = TextEditingController(text: config.host);
    _portaController = TextEditingController(text: config.porta);
    _caminhoBaseController = TextEditingController(text: config.caminhoBase);
    _logoPath = config.logoPath;
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portaController.dispose();
    _caminhoBaseController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.image,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _logoPath = result.files.single.path!;
      });
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
    });

    final host = _hostController.text;
    final port = int.tryParse(_portaController.text) ?? 3000;
    
    try {
      // Usamos Socket para testar se a porta está aberta (funciona para DB ou API)
      final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 3));
      socket.destroy();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conexão bem sucedida! Porta aberta.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha na conexão: Não foi possível alcançar o Host/Porta.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTesting = false;
        });
      }
    }
  }

  Future<void> _saveConfig() async {
    if (_formKey.currentState!.validate()) {
      final config = ConfigService();
      config.host = _hostController.text;
      config.porta = _portaController.text;
      config.caminhoBase = _caminhoBaseController.text;
      config.logoPath = _logoPath;
      
      await config.saveConfig();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configurações salvas com sucesso!')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações de Conexão'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    TextFormField(
                      controller: _hostController,
                      decoration: const InputDecoration(labelText: 'Host (IP ou Nome do Servidor)'),
                      validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _portaController,
                      decoration: const InputDecoration(labelText: 'Porta'),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _caminhoBaseController,
                      decoration: const InputDecoration(labelText: 'Caminho da Base de Dados (.FDB)'),
                      validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                    ),
                    const SizedBox(height: 24),
                    const Text('Logo do Sistema', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (_logoPath.isNotEmpty && File(_logoPath).existsSync())
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                            ),
                            child: Image.file(File(_logoPath), fit: BoxFit.contain),
                          )
                        else
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                            ),
                            child: const Icon(Icons.image, size: 40, color: Colors.grey),
                          ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: _pickLogo,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Selecionar Logo'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isTesting ? null : _testConnection,
                          icon: _isTesting 
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.wifi),
                          label: const Text('Testar Conexão'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _saveConfig,
                              child: const Text('Salvar'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
