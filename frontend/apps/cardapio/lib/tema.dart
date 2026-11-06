import 'dart:ui' show FontVariation;

import 'package:flutter/material.dart';

/// Identidade do cardápio: bar sofisticado — preto quente, dourado e tipografia serifada.
abstract final class Paleta {
  static const fundo = Color(0xFF0E0C0A);
  static const superficie = Color(0xFF181411);
  static const superficieAlta = Color(0xFF221D18);
  static const linha = Color(0xFF2F2822);
  static const ouro = Color(0xFFD4AF6A);
  static const ouroClaro = Color(0xFFE9CF98);
  static const ouroEscuro = Color(0xFF9C7B3F);
  static const texto = Color(0xFFF4EDE2);
  static const textoSuave = Color(0xFFA89C8C);
  static const promocao = Color(0xFFE2775B);
  static const erro = Color(0xFFF08A7E);
  static const sucesso = Color(0xFF7FCB8F);
}

/// Títulos em Playfair Display (fonte variável: o peso é aplicado também como variação).
TextStyle serifa(double tamanho, {FontWeight peso = FontWeight.w700, Color cor = Paleta.texto, double? altura}) =>
    TextStyle(
      fontFamily: 'Playfair',
      fontSize: tamanho,
      fontWeight: peso,
      fontVariations: [FontVariation.weight(peso.value.toDouble())],
      color: cor,
      height: altura,
    );

/// Rótulo pequeno em caixa alta e espaçado (ex.: "SUGESTÕES DA CASA").
TextStyle rotuloEspacado({Color cor = Paleta.ouro, double tamanho = 11}) =>
    TextStyle(fontSize: tamanho, letterSpacing: 2.4, fontWeight: FontWeight.w600, color: cor);

ThemeData temaCardapio() {
  final esquema = ColorScheme.fromSeed(seedColor: Paleta.ouro, brightness: Brightness.dark).copyWith(
    primary: Paleta.ouro,
    onPrimary: Paleta.fundo,
    secondary: Paleta.ouroClaro,
    surface: Paleta.superficie,
    onSurface: Paleta.texto,
    error: Paleta.erro,
  );
  final borda = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: Paleta.linha),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: esquema,
    scaffoldBackgroundColor: Paleta.fundo,
    appBarTheme: const AppBarTheme(backgroundColor: Paleta.fundo, foregroundColor: Paleta.texto, elevation: 0),
    cardTheme: CardThemeData(
      color: Paleta.superficie,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Paleta.superficieAlta,
      border: borda,
      enabledBorder: borda,
      focusedBorder: borda.copyWith(borderSide: const BorderSide(color: Paleta.ouro, width: 1.4)),
      labelStyle: const TextStyle(color: Paleta.textoSuave),
      hintStyle: const TextStyle(color: Paleta.textoSuave),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Paleta.ouro,
        foregroundColor: Paleta.fundo,
        disabledBackgroundColor: Paleta.linha,
        minimumSize: const Size(0, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 0.3),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Paleta.ouro,
        side: const BorderSide(color: Paleta.ouroEscuro),
        minimumSize: const Size(0, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Paleta.superficie,
      selectedColor: Paleta.ouro,
      side: const BorderSide(color: Paleta.linha),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      labelStyle: const TextStyle(color: Paleta.texto, fontWeight: FontWeight.w600),
      secondaryLabelStyle: const TextStyle(color: Paleta.fundo, fontWeight: FontWeight.w700),
      showCheckmark: false,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Paleta.superficie,
      showDragHandle: true,
      dragHandleColor: Paleta.linha,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dividerTheme: const DividerThemeData(color: Paleta.linha, space: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Paleta.ouro),
  );
}
