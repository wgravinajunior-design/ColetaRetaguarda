import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/config/config_service.dart';
import '../models/relatorio.dart';

/// Gera o PDF de um relatório e cuida da exportação e do envio.
class RelatorioPdfService {
  /// Pasta onde os PDFs gerados ficam, criada sob demanda.
  static Directory get pastaRelatorios {
    final base =
        Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    final dir = Directory(p.join(base, 'Documents', 'ColetaUp', 'Relatorios'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  static String _agora() {
    final d = DateTime.now();
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(d.day)}/${dois(d.month)}/${d.year} às ${dois(d.hour)}:${dois(d.minute)}';
  }

  static Future<Uint8List> gerar(
    DefinicaoRelatorio def,
    ResultadoRelatorio r,
  ) async {
    final doc = pw.Document();
    final config = ConfigService();

    pw.MemoryImage? logo;
    if (config.logoPath.isNotEmpty && File(config.logoPath).existsSync()) {
      try {
        logo = pw.MemoryImage(File(config.logoPath).readAsBytesSync());
      } catch (_) {
        // Logo ilegível não pode impedir a emissão do relatório.
      }
    }

    // Retrato até 5 colunas; a partir daí paisagem, senão a tabela espreme.
    final paisagem = r.colunas.length > 5;

    doc.addPage(
      pw.MultiPage(
        pageFormat: paisagem ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 32),
        header: (context) => context.pageNumber > 1
            ? pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Text(
                  def.nome,
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              )
            : pw.SizedBox(),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'ColetaUp · emitido em ${_agora()}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Text(
              'Página ${context.pageNumber} de ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
        build: (context) => [
          _cabecalho(def, r, logo),
          pw.SizedBox(height: 14),
          if (r.vazio)
            pw.Container(
              padding: const pw.EdgeInsets.all(24),
              alignment: pw.Alignment.center,
              child: pw.Text(
                'Nenhum registro encontrado para os filtros informados.',
                style: const pw.TextStyle(color: PdfColors.grey600),
              ),
            )
          else
            _tabela(r),
          if (r.totais.isNotEmpty) ...[pw.SizedBox(height: 14), _totais(r)],
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _cabecalho(
    DefinicaoRelatorio def,
    ResultadoRelatorio r,
    pw.MemoryImage? logo,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null) ...[
              pw.Image(logo, height: 42),
              pw.SizedBox(width: 14),
            ],
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    def.nome,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    def.descricao,
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  def.modulo.titulo.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue700,
                  ),
                ),
                if (r.descricaoFiltros.isNotEmpty)
                  pw.Text(
                    r.descricaoFiltros,
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(color: PdfColors.blue700, thickness: 1.2, height: 1),
      ],
    );
  }

  static pw.Widget _tabela(ResultadoRelatorio r) {
    return pw.TableHelper.fromTextArray(
      headers: r.colunas.map((c) => c.titulo).toList(),
      data: r.linhas,
      border: null,
      headerStyle: pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
      cellStyle: const pw.TextStyle(fontSize: 8.5),
      // Zebra: sem grade, é o que mantém as linhas legíveis.
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      cellHeight: 18,
      headerAlignments: {
        for (var i = 0; i < r.colunas.length; i++)
          i: r.colunas[i].alinhaDireita
              ? pw.Alignment.centerRight
              : pw.Alignment.centerLeft,
      },
      cellAlignments: {
        for (var i = 0; i < r.colunas.length; i++)
          i: r.colunas[i].alinhaDireita
              ? pw.Alignment.centerRight
              : pw.Alignment.centerLeft,
      },
      columnWidths: {
        for (var i = 0; i < r.colunas.length; i++)
          i: pw.FlexColumnWidth(r.colunas[i].flex.toDouble()),
      },
    );
  }

  static pw.Widget _totais(ResultadoRelatorio r) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Wrap(
        spacing: 28,
        runSpacing: 6,
        children: r.totais.entries
            .map(
              (e) => pw.Row(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(
                    '${e.key}: ',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey800,
                    ),
                  ),
                  pw.Text(
                    e.value,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  /// Abre a caixa de impressão / salvar como PDF do sistema.
  static Future<void> imprimir(
    DefinicaoRelatorio def,
    ResultadoRelatorio r,
  ) async {
    final bytes = await gerar(def, r);
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: _nomeArquivo(def),
    );
  }

  /// Grava o PDF na pasta de relatórios e devolve o arquivo.
  static Future<File> salvar(
    DefinicaoRelatorio def,
    ResultadoRelatorio r,
  ) async {
    final bytes = await gerar(def, r);
    final arquivo = File(p.join(pastaRelatorios.path, _nomeArquivo(def)));
    await arquivo.writeAsBytes(bytes);
    return arquivo;
  }

  static String _nomeArquivo(DefinicaoRelatorio def) {
    final d = DateTime.now();
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${def.id}_${d.year}${dois(d.month)}${dois(d.day)}_'
        '${dois(d.hour)}${dois(d.minute)}.pdf';
  }

  /// Abre o arquivo no visualizador padrão do sistema.
  static Future<void> abrir(File arquivo) =>
      Process.run('cmd', ['/c', 'start', '', arquivo.path], runInShell: true);

  /// Abre a pasta do arquivo já com ele selecionado.
  static Future<void> revelarNaPasta(File arquivo) =>
      Process.run('explorer', ['/select,', arquivo.path]);

  /// Abre uma conversa do WhatsApp com o resumo do relatório pronto.
  ///
  /// O WhatsApp não aceita anexo por link, então o arquivo vai por arrastar:
  /// a tela grava o PDF, abre a pasta com ele selecionado e traz o WhatsApp
  /// com o texto já escrito.
  static Future<void> abrirWhatsApp({
    required String texto,
    String? telefone,
  }) async {
    final numero = (telefone ?? '').replaceAll(RegExp(r'\D'), '');
    final destino = numero.isEmpty
        ? 'https://wa.me/?text=${Uri.encodeComponent(texto)}'
        : 'https://wa.me/${numero.length <= 11 ? '55$numero' : numero}'
              '?text=${Uri.encodeComponent(texto)}';
    await Process.run('cmd', ['/c', 'start', '', destino], runInShell: true);
  }

  /// Mensagem que acompanha o envio.
  static String mensagemWhatsApp(DefinicaoRelatorio def, ResultadoRelatorio r) {
    final b = StringBuffer()
      ..writeln('*${def.nome}*')
      ..writeln(r.descricaoFiltros)
      ..writeln();
    for (final t in r.totais.entries) {
      b.writeln('${t.key}: *${t.value}*');
    }
    b
      ..writeln()
      ..writeln('_Emitido pelo ColetaUp em ${_agora()}_');
    return b.toString();
  }
}
