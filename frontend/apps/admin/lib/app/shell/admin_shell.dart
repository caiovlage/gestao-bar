import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_controller.dart';
import '../menu.dart';

/// Estrutura do painel: menu lateral fixo (desktop), recolhido (tablet) ou gaveta (celular).
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.child});

  final Widget child;

  static const larguraCompleta = 1100.0;
  static const larguraTablet = 700.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caminho = GoRouterState.of(context).matchedLocation;
    final largura = MediaQuery.sizeOf(context).width;
    final conteudo = SelectionArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(largura < larguraTablet ? 16 : 28),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1400), child: child),
        ),
      ),
    );

    if (largura < larguraTablet) {
      final atual = itensMenu.where((i) => caminho.startsWith(i.caminho)).firstOrNull;
      return Scaffold(
        appBar: AppBar(title: Text(atual?.rotulo ?? 'Gestão do Bar')),
        drawer: Drawer(
          backgroundColor: AppCores.grafite,
          child: _MenuLateral(caminho: caminho, expandido: true, aoNavegar: () => Navigator.pop(context)),
        ),
        body: conteudo,
      );
    }

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: largura >= larguraCompleta ? 248 : 76,
            child: Material(
              color: AppCores.grafite,
              child: _MenuLateral(caminho: caminho, expandido: largura >= larguraCompleta),
            ),
          ),
          Expanded(child: conteudo),
        ],
      ),
    );
  }
}

class _MenuLateral extends ConsumerWidget {
  const _MenuLateral({required this.caminho, required this.expandido, this.aoNavegar});

  final String caminho;
  final bool expandido;
  final VoidCallback? aoNavegar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final login = ref.watch(authProvider).value?.login ?? '';
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: expandido ? 20 : 0, vertical: 22),
            child: Row(
              mainAxisAlignment: expandido ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: AppCores.ambar,
                  child: Icon(Icons.local_bar, size: 20, color: AppCores.sobreAmbar),
                ),
                if (expandido) ...[
                  const SizedBox(width: 12),
                  const Text(
                    'Gestão do Bar',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                for (final item in itensMenu)
                  _ItemMenuTile(
                    item: item,
                    selecionado: caminho.startsWith(item.caminho),
                    expandido: expandido,
                    aoTocar: () {
                      aoNavegar?.call();
                      context.go(item.caminho);
                    },
                  ),
              ],
            ),
          ),
          const Divider(color: AppCores.grafiteClaro),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Tooltip(
              message: expandido ? '' : 'Sair ($login)',
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: EdgeInsets.symmetric(horizontal: expandido ? 12 : 0),
                leading: const Icon(Icons.logout, color: AppCores.textoSidebar),
                title: expandido
                    ? Text('Sair', style: const TextStyle(color: AppCores.textoSidebar))
                    : null,
                subtitle: expandido
                    ? Text(login, style: TextStyle(color: Colors.grey.shade500, fontSize: 12))
                    : null,
                onTap: () async {
                  final ok = await confirmar(context,
                      titulo: 'Sair do sistema', mensagem: 'Deseja encerrar a sessão?', acao: 'Sair');
                  if (ok) await ref.read(authProvider.notifier).sair();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemMenuTile extends StatelessWidget {
  const _ItemMenuTile({
    required this.item,
    required this.selecionado,
    required this.expandido,
    required this.aoTocar,
  });

  final ItemMenu item;
  final bool selecionado;
  final bool expandido;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final cor = selecionado ? AppCores.sobreAmbar : AppCores.textoSidebar;
    final tile = Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selecionado ? AppCores.ambar : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: aoTocar,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: expandido ? 14 : 0, vertical: 11),
            child: Row(
              mainAxisAlignment: expandido ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Icon(item.icone, color: cor, size: 22),
                if (expandido) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      item.rotulo,
                      style: TextStyle(color: cor, fontWeight: selecionado ? FontWeight.w700 : FontWeight.w500),
                    ),
                  ),
                  if (!item.disponivel)
                    Text('em breve', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return expandido ? tile : Tooltip(message: item.rotulo, child: tile);
  }
}
