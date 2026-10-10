import 'dart:io';
import 'dart:typed_data';

Future<String?> saveToDownloads(String filename, Uint8List bytes) async {
  if (!Platform.isWindows) return null;

  final userProfile = Platform.environment['USERPROFILE'];
  if (userProfile == null || userProfile.isEmpty) return null;

  final safeName = filename.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  final downloads = Directory('$userProfile${Platform.pathSeparator}Downloads');
  await downloads.create(recursive: true);
  final file = File('${downloads.path}${Platform.pathSeparator}$safeName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
