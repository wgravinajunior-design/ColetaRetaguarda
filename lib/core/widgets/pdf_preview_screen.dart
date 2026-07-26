import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

/// Mostra o PDF na tela, com imprimir, salvar e compartilhar.
///
/// Antes o botão de PDF ia direto para a caixa de impressão do Windows, sem
/// o usuário ver o documento primeiro.
class PdfPreviewScreen extends StatelessWidget {
  const PdfPreviewScreen({
    required this.titulo,
    required this.nomeArquivo,
    required this.gerar,
    this.aoEnviarWhatsApp,
    super.key,
  });

  final String titulo;

  /// Nome sugerido ao salvar, sem extensão.
  final String nomeArquivo;

  /// Produz os bytes do PDF. Recebe o formato escolhido na barra do preview.
  final Future<Uint8List> Function() gerar;

  /// Quando informado, acrescenta o botão de WhatsApp na barra superior.
  final Future<void> Function()? aoEnviarWhatsApp;

  static Future<void> abrir(
    BuildContext context, {
    required String titulo,
    required String nomeArquivo,
    required Future<Uint8List> Function() gerar,
    Future<void> Function()? aoEnviarWhatsApp,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfPreviewScreen(
          titulo: titulo,
          nomeArquivo: nomeArquivo,
          gerar: gerar,
          aoEnviarWhatsApp: aoEnviarWhatsApp,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
        elevation: 0,
        actions: [
          if (aoEnviarWhatsApp != null)
            IconButton(
              icon: const Icon(Icons.chat),
              tooltip: 'Enviar no WhatsApp',
              onPressed: aoEnviarWhatsApp,
            ),
        ],
      ),
      body: PdfPreview(
        build: (_) => gerar(),
        pdfFileName: '$nomeArquivo.pdf',
        canDebug: false,
        // O preview já é a visualização: o botão de página inteira é redundante.
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        loadingWidget: const Center(child: CircularProgressIndicator()),
        onError: (context, erro) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 56, color: Colors.red.shade300),
                const SizedBox(height: 12),
                const Text('Não foi possível gerar o PDF'),
                const SizedBox(height: 8),
                SelectableText(
                  '$erro',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Abre um PDF já gravado no visualizador padrão do sistema.
Future<void> abrirPdfNoSistema(File arquivo) =>
    Process.run('cmd', ['/c', 'start', '', arquivo.path], runInShell: true);
