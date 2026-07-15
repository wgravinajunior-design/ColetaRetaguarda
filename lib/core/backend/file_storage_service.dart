import 'dart:io';
import 'package:path/path.dart' as path;

/// Serviço para armazenar arquivos de upload (fotos, etc)
class FileStorageService {
  static const String uploadsDir = 'uploads';
  static const String paradasDir = 'paradas';
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB

  /// Diretório base para uploads
  static Directory getUploadsDirectory() {
    final dir = Directory(uploadsDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// Diretório específico para paradas
  static Directory getParadasDirectory() {
    final dir = Directory(path.join(uploadsDir, paradasDir));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// Salva arquivo de foto
  static Future<String?> saveFoto(int paradaId, List<int> bytes) async {
    try {
      // Validar tamanho
      if (bytes.length > maxFileSize) {
        throw Exception('Arquivo excede 10MB');
      }

      // Criar nome do arquivo
      final filename = 'parada_${paradaId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filepath = path.join(getParadasDirectory().path, filename);

      // Salvar arquivo
      final file = File(filepath);
      await file.writeAsBytes(bytes);

      // Retornar caminho relativo
      return 'uploads/paradas/$filename';
    } catch (e) {
      return null;
    }
  }

  /// Valida arquivo JPEG/PNG
  static bool isValidImage(List<int> bytes) {
    if (bytes.isEmpty) return false;

    // Verificar magic number
    // JPEG: FF D8 FF
    // PNG: 89 50 4E 47
    if (bytes.length >= 3) {
      if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
        return true; // JPEG
      }
    }

    if (bytes.length >= 4) {
      if (bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        return true; // PNG
      }
    }

    return false;
  }

  /// Remove arquivo antigo
  static Future<void> deleteFile(String relativePath) async {
    try {
      final file = File(path.join(uploadsDir, relativePath));
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (e) {
      // Ignorar erro ao deletar
    }
  }
}
