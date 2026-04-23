import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/stock_providers.dart';
import '../../core/theme/app_theme.dart';

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final _ctrl       = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending     = false;

  static const _suggestions = [
    'Qual filial tem mais estoque parado?',
    'Onde estou perdendo dinheiro?',
    'O que devo comprar urgente?',
    'Analise a performance geral da empresa',
    'Quais produtos têm melhor margem?',
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send([String? text]) async {
    final question = (text ?? _ctrl.text).trim();
    if (question.isEmpty || _sending) return;
    _ctrl.clear();
    setState(() => _sending = true);

    await ref.read(aiProvider.notifier).ask(question);

    if (mounted) {
      setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(aiProvider).valueOrNull ?? [];
    final theme    = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, color: AppTheme.primary, size: 16),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Assistente IA', style: TextStyle(fontSize: 15)),
                Text('Powered by Claude', style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => ref.read(aiProvider.notifier).clear(),
            tooltip: 'Limpar conversa',
          ),
        ],
      ),
      body: Column(
        children: [
          // Chips de sugestão (somente quando sem mensagens)
          if (messages.isEmpty)
            _SuggestionsPanel(suggestions: _suggestions, onTap: _send),

          // Mensagens
          Expanded(
            child: messages.isEmpty
                ? _EmptyAI()
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final msg = messages[i];
                      return _MessageBubble(
                        text: msg.text,
                        isUser: msg.role == 'user',
                        isLoading: msg.text == '...',
                      );
                    },
                  ),
          ),

          // Input
          _InputBar(ctrl: _ctrl, sending: _sending, onSend: _send),
        ],
      ),
    );
  }
}

class _EmptyAI extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 56, color: AppTheme.primary.withOpacity(.4)),
            const SizedBox(height: 16),
            Text('Assistente StockIQ IA',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tenho acesso aos dados reais da sua empresa.\nPergunte sobre estoque, finanças e filiais.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionsPanel extends StatelessWidget {
  final List<String> suggestions;
  final void Function(String) onTap;
  const _SuggestionsPanel({required this.suggestions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      margin: const EdgeInsets.only(top: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => ActionChip(
          label: Text(suggestions[i], style: const TextStyle(fontSize: 12)),
          onPressed: () => onTap(suggestions[i]),
          backgroundColor: AppTheme.primary.withOpacity(.08),
          side: BorderSide(color: AppTheme.primary.withOpacity(.2), width: 0.5),
          labelStyle: const TextStyle(color: AppTheme.primary),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final bool isLoading;
  const _MessageBubble({required this.text, required this.isUser, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, size: 14, color: AppTheme.primary),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? AppTheme.primary
                    : theme.colorScheme.surface,
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(12),
                  topRight:    const Radius.circular(12),
                  bottomLeft:  Radius.circular(isUser ? 12 : 2),
                  bottomRight: Radius.circular(isUser ? 2 : 12),
                ),
                border: isUser ? null : Border.all(
                  color: theme.colorScheme.outline,
                  width: 0.5,
                ),
              ),
              child: isLoading
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(3, (i) => _Dot(delay: i * 200)),
                    )
                  : Text(
                      text,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: isUser ? Colors.white : theme.textTheme.bodyMedium?.color,
                      ),
                    ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.person, size: 14, color: AppTheme.primary),
            ),
          ],
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Interval(widget.delay / 600, 1.0, curve: Curves.easeInOut),
      ),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _anim,
    child: Container(
      width: 7, height: 7,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
    ),
  );
}

class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool sending;
  final void Function([String?]) onSend;
  const _InputBar({required this.ctrl, required this.sending, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outline, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: 'Pergunte sobre estoque, filiais, finanças...',
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: sending
                  ? const SizedBox(
                      width: 44, height: 44,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send_rounded),
                      color: AppTheme.primary,
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.primary.withOpacity(.12),
                        minimumSize: const Size(44, 44),
                      ),
                      onPressed: onSend,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
