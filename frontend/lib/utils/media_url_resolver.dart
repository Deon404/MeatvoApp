import '../config/backend_resolver.dart';

/// Turns API-relative or stale-host media paths into URLs reachable from the app.
abstract final class MediaUrlResolver {
  static const String _uploadPathSegment = '/uploads/images/';

  static String? resolve(String? url) {
    final trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;

    final root = BackendResolver.root.replaceAll(RegExp(r'/+$'), '');
    final rootUri = Uri.tryParse(root);

    if (trimmed.startsWith('/')) {
      return '$root$trimmed';
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return trimmed;

    // API often returns upload URLs signed with an old LAN IP (e.g. 192.168.0.101)
    // while the phone talks to 192.168.1.9 — rewrite host to the live backend.
    if (uri.path.contains(_uploadPathSegment) && rootUri != null) {
      return Uri(
        scheme: rootUri.scheme,
        host: rootUri.host,
        port: rootUri.hasPort ? rootUri.port : null,
        path: uri.path,
        query: uri.query,
      ).toString();
    }

    return trimmed;
  }

  static List<String>? resolveList(List<String>? urls) {
    if (urls == null || urls.isEmpty) return urls;
    return urls
        .map((u) => resolve(u))
        .whereType<String>()
        .where((u) => u.isNotEmpty)
        .toList();
  }
}
