import 'dart:io';
import 'package:path/path.dart' as p;

/// Diretórios usados pelo app em disco.
///
/// Instalado em `Program Files`, a pasta do executável não é gravável por
/// usuários sem elevação: config e banco local ficam em `%APPDATA%`.
class AppPaths {
  static const _appFolder = 'ColetaRetaguarda';

  static Directory? _cachedDataDir;
  static File? _cachedConfigFile;

  /// Pasta gravável de dados do usuário, já criada.
  static Directory get dataDir {
    final cached = _cachedDataDir;
    if (cached != null) return cached;

    final base = Platform.environment['APPDATA'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    final dir = Directory(p.join(base, _appFolder));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return _cachedDataDir = dir;
  }

  /// Caminho do `conf.ini`.
  ///
  /// Mantém um arquivo já existente no diretório atual ou ao lado do
  /// executável (uso portátil e desenvolvimento); senão usa [dataDir].
  static File get configFile {
    final cached = _cachedConfigFile;
    if (cached != null) return cached;

    final besideExe = File(
      p.join(File(Platform.resolvedExecutable).parent.path, 'conf.ini'),
    );

    for (final candidate in [File('conf.ini'), besideExe]) {
      if (candidate.existsSync() && _isWritable(candidate)) {
        return _cachedConfigFile = candidate;
      }
    }

    final userFile = File(p.join(dataDir.path, 'conf.ini'));
    // Aproveita uma config anterior que tenha ficado em pasta somente leitura.
    if (!userFile.existsSync() && besideExe.existsSync()) {
      besideExe.copySync(userFile.path);
    }
    return _cachedConfigFile = userFile;
  }

  static bool _isWritable(File file) {
    try {
      file.openSync(mode: FileMode.append).closeSync();
      return true;
    } on FileSystemException {
      return false;
    }
  }
}
