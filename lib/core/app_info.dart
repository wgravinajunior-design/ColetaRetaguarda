import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Versão em execução, lida do próprio pacote.
///
/// Antes era uma constante mantida à mão em paralelo ao `version:` do
/// `pubspec.yaml`. Bastava esquecer de sincronizar para o app comparar a
/// versão errada com a última tag do GitHub — deixando de oferecer uma
/// atualização que existe, ou oferecendo uma que já está instalada.
class AppInfo {
  const AppInfo._();

  /// Vale até [carregar] terminar; a interface só consulta depois disso.
  static String _versao = '0.0.0';

  static String get versao => _versao;

  /// Lê a versão do bundle. Chamada uma vez no bootstrap.
  static Future<void> carregar() async {
    try {
      final info = await PackageInfo.fromPlatform();
      // No Windows a versão do pacote vem como "2.8.0+11": o sufixo de build
      // não entra na comparação com a tag do GitHub nem na exibição.
      final limpa = info.version.split('+').first.trim();
      if (limpa.isNotEmpty) _versao = limpa;
    } catch (e) {
      // Sem a versão o app ainda funciona; só a checagem de atualização fica
      // sem referência, e ela já trata a falha sozinha.
      debugPrint('Não foi possível ler a versão do pacote: $e');
    }
  }
}

/// Atalho usado pela interface e pelo verificador de atualização.
String get appVersao => AppInfo.versao;

/// Repositório de onde saem as atualizações (releases públicas).
const String repoAtualizacao = 'wgravinajunior-design/ColetaRetaguarda';
