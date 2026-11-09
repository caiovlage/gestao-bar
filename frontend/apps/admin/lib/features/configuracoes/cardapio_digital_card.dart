import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/providers.dart';
import '../../app/widgets/abrir_link/abrir_link.dart';

/// Endereço público do cardápio (mesmo servidor do painel, caminho /cardapio/).
String get urlCardapio => '$apiUrl/cardapio/';

/// Mensagem padrão para divulgar o cardápio no WhatsApp.
String mensagemWhatsApp() =>
    'Peça pelo nosso cardápio e receba no seu apartamento 🍻\n$urlCardapio';

/// Cartão em Configurações: link do cardápio para enviar pelo WhatsApp (e QR Code opcional).
class CardapioDigitalCard extends StatelessWidget {
  const CardapioDigitalCard({super.key});

  Future<void> _compartilhar(BuildContext context) async {
    final texto = mensagemWhatsApp();
    final abriu = await abrirLink('https://wa.me/?text=${Uri.encodeComponent(texto)}');
    if (!abriu && context.mounted) {
      await Clipboard.setData(ClipboardData(text: texto));
      if (context.mounted) mostrarSucesso(context, 'Mensagem copiada: cole no WhatsApp.');
    }
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
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Cardápio digital (pedidos para entrega)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    'Envie o link pelo WhatsApp. O cliente abre no navegador do celular, escolhe os produtos, '
                    'informa nome, bloco e apartamento e o pedido chega em Pedidos para preparar e entregar. '
                    'Aparecem no cardápio os produtos marcados "Disponível no cardápio digital", de categorias '
                    'visíveis no cardápio.',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                    decoration: BoxDecoration(color: AppCores.fundo, borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
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
                  ),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    FilledButton.icon(
                      onPressed: () => _compartilhar(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.chat),
                      label: const Text('Compartilhar no WhatsApp'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        if (!await abrirLink(urlCardapio) && context.mounted) {
                          mostrarErro(context, 'Abra o link em um navegador: $urlCardapio');
                        }
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Ver como o cliente'),
                    ),
                  ]),
                ],
              ),
            ),
            // QR Code opcional (ex.: cartaz no elevador ou na portaria)
            Column(mainAxisSize: MainAxisSize.min, children: [
              QrImageView(data: urlCardapio, size: 130, backgroundColor: Colors.white),
              Text('QR Code para cartazes', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ]),
          ],
        ),
      ),
    );
  }
}
