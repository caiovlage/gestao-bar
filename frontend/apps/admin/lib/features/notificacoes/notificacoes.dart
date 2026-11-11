import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/widgets/push/push.dart';

/// Aparelho que recebe notificações de novos pedidos.
class AparelhoNotificado {
  const AparelhoNotificado(this.id, this.endpoint, this.dispositivo, this.usuario, this.criadoEm, this.ultimoEnvio);

  final String id;
  final String endpoint;
  final String? dispositivo;
  final String? usuario;
  final DateTime? criadoEm;
  final DateTime? ultimoEnvio;

  factory AparelhoNotificado.fromJson(Map<String, dynamic> j) => AparelhoNotificado(
        j['id'] as String,
        j['endpoint'] as String,
        j['dispositivo'] as String?,
        j['usuario'] as String?,
        dataDoJson(j['criadoEm']),
        dataDoJson(j['ultimoEnvio']),
      );
}

/// Situação das notificações neste aparelho.
enum EstadoNotificacao {
  inseguro, iosInstalar, naoSuportado, bloqueado, inativo, ativo;

  static EstadoNotificacao de(String v) => switch (v) {
        'inseguro' => inseguro,
        'ios-instalar' => iosInstalar,
        'bloqueado' => bloqueado,
        'inativo' => inativo,
        'ativo' => ativo,
        _ => naoSuportado,
      };

  /// Explicação para quem não consegue ativar.
  String? get ajuda => switch (this) {
        inseguro => 'Abra o painel pelo endereço com https (ex.: https://barentrenos.com.br/admin/) para ativar.',
        iosInstalar => 'No iPhone: toque em Compartilhar → "Adicionar à Tela de Início", abra o painel pelo '
            'ícone criado e ative aqui (iOS 16.4 ou mais novo).',
        naoSuportado => 'Este navegador não recebe notificações. Use Chrome, Edge, Firefox ou Safari atualizados.',
        bloqueado => 'As notificações estão bloqueadas para este site. Libere no cadeado ao lado do endereço '
            '(Permissões → Notificações) e recarregue a página.',
        _ => null,
      };
}

class NotificacoesRepository {
  NotificacoesRepository(this._api);
  final ApiClient _api;

  static const _base = '/api/admin/notificacoes';

  Future<String> chavePublica() async =>
      (await _api.get('$_base/chave-publica') as Map<String, dynamic>)['chavePublica'] as String;

  Future<List<AparelhoNotificado>> aparelhos() async => (await _api.get('$_base/inscricoes') as List)
      .map((e) => AparelhoNotificado.fromJson(e as Map<String, dynamic>))
      .toList();

  Future<void> inscrever(Map<String, dynamic> inscricao, String dispositivo) =>
      _api.post('$_base/inscricoes', corpo: {...inscricao, 'dispositivo': dispositivo});

  Future<void> remover(String endpoint) => _api.post('$_base/inscricoes/remover', corpo: {'endpoint': endpoint});

  Future<void> removerPorId(String id) => _api.delete('$_base/inscricoes/$id');

  Future<int> teste() async => ((await _api.post('$_base/teste')) as Map<String, dynamic>)['entregues'] as int;
}

final notificacoesRepositoryProvider = Provider((ref) => NotificacoesRepository(ref.watch(apiClientProvider)));

final estadoNotificacaoProvider =
    FutureProvider.autoDispose<EstadoNotificacao>((ref) async => EstadoNotificacao.de(await estadoPush()));

final aparelhosNotificadosProvider = FutureProvider.autoDispose<List<AparelhoNotificado>>(
    (ref) => ref.watch(notificacoesRepositoryProvider).aparelhos());

