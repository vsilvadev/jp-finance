import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final buildDirectory = Directory(
    arguments.isEmpty ? 'build/web' : arguments.single,
  ).absolute;
  final rootPath = buildDirectory.path;
  final flutterWorker = File(
    '${buildDirectory.path}${Platform.pathSeparator}flutter_service_worker.js',
  );
  if (await flutterWorker.exists()) await flutterWorker.delete();
  final assets = <String>[];

  await for (final entity in buildDirectory.list(recursive: true)) {
    if (entity is! File) continue;
    final relativePath = entity.absolute.path
        .substring(rootPath.length + 1)
        .replaceAll(Platform.pathSeparator, '/');
    final segments = relativePath.split('/');
    if (segments.any((segment) => segment.startsWith('.')) ||
        relativePath.endsWith('.symbols') ||
        relativePath == 'service_worker.js' ||
        relativePath == 'precache-manifest.json') {
      continue;
    }
    assets.add(relativePath);
  }
  assets.sort();

  final manifest = jsonEncode(assets);
  await File(
    '${buildDirectory.path}${Platform.pathSeparator}precache-manifest.json',
  ).writeAsString(manifest);

  // FNV-1a versions the cache when any precached file changes.
  var hash = 0x811c9dc5;
  void addToHash(List<int> bytes) {
    for (final byte in bytes) {
      hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
    }
  }

  for (final asset in assets) {
    addToHash(utf8.encode(asset));
    addToHash(
      await File(
        '${buildDirectory.path}${Platform.pathSeparator}'
        '${asset.replaceAll('/', Platform.pathSeparator)}',
      ).readAsBytes(),
    );
  }
  final buildId = hash.toRadixString(16).padLeft(8, '0');
  final template = await File('web/service_worker.js').readAsString();
  await File(
    '${buildDirectory.path}${Platform.pathSeparator}service_worker.js',
  ).writeAsString(template.replaceAll('__BUILD_ID__', buildId));

  final indexFile = File(
    '${buildDirectory.path}${Platform.pathSeparator}index.html',
  );
  final indexHtml = await indexFile.readAsString();
  await indexFile.writeAsString(
    indexHtml.replaceFirst(
      'name="jp-finance-precache-ready" content="false"',
      'name="jp-finance-precache-ready" content="true"',
    ),
  );
}
