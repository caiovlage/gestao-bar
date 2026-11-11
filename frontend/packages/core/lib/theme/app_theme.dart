import 'dart:ui' show FontVariation;

import 'package:flutter/material.dart';

/// Paleta da identidade visual: âmbar (cor de cerveja/bar) sobre neutros grafite.
abstract final class AppCores {
  // Identidade "Entre Nós": verde profundo, azul piscina, areia, off-white e dourado suave.
  static const verde = Color(0xFF123F2D);
  static const verdeMedio = Color(0xFF1F5A43);
  static const piscina = Color(0xFF2A8A86);
  static const areia = Color(0xFFE3CBA0);
  static const offWhite = Color(0xFFF4EEE3);
  static const linha = Color(0xFFE0D3BC);

  /// Destaque (antes âmbar): dourado suave.
  static const ambar = Color(0xFFC9A04A);

  /// Destaque para textos e ícones sobre fundo claro: dourado escuro.
  static const ambarEscuro = Color(0xFF8F6B1F);

  /// Texto sobre o dourado.
  static const sobreAmbar = verde;

  /// Menu lateral e barras (antes grafite): verde profundo.
  static const grafite = verde;
  static const grafiteClaro = verdeMedio;
  static const textoSidebar = Color(0xFFE9DFC9);
  static const fundo = offWhite;
  static const sucesso = Color(0xFF2E7D5B);
  static const alerta = Color(0xFFB7791F);
  static const perigo = Color(0xFFB3412E);
}

/// Títulos em Playfair Display (fonte do pacote core; o peso também vai como variação).
TextStyle estiloTitulo(double tamanho, {FontWeight peso = FontWeight.w600, Color? cor}) => TextStyle(
      fontFamily: 'Playfair',
      package: 'core',
      fontSize: tamanho,
      fontWeight: peso,
      fontVariations: [FontVariation.weight(peso.value.toDouble())],
      color: cor ?? AppCores.verde,
    );

abstract final class AppTheme {
  /// Tema do painel administrativo (claro, com menu lateral escuro).
  /// [compacto]: versão para celular (aplicada só em telas estreitas; desktop usa a normal).
  static ThemeData admin({bool compacto = false}) {
    final esquema = ColorScheme.fromSeed(
      seedColor: AppCores.verde,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppCores.verde,
      onPrimary: AppCores.offWhite,
      secondary: AppCores.piscina,
      onSecondary: Colors.white,
      tertiary: AppCores.ambar,
      error: AppCores.perigo,
      surface: const Color(0xFFFBF8F2),
    );

    final bordaCampo = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppCores.linha),
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
        color: const Color(0xFFFBF8F2),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppCores.linha),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFBF8F2),
        border: bordaCampo,
        enabledBorder: bordaCampo,
        focusedBorder: bordaCampo.copyWith(
          borderSide: const BorderSide(color: AppCores.verde, width: 1.6),
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
          foregroundColor: AppCores.verde,
          side: const BorderSide(color: AppCores.ambar),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      dividerTheme: const DividerThemeData(color: AppCores.linha, space: 1),
    );
  }
}
