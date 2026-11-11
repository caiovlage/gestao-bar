import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app/router.dart';

void main() {
  usePathUrlStrategy();
  runApp(
    // Sem repetição automática de consultas com erro: o usuário decide quando tentar de novo.
    ProviderScope(retry: (tentativa, erro) => null, child: const AdminApp()),
  );
}

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Entre Nós · Painel',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.admin(),
      // No celular, versão compacta do tema; em tablet e computador nada muda.
      builder: (context, child) => ehCelular(context)
          ? Theme(data: AppTheme.admin(compacto: true), child: child ?? const SizedBox.shrink())
          : child ?? const SizedBox.shrink(),
      routerConfig: ref.watch(routerProvider),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
