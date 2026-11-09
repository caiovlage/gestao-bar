import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

final _backupProvider = FutureProvider.autoDispose<Map<String, String>>((ref) async {
  final dados = await ref.watch(apiClientProvider).get('/api/admin/configuracoes') as List;
  return {
    for (final c in dados.cast<Map<String, dynamic>>())
      if ((c['chave'] as String).startsWith('backup_git_')) c['chave'] as String: c['valor'] as String,
  };
});

/// Backup diário do banco em um repositório Git privado. O envio é feito pelo servidor
/// (infra/backup/backup-git.sh, a cada 5 minutos verifica estas configurações).
class BackupCard extends ConsumerWidget {
  const BackupCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dados = ref.watch(_backupProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: dados.when(
          loading: () => const Carregando(),
          error: (e, _) => ErroView(mensagem: mensagemDeErro(e), aoTentarNovamente: () => ref.invalidate(_backupProvider)),
          data: (v) => v.isEmpty
              ? const Text('Atualize o servidor (./deploy.sh) para habilitar o backup no Git.')
              : _Formulario(valores: v),
        ),
      ),
    );
  }
}

class _Formulario extends ConsumerStatefulWidget {
  const _Formulario({required this.valores});

  final Map<String, String> valores;

  @override
  ConsumerState<_Formulario> createState() => _FormularioState();
}

class _FormularioState extends ConsumerState<_Formulario> {
  late bool _ativo = widget.valores['backup_git_ativo'] == 'true';
  late final _repositorio = TextEditingController(text: widget.valores['backup_git_repositorio'] ?? '');
  late int _horario = int.tryParse(widget.valores['backup_git_horario'] ?? '') ?? 4;
  late int _manter = int.tryParse(widget.valores['backup_git_manter_dias'] ?? '') ?? 7;
  bool _salvando = false;
  Timer? _acompanhar;

  Map<String, String> get v => widget.valores;
  bool get _solicitado => v['backup_git_solicitado'] == 'true';

  /// Data do último backup no momento em que "Fazer backup agora" foi clicado.
  String? _ultimoAoPedir;

  @override
  void initState() {
    super.initState();
    _agendarAtualizacao();
  }

  @override
  void didUpdateWidget(covariant _Formulario antigo) {
    super.didUpdateWidget(antigo);
    _agendarAtualizacao();
  }

  /// Enquanto um backup pedido não terminar, atualiza o status sozinho a cada 15 s.
  void _agendarAtualizacao() {
    _acompanhar?.cancel();
    final aguardando = _solicitado || (_ultimoAoPedir != null && v['backup_git_ultimo_em'] == _ultimoAoPedir);
    if (!aguardando) {
      _ultimoAoPedir = null;
      return;
    }
    _acompanhar = Timer(const Duration(seconds: 15), () {
      if (mounted) ref.invalidate(_backupProvider);
    });
  }

  @override
  void dispose() {
    _acompanhar?.cancel();
    _repositorio.dispose();
    super.dispose();
  }

