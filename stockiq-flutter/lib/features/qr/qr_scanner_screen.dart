import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/services/stock_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/product_model.dart';

class QRScannerScreen extends ConsumerStatefulWidget {
  const QRScannerScreen({super.key});

  @override
  ConsumerState<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends ConsumerState<QRScannerScreen> {
  final MobileScannerController _ctrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
  );

  bool _hasPermission = false;
  bool _scanning      = true;
  bool _loading       = false;
  String? _lastCode;

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    setState(() => _hasPermission = status.isGranted);
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!_scanning || _loading) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;
    final code = barcode.rawValue!;
    if (code == _lastCode) return;

    _lastCode = code;
    setState(() { _scanning = false; _loading = true; });

    try {
      // Verifica se é um QR do StockIQ
      if (!code.startsWith('STOCKIQ:')) {
        _showResult(null, 'QR Code não reconhecido pelo StockIQ.');
        return;
      }

      final product = await StockApiService().scanQR(code);
      if (mounted) _showProductSheet(product);
    } catch (e) {
      if (mounted) _showResult(null, 'Produto não encontrado: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showProductSheet(ProductModel product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ProductBottomSheet(
        product: product,
        onDismiss: () {
          Navigator.pop(context);
          setState(() { _scanning = true; _lastCode = null; });
        },
      ),
    );
  }

  void _showResult(ProductModel? product, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: product != null ? AppTheme.success : AppTheme.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() { _scanning = true; _lastCode = null; });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPermission) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scanner QR Code')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.camera_alt_outlined, size: 64, color: AppTheme.primary),
                const SizedBox(height: 16),
                const Text('Permissão de câmera necessária', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                const Text('Para escanear QR Codes, o app precisa de acesso à câmera.', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _requestPermission,
                  child: const Text('Conceder permissão'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: openAppSettings,
                  child: const Text('Abrir configurações'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scanner QR Code', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.white),
            onPressed: () => _ctrl.toggleTorch(),
            tooltip: 'Lanterna',
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
            onPressed: () => _ctrl.switchCamera(),
            tooltip: 'Trocar câmera',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Câmera
          MobileScanner(
            controller: _ctrl,
            onDetect: _onDetect,
          ),

          // Overlay com recorte
          _ScanOverlay(loading: _loading),

          // Instrução
          Positioned(
            bottom: 60,
            left: 0, right: 0,
            child: Column(
              children: [
                if (_loading)
                  const CircularProgressIndicator(color: AppTheme.primary)
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Aponte para o QR Code do produto',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Overlay do scanner ────────────────────────────────────────────────────────

class _ScanOverlay extends StatelessWidget {
  final bool loading;
  const _ScanOverlay({required this.loading});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OverlayPainter(loading: loading),
      child: const SizedBox.expand(),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final bool loading;
  _OverlayPainter({required this.loading});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black54;
    final side  = size.width * 0.68;
    final left  = (size.width - side) / 2;
    final top   = (size.height - side) / 2;
    final rect  = Rect.fromLTWH(left, top, side, side);

    // Escurecer tudo fora do recorte
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16))),
      ),
      paint,
    );

    // Cantos coloridos
    final cornerPaint = Paint()
      ..color = loading ? AppTheme.warning : AppTheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const cLen = 24.0;
    // TL
    canvas.drawLine(Offset(left, top + cLen), Offset(left, top), cornerPaint);
    canvas.drawLine(Offset(left, top), Offset(left + cLen, top), cornerPaint);
    // TR
    canvas.drawLine(Offset(left + side - cLen, top), Offset(left + side, top), cornerPaint);
    canvas.drawLine(Offset(left + side, top), Offset(left + side, top + cLen), cornerPaint);
    // BL
    canvas.drawLine(Offset(left, top + side - cLen), Offset(left, top + side), cornerPaint);
    canvas.drawLine(Offset(left, top + side), Offset(left + cLen, top + side), cornerPaint);
    // BR
    canvas.drawLine(Offset(left + side - cLen, top + side), Offset(left + side, top + side), cornerPaint);
    canvas.drawLine(Offset(left + side, top + side), Offset(left + side, top + side - cLen), cornerPaint);
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => old.loading != loading;
}

// ── Bottom Sheet do produto encontrado ───────────────────────────────────────

class _ProductBottomSheet extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onDismiss;
  const _ProductBottomSheet({required this.product, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.check_circle, color: AppTheme.success, size: 24),
              const SizedBox(width: 8),
              Text('Produto encontrado', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.success)),
            ],
          ),
          const SizedBox(height: 16),
          Text(product.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('SKU: ${product.sku}', style: Theme.of(context).textTheme.bodySmall),
          if (product.category != null)
            Text(product.category!, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _PriceBox(label: 'Venda', value: 'R\$ ${product.salePrice.toStringAsFixed(2)}', color: AppTheme.success),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PriceBox(label: 'Margem', value: '${product.marginPercent.toStringAsFixed(1)}%', color: AppTheme.info),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Ver detalhes'),
                  onPressed: () {
                    onDismiss();
                    context.push('/products/${product.id}');
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: const Text('Movimentar'),
                  onPressed: () {
                    onDismiss();
                    context.push('/stock/movement', extra: {'productId': product.id});
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton(onPressed: onDismiss, child: const Text('Escanear outro')),
          ),
        ],
      ),
    );
  }
}

class _PriceBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _PriceBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: color)),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}
