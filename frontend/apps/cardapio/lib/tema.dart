import 'dart:ui' show FontVariation;

import 'package:flutter/material.dart';

/// Identidade do cardápio (Entre Nós · bar de piscina & bistrô): off-white e areia, verde profundo,
/// azul piscina e dourado suave, com tipografia serifada.
abstract final class Paleta {
  // fundos
  static const fundo = Color(0xFFF4EEE3); // off-white (também o texto sobre o verde)
  static const superficie = Color(0xFFFBF8F2);
  static const superficieAlta = Color(0xFFEDE4D3);
  static const areia = Color(0xFFE3CBA0);
  static const linha = Color(0xFFE0D3BC);
  // marca
  static const verde = Color(0xFF123F2D); // verde profundo: cor principal
  static const verdeMedio = Color(0xFF1F5A43);
  static const piscina = Color(0xFF2A8A86); // azul piscina
  static const dourado = Color(0xFFA7802C); // dourado para textos
  static const douradoSuave = Color(0xFFC9A04A); // dourado de ornamentos e bordas
  // texto
  static const texto = Color(0xFF1C2B23);
  static const textoSuave = Color(0xFF6F6A5D);
  // estados
  static const promocao = piscina;
  static const erro = Color(0xFFB3412E);
  static const sucesso = Color(0xFF2E7D5B);
  // sobre fotos (fundo escuro)
  static const sobreFoto = Color(0xFFFFFFFF);
  static const sobreFotoSuave = Color(0xCCFFFFFF);
  static const douradoClaro = Color(0xFFE9CF98);
}

/// Títulos em Playfair Display (fonte variável: o peso é aplicado também como variação).
TextStyle serifa(double tamanho,
        {FontWeight peso = FontWeight.w600, Color cor = Paleta.verde, double? altura, bool italico = false}) =>
    TextStyle(
      fontFamily: 'Playfair',
      fontSize: tamanho,
      fontWeight: peso,
      fontStyle: italico ? FontStyle.italic : FontStyle.normal,
      fontVariations: [FontVariation.weight(peso.value.toDouble())],
      color: cor,
      height: altura,
    );

/// Rótulo pequeno em caixa alta e espaçado (ex.: "BAR DE PISCINA & BISTRÔ").
TextStyle rotuloEspacado({Color cor = Paleta.verde, double tamanho = 11}) =>
    TextStyle(fontSize: tamanho, letterSpacing: 3, fontWeight: FontWeight.w600, color: cor);

ThemeData temaCardapio() {
  final esquema = ColorScheme.fromSeed(seedColor: Paleta.verde, brightness: Brightness.light).copyWith(
    primary: Paleta.verde,
    onPrimary: Paleta.fundo,
    secondary: Paleta.piscina,
    onSecondary: Colors.white,
    tertiary: Paleta.dourado,
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
    brightness: Brightness.light,
    colorScheme: esquema,
    scaffoldBackgroundColor: Paleta.fundo,
    appBarTheme: const AppBarTheme(backgroundColor: Paleta.fundo, foregroundColor: Paleta.verde, elevation: 0),
    cardTheme: CardThemeData(
      color: Paleta.superficie,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Paleta.linha),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Paleta.superficie,
      border: borda,
      enabledBorder: borda,
      focusedBorder: borda.copyWith(borderSide: const BorderSide(color: Paleta.verde, width: 1.4)),
      labelStyle: const TextStyle(color: Paleta.textoSuave),
      hintStyle: const TextStyle(color: Paleta.textoSuave),
      prefixIconColor: Paleta.verdeMedio,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Paleta.verde,
        foregroundColor: Paleta.fundo,
        disabledBackgroundColor: Paleta.linha,
        minimumSize: const Size(0, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 0.3),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Paleta.verde,
        side: const BorderSide(color: Paleta.douradoSuave),
        minimumSize: const Size(0, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: Paleta.verde)),
    chipTheme: ChipThemeData(
      backgroundColor: Paleta.superficie,
      selectedColor: Paleta.verde,
      side: const BorderSide(color: Paleta.linha),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      labelStyle: const TextStyle(color: Paleta.texto, fontWeight: FontWeight.w600),
      secondaryLabelStyle: const TextStyle(color: Paleta.fundo, fontWeight: FontWeight.w700),
      showCheckmark: false,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Paleta.fundo,
      showDragHandle: true,
      dragHandleColor: Paleta.douradoSuave,
    ),
    popupMenuTheme: const PopupMenuThemeData(color: Paleta.superficie),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dividerTheme: const DividerThemeData(color: Paleta.linha, space: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Paleta.verde),
  );
}
