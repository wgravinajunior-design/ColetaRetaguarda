import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Barra de rolagem sempre à vista, em toda tela que rola.
///
/// O padrão do Flutter no Windows só mostra a barra enquanto se rola, e ela
/// some logo depois. Numa tela cheia isso esconde a informação mais útil que a
/// barra dá: que ainda há conteúdo abaixo. Aqui ela fica visível o tempo todo,
/// com a trilha desenhada, e pode ser arrastada com o mouse.
///
/// Vale para tudo: listas, formulários, o menu lateral e as tabelas que rolam
/// para o lado. Como está no [MaterialApp], nenhuma tela precisa se preocupar
/// com isso — inclusive as que vierem depois.
class RolagemSempreVisivel extends MaterialScrollBehavior {
  const RolagemSempreVisivel();

  /// Permite arrastar o conteúdo com o botão do mouse, e não só pela roda.
  /// Ajuda em tabelas largas, onde rolar para o lado é desajeitado.
  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Sem controlador não dá para manter o polegar fixo: a barra precisa saber
    // a posição para se desenhar antes da primeira rolagem. Nesse caso vale o
    // comportamento normal, que aparece ao rolar, em vez de estourar.
    final temControlador = details.controller != null;

    return Scrollbar(
      controller: details.controller,
      thumbVisibility: temControlador,
      trackVisibility: temControlador,
      interactive: true,
      child: child,
    );
  }
}
