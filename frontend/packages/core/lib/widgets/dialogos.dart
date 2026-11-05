import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../theme/app_theme.dart';

/// Pede confirmação para operações críticas. Retorna true se o usuário confirmar.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensagem,
  String acao = 'Confirmar',
  bool perigoso = false,
}) async {
  final resultado = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(titulo),
      content: Text(mensagem),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(
          style: perigoso
              ? FilledButton.styleFrom(backgroundColor: AppCores.perigo, foregroundColor: Colors.white)
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(acao),
        ),
      ],
    ),
  );
  return resultado ?? false;
}

void mostrarSucesso(BuildContext context, String mensagem) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(child: Text(mensagem)),
        ]),
        backgroundColor: AppCores.sucesso,
      ),
    );
}

void mostrarErro(BuildContext context, Object erro) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(child: Text(mensagemDeErro(erro))),
        ]),
        backgroundColor: AppCores.perigo,
      ),
    );
}