/// Ativa as notificações neste aparelho. Devolve null se deu certo, ou a mensagem de erro.
Future<String?> ativarNotificacoes(WidgetRef ref) async {
  try {
    final repo = ref.read(notificacoesRepositoryProvider);
    final resposta = jsonDecode(await ativarPush(await repo.chavePublica())) as Map<String, dynamic>;
    if (resposta['erro'] != null) {
      return switch (resposta['erro']) {
        'bloqueado' => EstadoNotificacao.bloqueado.ajuda,
        'recusado' => 'Permissão não concedida. Toque em "Permitir" quando o navegador perguntar.',
        _ => 'Não foi possível ativar: ${resposta['erro']}',
      };
    }
    await repo.inscrever(resposta, nomeAparelho());
    return null;
  } catch (e) {
    return mensagemDeErro(e);
  } finally {
    ref.invalidate(estadoNotificacaoProvider);
    ref.invalidate(aparelhosNotificadosProvider);
  }
}

Future<void> desativarNotificacoes(WidgetRef ref) async {
  final endpoint = await desativarPush();
  if (endpoint.isNotEmpty) {
    try {
      await ref.read(notificacoesRepositoryProvider).remover(endpoint);
    } catch (_) {
      // o servidor remove sozinho quando o serviço de push recusar o envio
    }
  }
  ref.invalidate(estadoNotificacaoProvider);
  ref.invalidate(aparelhosNotificadosProvider);
}

/// Botão do sino (tela de Pedidos): mostra o estado e ativa com um toque.
class BotaoNotificacoes extends ConsumerWidget {
  const BotaoNotificacoes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(estadoNotificacaoProvider).value;
    final ativo = estado == EstadoNotificacao.ativo;
    return IconButton(
      tooltip: ativo ? 'Notificações de pedidos ativas neste aparelho' : 'Ativar notificações de pedidos',
      onPressed: () async {
        if (ativo) {
          mostrarSucesso(context, 'Este aparelho já recebe notificações de novos pedidos.');
          return;
        }
        final ajuda = estado?.ajuda;
        if (ajuda != null) {
          mostrarErro(context, ajuda);
          return;
        }
        final erro = await ativarNotificacoes(ref);
        if (!context.mounted) return;
        erro == null
            ? mostrarSucesso(context, 'Pronto! Este aparelho vai avisar quando chegar pedido.')
            : mostrarErro(context, erro);
      },
      icon: Icon(ativo ? Icons.notifications_active : Icons.notifications_off_outlined,
          color: ativo ? AppCores.sucesso : AppCores.ambarEscuro),
    );
  }
}

/// Cartão em Configurações: ativar neste aparelho, testar e ver os aparelhos cadastrados.
class NotificacoesCard extends ConsumerStatefulWidget {
  const NotificacoesCard({super.key});

  @override
  ConsumerState<NotificacoesCard> createState() => _NotificacoesCardState();
}

class _NotificacoesCardState extends ConsumerState<NotificacoesCard> {
  bool _ocupado = false;

