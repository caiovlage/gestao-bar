import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/providers.dart';

/// Endereço público do cardápio (mesmo servidor do painel, caminho /cardapio/).
String get urlCardapio => '$apiUrl/cardapio/';

/// Link do cardápio com o local já preenchido (ex.: ?mesa=12 ou ?local=Balcão).
String linkCardapio({int? mesa, String? local}) {
  if (mesa != null) return '$urlCardapio?mesa=$mesa';
  if (local != null) return '$urlCardapio?local=${Uri.encodeQueryComponent(local)}';
  return urlCardapio;
}

/// Folha de QR Codes para imprimir e colar nas mesas (Ctrl+P no navegador).
class QrCodesPage extends StatelessWidget {
  const QrCodesPage({super.key, required this.mesas, this.extras});

  final int mesas;

  /// Outros locais separados por vírgula (ex.: "Balcão,Retirada").
  final String? extras;

  @override
  Widget build(BuildContext context) {
    final locais = <(String, String)>[
      for (var i = 1; i <= mesas.clamp(0, 200); i++) ('Mesa $i', linkCardapio(mesa: i)),
      for (final e in (extras ?? '').split(',').map((e) => e.trim()).where((e) => e.isNotEmpty))
        (e, linkCardapio(local: e)),
    ];
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Voltar',
          onPressed: () => context.canPop() ? context.pop() : context.go('/configuracoes'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text('QR Codes · ${locais.length} locais'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(child: Text('Para imprimir: Ctrl+P')),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Wrap(
          spacing: 20,
          runSpacing: 20,
          children: [for (final (nome, link) in locais) _CartaoQr(nome: nome, link: link)],
        ),
      ),
    );
  }
}

class _CartaoQr extends StatelessWidget {
  const _CartaoQr({required this.nome, required this.link});

  final String nome;
  final String link;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400, width: 1.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Faça seu pedido', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        QrImageView(data: link, size: 180, backgroundColor: Colors.white),
        const SizedBox(height: 8),
        Text(nome, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text('Aponte a câmera do celular', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
      ]),
    );
  }
}

/// Cartão em Configurações: link do cardápio e geração dos QR Codes.
class CardapioDigitalCard extends StatefulWidget {
  const CardapioDigitalCard({super.key});

  @override
  State<CardapioDigitalCard> createState() => _CardapioDigitalCardState();
}

class _CardapioDigitalCardState extends State<CardapioDigitalCard> {
  final _mesas = TextEditingController(text: '10');
  final _extras = TextEditingController(text: 'Balcão');

  @override
  void dispose() {
    _mesas.dispose();
    _extras.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 24,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            QrImageView(data: urlCardapio, size: 140, backgroundColor: Colors.white),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Cardápio digital e QR Codes',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    'O cliente lê o QR Code da mesa, monta o pedido no celular e acompanha o preparo. '
                    'Os pedidos chegam em Pedidos. Aparecem no cardápio os produtos marcados '
                    '"Vende no cardápio", de categorias visíveis no cardápio.',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: SelectableText(urlCardapio, style: const TextStyle(fontWeight: FontWeight.w600))),
                    IconButton(
                      tooltip: 'Copiar link',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: urlCardapio));
                        mostrarSucesso(context, 'Link copiado.');
                      },
                      icon: const Icon(Icons.copy),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    SizedBox(
                      width: 140,
                      child: TextField(
                        controller: _mesas,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Nº de mesas'),
                      ),
                    ),
                    SizedBox(
                      width: 240,
                      child: TextField(
                        controller: _extras,
                        decoration: const InputDecoration(
                          labelText: 'Outros locais',
                          hintText: 'Balcão, Retirada',
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        final mesas = int.tryParse(_mesas.text.trim()) ?? 0;
                        context.push(Uri(path: '/qrcodes', queryParameters: {
                          'mesas': '$mesas',
                          'extras': _extras.text,
                        }).toString());
                      },
                      icon: const Icon(Icons.qr_code_2),
                      label: const Text('Gerar QR Codes'),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