  Future<void> _salvar({bool agora = false}) async {
    final repo = _repositorio.text.trim();
    if ((_ativo || agora) && repo.isEmpty) {
      mostrarErro(context, 'Informe o endereço SSH do repositório privado.');
      return;
    }
    setState(() => _salvando = true);
    if (agora) _ultimoAoPedir = v['backup_git_ultimo_em'] ?? '';
    try {
      await ref.read(apiClientProvider).put('/api/admin/configuracoes', corpo: {
        'backup_git_ativo': '$_ativo',
        if (repo.isNotEmpty) 'backup_git_repositorio': repo,
        'backup_git_horario': '$_horario',
        'backup_git_manter_dias': '$_manter',
        if (agora) 'backup_git_solicitado': 'true',
      });
      ref.invalidate(_backupProvider);
      if (mounted) {
        mostrarSucesso(
            context,
            agora
                ? 'Backup solicitado. O servidor envia em até 5 minutos; o resultado aparece aqui.'
                : 'Configuração de backup salva.');
      }
    } catch (e) {
      if (mounted) mostrarErro(context, e);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final chave = v['backup_git_chave_publica'] ?? '';
    final ultimoEm = v['backup_git_ultimo_em'] ?? '';
    final resultado = v['backup_git_ultimo_resultado'] ?? '';
    final sucesso = resultado.startsWith('OK');

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: Text('Backup diário no Git', style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ),
        IconButton(
          tooltip: 'Atualizar status',
          onPressed: () => ref.invalidate(_backupProvider),
          icon: const Icon(Icons.refresh),
        ),
      ]),
      Text(
        'Uma vez por dia o servidor gera uma cópia do banco de dados e envia para um repositório Git '
        'PRIVADO, mantendo só os últimos backups. Use sempre um repositório privado: o backup contém '
        'todos os dados do bar.',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      ),
      const SizedBox(height: 12),
      // Status do último backup
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: (resultado.isEmpty ? Colors.grey : (sucesso ? AppCores.sucesso : AppCores.perigo)).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(
            resultado.isEmpty ? Icons.cloud_off_outlined : (sucesso ? Icons.cloud_done_outlined : Icons.error_outline),
            color: resultado.isEmpty ? Colors.grey : (sucesso ? AppCores.sucesso : AppCores.perigo),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              resultado.isEmpty
                  ? 'Nenhum backup enviado ainda.'
                  : 'Último backup: $ultimoEm\n$resultado',
              style: const TextStyle(height: 1.4),
            ),
          ),
        ]),
      ),
      if (_solicitado)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Row(children: [
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 8),
            Expanded(child: Text('Backup solicitado: o servidor envia em até 5 minutos.')),
          ]),
        ),
      const SizedBox(height: 8),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Enviar backup diário'),
        subtitle: const Text('Desligado, nenhum backup é enviado automaticamente'),
        value: _ativo,
        onChanged: (x) => setState(() => _ativo = x),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 12, runSpacing: 12, children: [
        LarguraCampo(
          largura: 440,
          child: TextField(
            controller: _repositorio,
            decoration: const InputDecoration(
              labelText: 'Repositório privado (endereço SSH)',
              hintText: 'git@github.com:usuario/gestao-bar-backups.git',
            ),
          ),
        ),
        LarguraCampo(
          largura: 150,
          child: DropdownButtonFormField<int>(
            initialValue: _horario,
            decoration: const InputDecoration(labelText: 'Horário'),
            items: [for (var h = 0; h < 24; h++) DropdownMenuItem(value: h, child: Text('${h.toString().padLeft(2, '0')}:00'))],
            onChanged: (h) => setState(() => _horario = h ?? _horario),
          ),
        ),
        LarguraCampo(
          largura: 170,
          child: DropdownButtonFormField<int>(
            initialValue: _manter,
            decoration: const InputDecoration(labelText: 'Manter'),
            items: [for (final d in const [3, 7, 14, 30]) DropdownMenuItem(value: d, child: Text('últimos $d'))],
            onChanged: (d) => setState(() => _manter = d ?? _manter),
          ),
        ),
      ]),
      const SizedBox(height: 16),
      Text('Chave do servidor (deploy key)', style: tema.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(
        'No GitHub: abra o repositório privado → Settings → Deploy keys → Add deploy key, cole a chave abaixo '
        'e marque "Allow write access". É a única autenticação necessária.',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      ),
      const SizedBox(height: 8),
      if (chave.isEmpty)
        Text('A chave aparece aqui alguns minutos depois de rodar ./deploy.sh no servidor.',
            style: TextStyle(color: Colors.grey.shade700, fontStyle: FontStyle.italic))
      else
        Container(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          decoration: BoxDecoration(color: AppCores.fundo, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Expanded(
              child: SelectableText(chave, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
            IconButton(
              tooltip: 'Copiar chave',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: chave));
                mostrarSucesso(context, 'Chave copiada.');
              },
              icon: const Icon(Icons.copy),
            ),
          ]),
        ),
      const SizedBox(height: 16),
      Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(
          onPressed: _salvando || _solicitado ? null : () => _salvar(agora: true),
          icon: const Icon(Icons.cloud_upload_outlined),
          label: const Text('Fazer backup agora'),
        ),
        FilledButton(onPressed: _salvando ? null : _salvar, child: const Text('Salvar')),
      ]),
    ]);
  }
}
