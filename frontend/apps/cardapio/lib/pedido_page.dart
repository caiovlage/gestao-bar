import 'dart:async';

import 'package:core/core.dart' show formatarMoeda, mensagemDeErro;
import 'package:flutter/material.dart';

import 'dados.dart';
import 'tema.dart';

/// Rota com o id do pedido (ex.: #/pedido/…): entra no histórico do navegador, então o botão
/// "voltar" do celular retorna ao cardápio, e o link pode ser reaberto para acompanhar o pedido.
String rotaPedido(String id) => '/pedido/$id';

/// Acompanhamento do pedido pelo cliente: consulta o status a cada 8 segundos até finalizar.
class PedidoPage extends StatefulWidget {
  const PedidoPage({super.key, required this.pedidoId, this.inicial});

  final String pedidoId;
  final Acompanhamento? inicial;

  @override
  State<PedidoPage> createState() => _PedidoPageState();
}

class _PedidoPageState extends State<PedidoPage> {
  late Acompanhamento? _pedido = widget.inicial;
  Timer? _timer;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _atualizar();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _atualizar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _atualizar() async {
    try {
      final p = await buscarPedido(widget.pedidoId);
      if (!mounted) return;
      setState(() {
        _pedido = p;
        _erro = null;
      });
      if (p.finalizado) _timer?.cancel();
    } catch (e) {
      if (mounted) setState(() => _erro = mensagemDeErro(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _pedido;
    return Scaffold(
      appBar: AppBar(title: Text(p == null ? 'Seu pedido' : 'Pedido nº ${p.numero}')),
      body: p == null
          ? Center(child: _erro == null ? const CircularProgressIndicator() : Text(_erro!))
          : RefreshIndicator(
              onRefresh: _atualizar,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        _Cabecalho(pedido: p),
                        const SizedBox(height: 24),
                        if (p.etapa != EtapaPedido.cancelado) _Linha(etapa: p.etapa),
                        if (p.motivoCancelamento != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text('Motivo: ${p.motivoCancelamento}', textAlign: TextAlign.center),
                          ),
                        const SizedBox(height: 24),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              Text('${p.local} · ${p.clienteNome}', style: const TextStyle(fontWeight: FontWeight.w700)),
                              const Divider(height: 24),
                              for (final i in p.itens)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text('${i.quantidade}× ${i.produtoNome}'),
                                        if (i.observacao != null)
                                          Text(i.observacao!,
                                              style: const TextStyle(fontSize: 13, color: Paleta.textoSuave)),
                                      ]),
                                    ),
                                    Text(formatarMoeda(i.total)),
                                  ]),
                                ),
                              if (p.observacao != null) Text('Obs.: ${p.observacao}'),
                              const Divider(height: 24),
                              Row(children: [
                                const Expanded(child: Text('Total', style: TextStyle(fontSize: 16))),
                                Text(formatarMoeda(p.total), style: serifa(24, cor: Paleta.verde)),
                              ]),
                              const SizedBox(height: 4),
                              Text(
                                p.pago ? 'Pagamento recebido. Obrigado!' : 'Pagamento na entrega.',
                                style: TextStyle(
                                  color: p.pago ? Paleta.sucesso : Paleta.textoSuave,
                                  fontSize: 13,
                                ),
                              ),
                            ]),
                          ),
                        ),
                        if (_erro != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text('Sem conexão no momento — tentando de novo…',
                                textAlign: TextAlign.center, style: TextStyle(color: Colors.orange.shade300)),
                          ),
                        const SizedBox(height: 24),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).canPop()
                              ? Navigator.pop(context)
                              : Navigator.of(context).pushReplacementNamed('/'),
                          icon: const Icon(Icons.restaurant_menu),
                          label: const Text('Voltar ao cardápio'),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.pedido});

  final Acompanhamento pedido;

  @override
  Widget build(BuildContext context) {
    final cancelado = pedido.etapa == EtapaPedido.cancelado;
    final cor = cancelado ? Paleta.erro : Paleta.verde;
    return Column(children: [
      const SizedBox(height: 8),
      CircleAvatar(
        radius: 40,
        backgroundColor: cor.withValues(alpha: 0.15),
        child: Icon(
          switch (pedido.etapa) {
            EtapaPedido.recebido => Icons.hourglass_top,
            EtapaPedido.aceito => Icons.thumb_up_alt_outlined,
            EtapaPedido.emPreparo => Icons.soup_kitchen_outlined,
            EtapaPedido.pronto => Icons.room_service_outlined,
            EtapaPedido.entregue => Icons.celebration_outlined,
            EtapaPedido.cancelado => Icons.cancel_outlined,
          },
          size: 40,
          color: cor,
        ),
      ),
      const SizedBox(height: 12),
      Text(pedido.etapa.titulo,
          textAlign: TextAlign.center, style: serifa(30)),
      const SizedBox(height: 4),
      Text(pedido.etapa.descricao, textAlign: TextAlign.center, style: const TextStyle(color: Paleta.textoSuave)),
    ]);
  }
}

/// Linha do tempo: Enviado → Confirmado → Em preparo → Pronto → Entregue.
class _Linha extends StatelessWidget {
  const _Linha({required this.etapa});

  final EtapaPedido etapa;

  static const _passos = [
    (EtapaPedido.recebido, 'Enviado'),
    (EtapaPedido.aceito, 'Confirmado'),
    (EtapaPedido.emPreparo, 'Preparo'),
    (EtapaPedido.pronto, 'Pronto'),
    (EtapaPedido.entregue, 'Entregue'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (var i = 0; i < _passos.length; i++) ...[
        if (i > 0)
          Expanded(
            child: Container(
              height: 3,
              margin: const EdgeInsets.only(bottom: 22),
              color: etapa.index >= _passos[i].$1.index ? Paleta.verde : Paleta.linha,
            ),
          ),
        Column(children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: etapa.index >= _passos[i].$1.index ? Paleta.verde : Paleta.linha,
            child: etapa.index >= _passos[i].$1.index
                ? const Icon(Icons.check, size: 14, color: Paleta.fundo)
                : null,
          ),
          const SizedBox(height: 6),
          Text(_passos[i].$2, style: const TextStyle(fontSize: 11)),
        ]),
      ],
    ]);
  }
}
