import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _senha = TextEditingController();
  bool _enviando = false;
  bool _senhaVisivel = false;
  String? _erro;

  @override
  void dispose() {
    _login.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      await ref.read(authProvider.notifier).entrar(_login.text.trim(), _senha.text);
      // O roteador redireciona automaticamente após o login.
    } catch (e) {
      if (mounted) setState(() => _erro = mensagemDeErro(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      backgroundColor: AppCores.verde,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _form,
                  // Sem AutofillGroup/autofillHints: no Flutter Web, o preenchimento automático do navegador
                  // deixa o campo de senha travado (não aceita editar depois de colar/sugerir).
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: Marca(largura: 280)),
                        const SizedBox(height: 20),
                        Text(
                          'Entre para acessar o painel',
                          textAlign: TextAlign.center,
                          style: tema.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 28),
                        TextFormField(
                          controller: _login,
                          autofocus: true,
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Login',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o login' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _senha,
                          obscureText: !_senhaVisivel,
                          autocorrect: false,
                          enableSuggestions: false,
                          keyboardType: TextInputType.visiblePassword,
                          onFieldSubmitted: (_) => _entrar(),
                          decoration: InputDecoration(
                            labelText: 'Senha',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: _senhaVisivel ? 'Ocultar senha' : 'Mostrar senha',
                              icon: Icon(_senhaVisivel ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
                            ),
                          ),
                          validator: (v) => (v == null || v.isEmpty) ? 'Informe a senha' : null,
                        ),
                        if (_erro != null) ...[
                          const SizedBox(height: 14),
                          Text(_erro!, style: const TextStyle(color: AppCores.perigo), textAlign: TextAlign.center),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _enviando ? null : _entrar,
                          child: _enviando
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                              : const Text('Entrar'),
                        ),
                      ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
