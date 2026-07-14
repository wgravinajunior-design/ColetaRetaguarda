import 'dart:convert';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/parada_model.dart';
import '../screens/pagamentos_screen.dart' show PagamentoProdutor;
import '../../rotas/models/rota_model.dart';

/// Gera e imprime/compartilha o comprovante de coleta de uma rota em PDF.
class ComprovanteService {
  String _statusLabel(String status) {
    switch (status) {
      case 'P':
        return 'Pendente';
      case 'E':
        return 'Em Andamento';
      case 'C':
        return 'Concluida';
      case 'R':
        return 'Recusada';
      default:
        return status;
    }
  }

  String _dataHoje() {
    final d = DateTime.now();
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(d.day)}/${dois(d.month)}/${d.year} ${dois(d.hour)}:${dois(d.minute)}';
  }

  Future<void> imprimirComprovanteRota({
    required RotaModel rota,
    required List<ParadaModel> paradas,
  }) async {
    final doc = pw.Document();

    final concluidas = paradas.where((p) => p.status == 'C').toList();
    final totalLitros = concluidas.fold<double>(0, (s, p) => s + (p.volume ?? 0));
    final temps = concluidas.where((p) => p.temperatura != null).map((p) => p.temperatura!).toList();
    final tempMedia = temps.isEmpty ? null : temps.reduce((a, b) => a + b) / temps.length;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Cabecalho
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Comprovante de Coleta',
                    style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('ColetaUp', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
              ],
            ),
          ),
          pw.SizedBox(height: 8),

          // Dados da rota
          _infoLinha('Rota', rota.descricao),
          _infoLinha('Regiao', rota.regiao ?? '-'),
          _infoLinha('Status da rota', rota.status),
          _infoLinha('Emitido em', _dataHoje()),
          pw.SizedBox(height: 16),

          // Resumo
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _resumoItem('Paradas', '${paradas.length}'),
                _resumoItem('Concluidas', '${concluidas.length}'),
                _resumoItem('Total coletado', '${totalLitros.toStringAsFixed(0)} L'),
                _resumoItem('Temp. media', tempMedia == null ? '-' : '${tempMedia.toStringAsFixed(1)} C'),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Tabela de paradas
          pw.Text('Paradas', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.center,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
            },
            headers: ['Produtor', 'CNPJ/CPF', 'Status', 'Temp.', 'Volume'],
            data: paradas.map((p) {
              return [
                p.pessoaNome,
                p.cnpjCpf,
                _statusLabel(p.status),
                p.temperatura != null ? '${p.temperatura!.toStringAsFixed(1)} C' : '-',
                p.volume != null ? '${p.volume!.toStringAsFixed(0)} L' : '-',
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 24),

          // Assinaturas
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _campoAssinatura('Motorista'),
              _campoAssinatura('Responsavel'),
            ],
          ),
        ],
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Pagina ${context.pageNumber}/${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
          ),
        ),
      ),
    );

    // Abre a caixa de dialogo de impressao / compartilhamento
    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'comprovante_${rota.descricao}',
    );
  }

  /// Recibo individual de uma coleta (parada), com foto e assinatura.
  Future<void> imprimirReciboParada(ParadaModel parada) async {
    final doc = pw.Document();

    // Carrega imagens, se existirem
    pw.MemoryImage? foto;
    if (parada.fotoPath != null && File(parada.fotoPath!).existsSync()) {
      foto = pw.MemoryImage(File(parada.fotoPath!).readAsBytesSync());
    }
    pw.MemoryImage? assinatura;
    if (parada.assinaturaBase64 != null) {
      try {
        assinatura = pw.MemoryImage(base64Decode(parada.assinaturaBase64!));
      } catch (_) {}
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Recibo de Coleta',
                style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.Text('ColetaUp', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
            pw.Divider(),
            pw.SizedBox(height: 8),
            _infoLinha('Produtor', parada.pessoaNome),
            _infoLinha('CNPJ/CPF', parada.cnpjCpf),
            _infoLinha('Endereco', parada.endereco),
            _infoLinha('Status', _statusLabel(parada.status)),
            _infoLinha('Temperatura', parada.temperatura != null ? '${parada.temperatura!.toStringAsFixed(1)} C' : '-'),
            _infoLinha('Volume', parada.volume != null ? '${parada.volume!.toStringAsFixed(0)} L' : '-'),
            if (parada.horarioChegada != null)
              _infoLinha('Chegada', _formatarIso(parada.horarioChegada!)),
            if (parada.gpsCapturaLatitude != null)
              _infoLinha('GPS', '${parada.gpsCapturaLatitude!.toStringAsFixed(6)}, ${parada.gpsCapturaltitude?.toStringAsFixed(6) ?? '-'}'),
            _infoLinha('Emitido em', _dataHoje()),
            pw.SizedBox(height: 16),
            if (foto != null) ...[
              pw.Text('Foto da coleta', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.SizedBox(height: 4),
              pw.Container(
                height: 200,
                alignment: pw.Alignment.centerLeft,
                child: pw.Image(foto, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(height: 16),
            ],
            pw.Spacer(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (assinatura != null)
                      pw.Container(width: 180, height: 60, child: pw.Image(assinatura))
                    else
                      pw.SizedBox(width: 180, height: 60),
                    pw.Container(width: 180, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 4),
                    pw.Text('Assinatura do Produtor', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                _campoAssinatura('Motorista'),
              ],
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'recibo_${parada.pessoaNome}',
    );
  }

  /// Relatório de pagamentos por produtor.
  Future<void> imprimirRelatorioPagamentos({
    required List<PagamentoProdutor> pagamentos,
    required double precoLitro,
  }) async {
    final doc = pw.Document();
    final totalLitros = pagamentos.fold<double>(0, (s, p) => s + p.totalLitros);
    final totalValor = pagamentos.fold<double>(0, (s, p) => s + p.totalLitros * precoLitro);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Relatorio de Pagamentos',
                    style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.Text('ColetaUp', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          _infoLinha('Preco por litro', 'R\$ ${precoLitro.toStringAsFixed(2)}'),
          _infoLinha('Produtores', '${pagamentos.length}'),
          _infoLinha('Emitido em', _dataHoje()),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.center,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
            },
            headers: ['Produtor', 'CNPJ/CPF', 'Coletas', 'Litros', 'Valor (R\$)'],
            data: pagamentos.map((p) {
              return [
                p.nome,
                p.cnpjCpf,
                '${p.qtdColetas}',
                p.totalLitros.toStringAsFixed(0),
                (p.totalLitros * precoLitro).toStringAsFixed(2),
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Total: ${totalLitros.toStringAsFixed(0)} L  |  R\$ ${totalValor.toStringAsFixed(2)}',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'relatorio_pagamentos',
    );
  }

  String _formatarIso(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(d.day)}/${dois(d.month)}/${d.year} ${dois(d.hour)}:${dois(d.minute)}';
  }

  pw.Widget _infoLinha(String label, String valor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text('$label:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
          ),
          pw.Text(valor, style: const pw.TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  pw.Widget _resumoItem(String label, String valor) {
    return pw.Column(
      children: [
        pw.Text(valor, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      ],
    );
  }

  pw.Widget _campoAssinatura(String label) {
    return pw.Column(
      children: [
        pw.Container(width: 180, height: 1, color: PdfColors.black),
        pw.SizedBox(height: 4),
        pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }
}
