import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/providers/stock_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';

class QRViewerScreen extends ConsumerWidget {
  final String productId;
  const QRViewerScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productDetailProvider(productId));

    return Scaffold(
      appBar: AppBar(title: const Text('QR Code do produto')),
      body: product.when(
        data: (p) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // QR Code gerado localmente pelo flutter
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        QrImageView(
                          data: p.qrCode ?? 'STOCKIQ:${p.companyId}:${p.id}:${p.sku}',
                          version: QrVersions.auto,
                          size: 220,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Color(0xFF1A1A1A),
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(p.name, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
                        const SizedBox(height: 4),
                        Text('SKU: ${p.sku}', style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            p.qrCode ?? 'STOCKIQ:${p.id}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Botões de ação
                ElevatedButton.icon(
                  icon: const Icon(Icons.print, size: 18),
                  label: const Text('Imprimir QR Code'),
                  onPressed: () {
                    // Integração com impressora via plugin flutter_bluetooth_serial
                    // ou share_plus para compartilhar a imagem
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Conecte à impressora via Bluetooth.')),
                    );
                  },
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Compartilhar'),
                  onPressed: () {
                    // share_plus: Share.share(p.qrCode ?? '');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Compartilhamento disponível em breve.')),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(productDetailProvider(productId)),
        ),
      ),
    );
  }
}
