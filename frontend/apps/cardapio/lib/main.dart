import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'cardapio_page.dart';
import 'dados.dart';
import 'pedido_page.dart';
import 'tema.dart';

void main() {
  runApp(const CardapioApp());
  // Tira a tela de carregamento do index.html assim que o app desenhar a primeira tela
  // (não depende só do evento do Flutter, que pode não ser disparado).
  WidgetsBinding.instance.addPostFrameCallback((_) => _removerCarregandoHtml());
}

void _removerCarregandoHtml() {
  try {
    if (globalContext.has('removerCarregando')) {
      globalContext.callMethod('removerCarregando'.toJS);
    }
  } catch (_) {
    // sem a tela de carregamento (ex.: execução fora do navegador): nada a fazer
  }
}

class CardapioApp extends StatelessWidget {
  const CardapioApp({super.key});

  /// Rotas nomeadas: no navegador cada tela vira uma entrada do histórico (#/pedido/…),
  /// então o botão "voltar" do celular funciona como o cliente espera.
  static Route<void>? _rota(RouteSettings settings) {
    final nome = settings.name ?? '/';
    if (nome.startsWith('/pedido/') && nome.length > '/pedido/'.length) {
      final inicial = settings.arguments is Acompanhamento ? settings.arguments as Acompanhamento : null;
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => PedidoPage(pedidoId: nome.substring('/pedido/'.length), inicial: inicial),
      );
    }
    return MaterialPageRoute(settings: const RouteSettings(name: '/'), builder: (_) => const CardapioPage());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cardápio',
      debugShowCheckedModeBanner: false,
      theme: temaCardapio(),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      onGenerateRoute: _rota,
    );
  }
}
