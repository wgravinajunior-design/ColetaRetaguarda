import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../app_info.dart';
import '../paths/app_paths.dart';

/// Uma versão publicada no GitHub Releases.
class VersaoDisponivel {
  final String versao;
  final String notas;
  final String urlDownload;
  final int tamanhoBytes;

  const VersaoDisponivel({
    required this.versao,
    required this.notas,
    required this.urlDownload,
    required this.tamanhoBytes,
  });
}

/// Verifica e aplica atualizações a partir das releases públicas do GitHub.
///
/// O repositório é público de propósito: assim o download do asset não exige
/// token embutido no executável.
class UpdateService {
  static const _timeout = Duration(seconds: 12);

  /// Arquivo que guarda a última versão para a qual já mostramos as novidades.
  static File get _arquivoVersaoVista =>
      File(p.join(AppPaths.dataDir.path, 'ultima_versao_vista'));

  /// Consulta a última release. Retorna null se já estamos atualizados, se não
  /// há release publicada, ou se a rede falhou — nunca lança: uma checagem de
  /// atualização não pode impedir o sistema de abrir.
  static Future<VersaoDisponivel?> verificar() async {
    try {
      final resposta = await http
          .get(
            Uri.parse(
              'https://api.github.com/repos/$repoAtualizacao/releases/latest',
            ),
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(_timeout);

      if (resposta.statusCode != 200) return null;

      final json = jsonDecode(resposta.body) as Map<String, dynamic>;
      final tag = (json['tag_name'] as String?)?.replaceFirst('v', '') ?? '';
      if (tag.isEmpty || !ehMaisNova(tag, appVersao)) return null;

      // Pega o primeiro asset .zip da release (o pacote do Windows).
      final assets = (json['assets'] as List?) ?? const [];
      final zip = assets.cast<Map<String, dynamic>>().firstWhere(
        (a) => (a['name'] as String? ?? '').toLowerCase().endsWith('.zip'),
        orElse: () => <String, dynamic>{},
      );
      final url = zip['browser_download_url'] as String?;
      if (url == null) return null;

      return VersaoDisponivel(
        versao: tag,
        notas: (json['body'] as String?) ?? '',
        urlDownload: url,
        tamanhoBytes: (zip['size'] as int?) ?? 0,
      );
    } catch (e) {
      debugPrint('Falha ao verificar atualização: $e');
      return null;
    }
  }

  /// Compara duas versões no formato `x.y.z`.
  static bool ehMaisNova(String candidata, String atual) {
    List<int> partes(String v) => v
        .split('+')
        .first
        .split('.')
        .map((s) => int.tryParse(s.trim()) ?? 0)
        .toList();

    final a = partes(candidata);
    final b = partes(atual);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  /// Baixa o pacote, reportando o progresso de 0 a 1.
  static Future<File> baixar(
    VersaoDisponivel versao, {
    void Function(double)? aoProgredir,
  }) async {
    final destino = File(
      p.join(
        Directory.systemTemp.path,
        'ColetaRetaguarda-${versao.versao}.zip',
      ),
    );

    final cliente = http.Client();
    try {
      final requisicao = http.Request('GET', Uri.parse(versao.urlDownload));
      final resposta = await cliente.send(requisicao);
      if (resposta.statusCode != 200) {
        throw Exception('Download falhou (HTTP ${resposta.statusCode})');
      }

      final total = resposta.contentLength ?? versao.tamanhoBytes;
      final saida = destino.openWrite();
      var recebido = 0;

      await for (final pedaco in resposta.stream) {
        saida.add(pedaco);
        recebido += pedaco.length;
        if (total > 0) aoProgredir?.call(recebido / total);
      }
      await saida.close();
      return destino;
    } finally {
      cliente.close();
    }
  }

  /// Aplica a atualização e reinicia o aplicativo.
  ///
  /// O Windows não deixa sobrescrever um executável em uso, então quem troca os
  /// arquivos é um .bat: ele espera este processo morrer, extrai o pacote por
  /// cima da instalação, reabre o app e se apaga.
  static Future<void> aplicar(File pacote) async {
    final pastaInstalacao = File(Platform.resolvedExecutable).parent.path;
    final exe = Platform.resolvedExecutable;
    final pid = pid_();

    final bat = File(p.join(Directory.systemTemp.path, 'coleta-atualizar.bat'));

    await bat.writeAsString('''
@echo off
rem Espera o Coleta fechar antes de trocar os arquivos.
:aguardar
tasklist /FI "PID eq $pid" 2>nul | find "$pid" >nul
if not errorlevel 1 (
  timeout /t 1 /nobreak >nul
  goto aguardar
)
powershell -NoProfile -Command "Expand-Archive -LiteralPath '${pacote.path}' -DestinationPath '$pastaInstalacao' -Force"
start "" "$exe"
del "%~f0"
''');

    await Process.start(
      'cmd',
      ['/c', bat.path],
      mode: ProcessStartMode.detached,
      runInShell: true,
    );

    exit(0);
  }

  static int pid_() => pid;

  /// Versão cujas novidades o usuário já viu.
  static Future<String?> versaoVista() async {
    try {
      final f = _arquivoVersaoVista;
      if (!await f.exists()) return null;
      return (await f.readAsString()).trim();
    } catch (_) {
      return null;
    }
  }

  static Future<void> marcarVersaoVista(String versao) async {
    try {
      await _arquivoVersaoVista.writeAsString(versao);
    } catch (e) {
      debugPrint('Não foi possível gravar a versão vista: $e');
    }
  }

  /// Notas da release da versão em execução, para o popup de novidades.
  static Future<String?> notasDaVersaoAtual() async {
    try {
      final resposta = await http
          .get(
            Uri.parse(
              'https://api.github.com/repos/$repoAtualizacao/releases/tags/v$appVersao',
            ),
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(_timeout);
      if (resposta.statusCode != 200) return null;
      final json = jsonDecode(resposta.body) as Map<String, dynamic>;
      return json['body'] as String?;
    } catch (_) {
      return null;
    }
  }
}
