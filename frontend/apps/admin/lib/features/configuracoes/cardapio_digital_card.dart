import 'dart:ui' as ui;

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/providers.dart';
import '../../app/widgets/abrir_link/abrir_link.dart';
import '../../app/widgets/download/download.dart';

/// Endereço público do cardápio (mesmo servidor do painel, caminho /cardapio/).
String get urlCardapio => '$apiUrl/cardapio/';

/// Mensagem padrão para divulgar o cardápio no WhatsApp.
String mensagemWhatsApp() =>
    'Peça pelo nosso cardápio e receba no seu apartamento 🍻\n$urlCardapio';

/// QR Code do cardápio com a taça do logo no centro. Usa correção de erros máxima (H, ~30%),
/// então o logo cobrindo o meio não impede a leitura.
class QrCodeCardapio extends StatelessWidget {
  const QrCodeCardapio({super.key, required this.tamanho});

  final double tamanho;

  @override
  Widget build(BuildContext context) {
    final logo = tamanho * 0.22;
    return SizedBox(
      width: tamanho,
      height: tamanho,
      child: Stack(alignment: Alignment.center, children: [
        QrImageView(
          data: urlCardapio,
          size: tamanho,
          backgroundColor: Colors.white,
          errorCorrectionLevel: QrErrorCorrectLevel.H,
          gapless: true,
        ),
        // anel branco separa o logo dos módulos do QR
        Container(
          width: logo,
          height: logo,
          padding: EdgeInsets.all(logo * 0.08),
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: Container(
            decoration: const BoxDecoration(color: AppCores.ambar, shape: BoxShape.circle),
            child: Icon(Icons.local_bar, size: logo * 0.55, color: AppCores.sobreAmbar),
          ),
        ),
      ]),
    );
  }
}

/// Cartão em Configurações: link do cardápio para enviar pelo WhatsApp (e QR Code opcional).
class CardapioDigitalCard extends StatefulWidget {
  const CardapioDigitalCard({super.key});

  @override
  State<CardapioDigitalCard> createState() => _CardapioDigitalCardState();
}

class _CardapioDigitalCardState extends State<CardapioDigitalCard> {
  final _qr = GlobalKey();

  /// Salva o QR Code exibido como PNG em alta resolução (~1.300 px), para impressão.
  Future<void> _baixarQr() async {
    try {
      final objeto = _qr.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (objeto == null) return;
      final imagem = await objeto.toImage(pixelRatio: 8);
      final png = await imagem.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) return;
      final ok = await baixarArquivo(png.buffer.asUint8List(), 'qrcode-cardapio.png', 'image/png');
      if (!ok && mounted) mostrarErro(context, 'Baixar imagem só está disponível no navegador.');
    } catch (e) {
      if (mounted) mostrarErro(context, e);
    }
  }

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
              RepaintBoundary(key: _qr, child: const QrCodeCardapio(tamanho: 160)),
              const SizedBox(height: 6),
              Text('QR Code para cartazes', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              TextButton.icon(
                onPressed: _baixarQr,
                icon: const Icon(Icons.download),
                label: const Text('Baixar QR Code (PNG)'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
