import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/widgets/push/push.dart';
import 'notificacoes.dart';

final instalacaoAppProvider = FutureProvider.autoDispose<String>((ref) => instalacaoApp());

const _chaveAdiado = 'notificacoes.adiado_ate';

/// Envolve o painel: na primeira tela depois do login, se este aparelho ainda não recebe avisos de
/// pedidos, abre uma janela pedindo para ativar (o clique no botão libera a pergunta do navegador).
/// "Agora não" adia por 3 dias. No iPhone sem o app instalado, mostra como instalar.
class LembreteNotificacoes extends ConsumerStatefulWidget {
  const LembreteNotificacoes({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LembreteNotificacoes> createState() => _LembreteNotificacoesState();
}

class _LembreteNotificacoesState extends ConsumerState<LembreteNotificacoes> {
  /// Uma vez por abertura do painel.
  static bool _jaPerguntado = false;

  @override
  void initState() {
    super.initState();
    if (!_jaPerguntado) {
      _jaPerguntado = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _talvezPerguntar());
    }
  }

  Future<void> _talvezPerguntar() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    final estado = EstadoNotificacao.de(await estadoPush());
    if (estado != EstadoNotificacao.inativo &&
        estado != EstadoNotificacao.iosInstalar &&
        estado != EstadoNotificacao.bloqueado) {
      return;
    }
    final prefs = SharedPreferencesAsync();
    try {
      final adiado = await prefs.getInt(_chaveAdiado);
      if (adiado != null && DateTime.now().millisecondsSinceEpoch < adiado) return;
    } catch (_) {
      // sem armazenamento local: pergunta mesmo assim
    }
    if (!mounted) return;
    final adiar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogoAtivarNotificacoes(estado: estado),
    );
    if (adiar == true) {
      try {
        await prefs.setInt(_chaveAdiado, DateTime.now().add(const Duration(days: 3)).millisecondsSinceEpoch);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Janela "Receber aviso de novos pedidos?". Devolve true se a pessoa escolheu "Agora não".
class DialogoAtivarNotificacoes extends ConsumerStatefulWidget {
  const DialogoAtivarNotificacoes({super.key, required this.estado});

  final EstadoNotificacao estado;

  @override
  ConsumerState<DialogoAtivarNotificacoes> createState() => _DialogoAtivarNotificacoesState();
}

class _DialogoAtivarNotificacoesState extends ConsumerState<DialogoAtivarNotificacoes> {
  bool _ativando = false;
  String? _erro;

  Future<void> _ativar() async {
    setState(() {
      _ativando = true;
      _erro = null;
    });
    final erro = await ativarNotificacoes(ref);
    if (!mounted) return;
    if (erro == null) {
      Navigator.pop(context, false);
      mostrarSucesso(context, 'Pronto! Este aparelho vai avisar quando chegar pedido.');
    } else {
      setState(() {
        _ativando = false;
        _erro = erro;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.estado;
    final ios = e == EstadoNotificacao.iosInstalar;
    final bloqueado = e == EstadoNotificacao.bloqueado;
    return AlertDialog(
      icon: const Marca(versao: VersaoMarca.simbolo, largura: 96),
      title: Text(ios ? 'Instale o painel no iPhone' : 'Receber aviso de novos pedidos?',
          textAlign: TextAlign.center),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (ios) ...[
            const Text('No iPhone, os avisos só chegam com o painel instalado como app:'),
            const SizedBox(height: 12),
            const _Passo(1, Icons.ios_share, 'No Safari, toque em Compartilhar (quadrado com a seta para cima).'),
            const _Passo(2, Icons.add_box_outlined, 'Escolha "Adicionar à Tela de Início" e confirme.'),
            const _Passo(3, Icons.touch_app_outlined,
                'Abra o painel pelo ícone Entre Nós, entre com seu login e toque em "Ativar notificações".'),
          ] else if (bloqueado) ...[
            Text(EstadoNotificacao.bloqueado.ajuda!),
          ] else ...[
            const Text('Ative as notificações neste aparelho para ser avisado assim que um cliente fizer um '
                'pedido pelo cardápio, mesmo com o painel fechado.'),
            const SizedBox(height: 10),
            Text('O navegador vai perguntar: toque em "Permitir".',
                style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
          ],
          if (_erro != null) ...[
            const SizedBox(height: 12),
            Text(_erro!, style: const TextStyle(color: AppCores.perigo)),
          ],
        ]),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(ios || bloqueado ? 'Entendi' : 'Agora não'),
        ),
        if (!ios && !bloqueado)
          FilledButton.icon(
            onPressed: _ativando ? null : _ativar,
            icon: _ativando
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.notifications_active),
            label: const Text('Ativar notificações'),
          ),
      ],
    );
  }
}

class _Passo extends StatelessWidget {
  const _Passo(this.numero, this.icone, this.texto);

  final int numero;
  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: AppCores.verde,
          child: Text('$numero',
              style: const TextStyle(color: AppCores.offWhite, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 10),
        Icon(icone, size: 20, color: AppCores.ambarEscuro),
        const SizedBox(width: 8),
        Expanded(child: Text(texto)),
      ]),
    );
  }
}

/// Instalar o painel como app (Configurações).
class InstalarAppCard extends ConsumerWidget {
  const InstalarAppCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inst = ref.watch(instalacaoAppProvider).value;
    if (inst == null || inst == 'nao') return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(spacing: 16, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          const Marca(versao: VersaoMarca.simbolo, largura: 64),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('App do painel',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                switch (inst) {
                  'instalado' => 'Você está usando o painel instalado como app.',
                  'ios' => 'No iPhone: Safari → Compartilhar → "Adicionar à Tela de Início". Depois abra pelo ícone.',
                  _ => 'Instale o painel neste aparelho para abrir como app, com ícone próprio.',
                },
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
            ]),
          ),
          if (inst == 'sim')
            FilledButton.icon(
              onPressed: () async {
                final r = await instalarApp();
                ref.invalidate(instalacaoAppProvider);
                if (context.mounted && r == 'accepted') mostrarSucesso(context, 'App instalado!');
              },
              icon: const Icon(Icons.install_mobile),
              label: const Text('Instalar o app'),
            ),
        ]),
      ),
    );
  }
}
