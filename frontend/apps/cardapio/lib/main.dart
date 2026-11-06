import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'cardapio_page.dart';

void main() {
  runApp(const CardapioApp());
}

class CardapioApp extends StatelessWidget {
  const CardapioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cardápio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.cardapio(),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const CardapioPage(),
    );
  }
}
