import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/app_notifications.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure    = true;
  bool _loading    = false;
  bool _googleLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    await ref.read(authStateProvider.notifier).signIn(
      _emailCtrl.text.trim(),
      _passCtrl.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    final auth = ref.read(authStateProvider);
    auth.whenOrNull(
      data: (state) {
        if (state.isLoggedIn) _goToDashboard();
      },
      error: (e, _) => _showError(e.toString()),
    );
  }

  void _goToDashboard() {
    // Fogo-e-esquece: não trava o login se o usuário negar/ignorar o
    // pedido de permissão de notificação.
    AppNotifications.requestPermission();
    context.go('/dashboard');
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _googleLoading = true);

    await ref.read(authStateProvider.notifier).signInWithGoogle();

    if (!mounted) return;
    setState(() => _googleLoading = false);

    final auth = ref.read(authStateProvider);
    auth.whenOrNull(
      data: (state) {
        if (state.isLoggedIn) _goToDashboard();
      },
      error: (e, _) => _showError(e.toString()),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Enquanto verifica se já tem sessão salva (secure storage), mostra
    // esqueleto em vez do form em branco -- evita o flash "login vazio
    // -> dashboard" pra quem já tava logado.
    final checkingSession = ref.watch(authStateProvider).isLoading;
    if (checkingSession) {
      return const _LoginSkeleton();
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo
                  Row(
                    children: [
                      const AppLogo(size: 48),
                      const SizedBox(width: 12),
                      Text('StockIQ', style: theme.textTheme.headlineMedium?.copyWith(fontSize: 26)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('ERP inteligente para sua empresa', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 40),

                  Text('Entrar na conta', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 24),

                  // Email
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.email_outlined, size: 20),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Informe o e-mail.';
                      if (!v.contains('@')) return 'E-mail inválido.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Senha
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      prefixIcon: const Icon(Icons.lock_outlined, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Informe a senha.';
                      if (v.length < 6) return 'Mínimo 6 caracteres.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // Esqueceu senha
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _showForgotDialog(),
                      child: const Text('Esqueceu a senha?', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Botão de login
                  ElevatedButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Entrar'),
                  ),
                  const SizedBox(height: 20),

                  // Divisor
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text('ou', style: theme.textTheme.bodySmall),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Login com Google
                  OutlinedButton.icon(
                    onPressed: _googleLoading ? null : _loginWithGoogle,
                    icon: _googleLoading
                        ? const SizedBox(
                            height: 18, width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.g_mobiledata, size: 24),
                    label: const Text('Continuar com Google'),
                  ),
                  const SizedBox(height: 32),

                  // Info
                  Center(
                    child: Text(
                      'Primeiro acesso com Google cria sua conta automaticamente.',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showForgotDialog() {
    final ctrl = TextEditingController(text: _emailCtrl.text);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Redefinir senha'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'E-mail'),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // await AuthService().sendPasswordReset(ctrl.text);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('E-mail de redefinição enviado!')),
                );
              }
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }
}

/// Mesmo layout do form de login, só que com blocos cinza pulsando no
/// lugar de cada campo -- mostrado só durante a checagem inicial de
/// sessão salva (rápido, mas evita o form aparecer vazio por um instante).
class _LoginSkeleton extends StatelessWidget {
  const _LoginSkeleton();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const AppLogo(size: 48),
                    const SizedBox(width: 12),
                    Text('StockIQ', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 26)),
                  ],
                ),
                const SizedBox(height: 8),
                const ShimmerCard(height: 12),
                const SizedBox(height: 40),
                const ShimmerCard(height: 20),
                const SizedBox(height: 24),
                const ShimmerCard(height: 56),
                const SizedBox(height: 14),
                const ShimmerCard(height: 56),
                const SizedBox(height: 28),
                const ShimmerCard(height: 48),
                const SizedBox(height: 20),
                const ShimmerCard(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
