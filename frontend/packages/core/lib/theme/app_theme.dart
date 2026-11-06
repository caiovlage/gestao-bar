import 'package:flutter/material.dart';

/// Paleta da identidade visual: âmbar (cor de cerveja/bar) sobre neutros grafite.
abstract final class AppCores {
  static const ambar = Color(0xFFF59E0B);
  static const ambarEscuro = Color(0xFFB45309);
  static const sobreAmbar = Color(0xFF1C1917);
  static const grafite = Color(0xFF1F2328);
  static const grafiteClaro = Color(0xFF2D333B);
  static const textoSidebar = Color(0xFFD1D5DB);
  static const fundo = Color(0xFFF6F6F4);
  static const sucesso = Color(0xFF15803D);
  static const alerta = Color(0xFFB45309);
  static const perigo = Color(0xFFB91C1C);
}

abstract final class AppTheme {
  /// Tema do painel administrativo (claro, com menu lateral escuro).
  /// [compacto]: versão para celular (aplicada só em telas estreitas; desktop usa a normal).
  static ThemeData admin({bool compacto = false}) {
    final esquema = ColorScheme.fromSeed(
      seedColor: AppCores.ambar,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppCores.ambar,
      onPrimary: AppCores.sobreAmbar,
      secondary: AppCores.grafite,
      onSecondary: Colors.white,
      error: AppCores.perigo,
      surface: Colors.white,
    );

    final bordaCampo = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade300),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: esquema,
      scaffoldBackgroundColor: AppCores.fundo,
      visualDensity: compacto ? VisualDensity.compact : VisualDensity.standard,
      dialogTheme: compacto
          ? const DialogThemeData(insetPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 20))
          : null,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppCores.grafite,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: bordaCampo,
        enabledBorder: bordaCampo,
        focusedBorder: bordaCampo.copyWith(
          borderSide: const BorderSide(color: AppCores.ambarEscuro, width: 1.6),
        ),
        contentPadding: compacto
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 11)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size(0, compacto ? 40 : 46),
          padding: EdgeInsets.symmetric(horizontal: compacto ? 14 : 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(0, compacto ? 40 : 46),
          foregroundColor: AppCores.grafite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      dividerTheme: DividerThemeData(color: Colors.grey.shade200, space: 1),
    );
  }
}
