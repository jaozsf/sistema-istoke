import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Mobile/desktop: sem download de navegador. Salva no diretório temporário
/// do app e abre a folha de compartilhamento nativa (salvar, mandar por
/// WhatsApp/email, etc). Não precisa de permissão de storage.
Future<void> downloadBytes(List<int> bytes, String filename) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes);
  await Share.shareXFiles([XFile(file.path)]);
}