  Future<void> _executar(Future<void> Function() acao) async {
    setState(() => _ocupado = true);
    try {
      await acao();
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(estadoNotificacaoProvider);
    final aparelhos = ref.watch(aparelhosNotificadosProvider);
    final tema = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.notifications_active_outlined, color: AppCores.ambarEscuro),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Notificações de novos pedidos',
                  style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            'Cada celular ou notebook da equipe pode receber um aviso quando chegar pedido pelo cardápio, '
            'mesmo com o painel fechado. Ative em cada aparelho que for usar.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          const SizedBox(height: 14),
          estado.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(mensagemDeErro(e)),
            data: (e) => _estado(e),
          ),
          const Divider(height: 28),
          Text('Aparelhos que recebem', style: tema.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          aparelhos.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(mensagemDeErro(e)),
            data: (lista) => lista.isEmpty
                ? Text('Nenhum aparelho ainda.', style: TextStyle(color: Colors.grey.shade600))
                : Column(children: [
                    for (final a in lista)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Icon(
                          (a.dispositivo ?? '').startsWith('Android') || (a.dispositivo ?? '').startsWith('iPhone')
                              ? Icons.smartphone
                              : Icons.laptop,
                          color: AppCores.verde,
                        ),
                        title: Text(a.dispositivo ?? 'Aparelho'),
                        subtitle: Text([
                          if (a.usuario != null) a.usuario!,
                          'desde ${formatarData(a.criadoEm)}',
                          if (a.ultimoEnvio != null) 'último aviso ${formatarDataHora(a.ultimoEnvio)}',
                        ].join(' · ')),
                        trailing: IconButton(
                          tooltip: 'Parar de enviar para este aparelho',
                          icon: const Icon(Icons.delete_outline, color: AppCores.perigo),
                          onPressed: () async {
                            await ref.read(notificacoesRepositoryProvider).removerPorId(a.id);
                            ref.invalidate(aparelhosNotificadosProvider);
                            ref.invalidate(estadoNotificacaoProvider);
                          },
                        ),
                      ),
                  ]),
          ),
        ]),
      ),
    );
  }

  Widget _estado(EstadoNotificacao e) {
    if (e.ajuda != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppCores.alerta.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline, color: AppCores.alerta),
          const SizedBox(width: 10),
          Expanded(child: Text(e.ajuda!)),
        ]),
      );
    }
    final ativo = e == EstadoNotificacao.ativo;
    return Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
      Etiqueta(ativo ? 'Ativas neste aparelho' : 'Desativadas neste aparelho',
          cor: ativo ? AppCores.sucesso : Colors.grey.shade700,
          icone: ativo ? Icons.check_circle : Icons.notifications_off_outlined),
      if (!ativo)
        FilledButton.icon(
          onPressed: _ocupado
              ? null
              : () => _executar(() async {
                    final erro = await ativarNotificacoes(ref);
                    if (!mounted) return;
                    erro == null
                        ? mostrarSucesso(context, 'Pronto! Este aparelho vai avisar quando chegar pedido.')
                        : mostrarErro(context, erro);
                  }),
          icon: const Icon(Icons.notifications_active),
          label: const Text('Ativar neste aparelho'),
        )
      else ...[
        OutlinedButton.icon(
          onPressed: _ocupado
              ? null
              : () => _executar(() async {
                    try {
                      final n = await ref.read(notificacoesRepositoryProvider).teste();
                      if (mounted) mostrarSucesso(context, 'Aviso de teste enviado para $n aparelho(s).');
                    } catch (e) {
                      if (mounted) mostrarErro(context, e);
                    }
                    ref.invalidate(aparelhosNotificadosProvider);
                  }),
          icon: const Icon(Icons.send_outlined),
          label: const Text('Enviar teste'),
        ),
        TextButton(
          onPressed: _ocupado ? null : () => _executar(() => desativarNotificacoes(ref)),
          child: const Text('Desativar neste aparelho'),
        ),
      ],
    ]);
  }
}

/// Faixa no topo da tela de Pedidos enquanto este aparelho não recebe avisos (some quando ativar).
class AvisoAtivarNotificacoes extends ConsumerWidget {
  const AvisoAtivarNotificacoes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(estadoNotificacaoProvider).value;
    if (estado != EstadoNotificacao.inativo && estado != EstadoNotificacao.iosInstalar) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppCores.ambar.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppCores.ambar.withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        const Icon(Icons.notifications_active_outlined, color: AppCores.ambarEscuro),
        const SizedBox(width: 10),
        Expanded(
          child: Text(estado == EstadoNotificacao.iosInstalar
              ? 'Para receber aviso de novos pedidos no iPhone, adicione o painel à Tela de Início '
                  '(Compartilhar → Adicionar à Tela de Início) e abra por lá.'
              : 'Receba um aviso neste aparelho sempre que chegar pedido, mesmo com o painel fechado.'),
        ),
        if (estado == EstadoNotificacao.inativo)
          FilledButton(
            onPressed: () async {
              final erro = await ativarNotificacoes(ref);
              if (!context.mounted) return;
              erro == null
                  ? mostrarSucesso(context, 'Pronto! Este aparelho vai avisar quando chegar pedido.')
                  : mostrarErro(context, erro);
            },
            child: const Text('Ativar'),
          ),
      ]),
    );
  }
}
