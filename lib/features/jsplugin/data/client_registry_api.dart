import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/github_proxy_fallback.dart';
import '../../settings/data/settings_api.dart';
import 'jsplugin_api.dart';

String registryIdentity(String? author, String? updateUrl) {
  final normalized =
      (author ?? '')
          .replaceAll(RegExp(r'<[^>]*>|\([^)]*\)'), ' ')
          .replaceAll(RegExp(r'[ \t\r\n\f]+'), ' ')
          .trim()
          .toLowerCase();
  if (normalized.isNotEmpty) return normalized;
  final uri = Uri.tryParse(updateUrl ?? '');
  if (uri == null ||
      !{
        'github.com',
        'raw.githubusercontent.com',
        'objects.githubusercontent.com',
      }.contains(uri.host.toLowerCase())) {
    return '';
  }
  final parts = uri.path.split('/').where((part) => part.isNotEmpty).toList();
  return parts.length < 2
      ? ''
      : 'repo:${parts[0].toLowerCase()}/${parts[1].toLowerCase()}';
}

int compareRegistryVersions(String a, String b) {
  final first = a.split('.'), second = b.split('.');
  for (
    var i = 0;
    i < (first.length > second.length ? first.length : second.length);
    i++
  ) {
    final delta =
        (i < first.length ? int.tryParse(first[i]) ?? 0 : 0) -
        (i < second.length ? int.tryParse(second[i]) ?? 0 : 0);
    if (delta != 0) return delta;
  }
  return 0;
}

class _Catalog {
  final plugins = <RegistryPluginEntry>[];
  final warnings = <String>[];
}

class _RegistryConnectionError implements Exception {
  @override
  String toString() => 'Could not connect to registry';
}

class ClientRegistryApi {
  final JSPluginApi _backend;
  final Future<List<PluginRegistryConfig>> Function() _registries;
  final Future<String> Function() _githubToken;
  final Dio _public;
  final bool _web;
  final DateTime Function() _now;
  String _signature = '';
  int _revision = 0;
  ({DateTime until, _Catalog catalog})? _cache;
  int _active = 0;
  final _waiters = <Completer<void>>[];

  ClientRegistryApi({
    required JSPluginApi backend,
    required Future<List<PluginRegistryConfig>> Function() registries,
    Future<String> Function()? githubToken,
    Dio? publicDio,
    bool web = kIsWeb,
    DateTime Function()? now,
  }) : _backend = backend,
       _registries = registries,
       _githubToken = githubToken ?? (() async => ''),
       _web = web,
       _now = now ?? DateTime.now,
       _public =
           publicDio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 15),
               headers: {'Accept': 'application/json'},
             ),
           );

  void close() => _public.close(force: true);

  void _ensureActive(CancelToken cancel) {
    if (cancel.isCancelled) throw cancel.cancelError!;
  }

  Uri _httpAddress(String address) {
    final uri = Uri.tryParse(address);
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        address.contains(r'\')) {
      throw const FormatException('Invalid registry URL');
    }
    return uri;
  }

  bool _sameOrigin(String a, String b) {
    try {
      return _httpAddress(a).origin == _httpAddress(b).origin;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _object(dynamic value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid registry JSON');
    }
    return value;
  }

  Future<Map<String, dynamic>> _read(
    String address,
    String proxy,
    String token,
    CancelToken cancel, {
    required String githubToken,
  }) async {
    _ensureActive(cancel);
    final origin = _httpAddress(address).origin;
    // Source credentials win; the shared credential only applies to the official API.
    final credential =
        token.isNotEmpty
            ? token
            : origin == 'https://api.github.com'
            ? githubToken
            : '';
    if (_active >= 8) {
      final waiter = Completer<void>();
      _waiters.add(waiter);
      await waiter.future;
    } else {
      _active++;
    }
    try {
      _ensureActive(cancel);
      Future<Map<String, dynamic>> send(String url) async {
        late final Response<String> response;
        try {
          response = await _public.get<String>(
            url,
            cancelToken: cancel,
            options: Options(
              responseType: ResponseType.plain,
              validateStatus: (_) => true,
              headers:
                  credential.isEmpty
                      ? null
                      : {'Authorization': 'Bearer $credential'},
              followRedirects: credential.isEmpty,
            ),
          );
        } on DioException {
          _ensureActive(cancel);
          throw _RegistryConnectionError();
        }
        _ensureActive(cancel);
        final status = response.statusCode ?? 0;
        if (status < 200 || status >= 300) {
          throw FormatException('HTTP $status');
        }
        final body = response.data ?? '';
        if (utf8.encode(body).length > 2 * 1024 * 1024) {
          throw const FormatException('Registry JSON exceeds 2 MiB');
        }
        return _object(jsonDecode(body));
      }

      // Private credentials never pass through a GitHub prefix proxy.
      final proxied =
          credential.isNotEmpty ? address : applyGithubProxy(address, proxy);
      try {
        return await send(proxied);
      } catch (_) {
        _ensureActive(cancel);
        if (proxied == address) rethrow;
        return send(address);
      }
    } finally {
      if (_waiters.isNotEmpty) {
        _waiters.removeAt(0).complete();
      } else {
        _active--;
      }
    }
  }

  RegistryPluginEntry _installedState(
    RegistryPluginEntry entry,
    List<JSPlugin> installed,
  ) {
    final local =
        installed
            .where((plugin) => plugin.entryPath == entry.entryPath)
            .firstOrNull;
    if (local == null) {
      return entry.copyWith(
        installed: false,
        installedVersion: '',
        hasUpdate: false,
        conflict: false,
        conflictWith: '',
      );
    }
    final identity = registryIdentity(local.author, local.updateUrl);
    if ((entry.identity ?? '').isNotEmpty &&
        identity.isNotEmpty &&
        entry.identity != identity) {
      return entry.copyWith(
        installed: false,
        installedVersion: '',
        hasUpdate: false,
        conflict: true,
        conflictWith:
            '${local.displayName}${(local.author ?? '').isNotEmpty ? ' (${local.author})' : ''} v${local.version ?? ''}',
      );
    }
    return entry.copyWith(
      installed: true,
      installedVersion: local.version ?? '',
      hasUpdate:
          compareRegistryVersions(entry.version, local.version ?? '') > 0,
      conflict: false,
      conflictWith: '',
    );
  }

  Future<RegistryRefreshResponse> refreshRegistry({
    String registryUrl = '',
    bool allSources = false,
    int page = 1,
    int pageSize = 20,
    String? search,
    String? githubProxy,
    String? token,
    String? githubToken,
    bool force = false,
    List<PluginRegistryConfig>? registries,
    CancelToken? cancelToken,
    void Function(RegistryRefreshResponse)? onProgress,
    void Function(List<PluginRegistryConfig>)? onSources,
  }) async {
    final cancel = cancelToken ?? CancelToken();
    final configured =
        force || registries == null && allSources
            ? await _registries()
            : registries ?? <PluginRegistryConfig>[];
    _ensureActive(cancel);
    if (force) onSources?.call(configured);
    final requested =
        configured.where((source) => source.url == registryUrl).firstOrNull;
    final selectionRemoved =
        force &&
        !allSources &&
        (registries?.any((source) => source.url == registryUrl) ?? false) &&
        (requested == null || !requested.enabled);
    final sources =
        allSources || selectionRemoved
            ? configured.where((source) => source.enabled).toList()
            : [
              requested ??
                  PluginRegistryConfig(
                    url: registryUrl,
                    name: '',
                    token: token ?? '',
                  ),
            ];
    final proxy = githubProxy ?? '';
    var sharedToken = '', tokenWarning = '';
    try {
      sharedToken = githubToken ?? await _githubToken();
    } catch (_) {
      tokenWarning = 'Could not read GitHub token setting.';
    }
    _ensureActive(cancel);
    // Credential values stay private to this session; external cache/query keys never contain them.
    final signature = jsonEncode([
      proxy,
      sources.map((source) => source.toJson()).toList(),
      sharedToken,
    ]);
    if (_signature != signature || force) {
      _signature = signature;
      _revision++;
      _cache = null;
    }
    final revision = _revision;
    final installed = await _backend.getPlugins();
    _ensureActive(cancel);
    page = page < 1 ? 1 : page;
    pageSize = pageSize.clamp(1, 100);
    RegistryRefreshResponse snapshot(_Catalog catalog) {
      final keyword = (search ?? '').trim().toLowerCase();
      final entries =
          catalog.plugins
              .where(
                (entry) =>
                    keyword.isEmpty ||
                    [
                      entry.name,
                      entry.entryPath,
                      entry.author ?? '',
                      entry.description ?? '',
                    ].any((value) => value.toLowerCase().contains(keyword)),
              )
              .toList();
      final start = ((page - 1) * pageSize).clamp(0, entries.length);
      final end = (page * pageSize).clamp(start, entries.length);
      return RegistryRefreshResponse(
        plugins: List.unmodifiable(
          entries
              .sublist(start, end)
              .map((entry) => _installedState(entry, installed)),
        ),
        total: entries.length,
        page: page,
        pageSize: pageSize,
        warnings: List.unmodifiable(catalog.warnings),
      );
    }

    if (!force && _cache != null && _cache!.until.isAfter(_now())) {
      return snapshot(_cache!.catalog);
    }
    final catalog = _Catalog();
    if (tokenWarning.isNotEmpty) catalog.warnings.add(tokenWarning);
    final merged = <String, int>{};
    void progress() {
      _ensureActive(cancel);
      onProgress?.call(snapshot(catalog));
    }

    void add(RegistryPluginEntry entry) {
      _ensureActive(cancel);
      final index = merged[entry.rowKey];
      if (index != null) {
        if (compareRegistryVersions(
              entry.version,
              catalog.plugins[index].version,
            ) >
            0) {
          catalog.plugins[index] = entry;
        }
      } else {
        merged[entry.rowKey] = catalog.plugins.length;
        catalog.plugins.add(entry);
      }
      progress();
    }

    void warn(String address, Object error) {
      _ensureActive(cancel);
      catalog.warnings.add('$address: $error');
      progress();
    }

    Future<void> fallback(PluginRegistryConfig source) async {
      for (var next = 1; next <= 5; next++) {
        _ensureActive(cancel);
        final response = await _backend.refreshRegistry(
          registryUrl: source.url,
          token: source.token.isEmpty ? null : source.token,
          githubProxy: source.token.isNotEmpty || proxy.isEmpty ? null : proxy,
          page: next,
          pageSize: 100,
          force: next == 1 && force,
        );
        _ensureActive(cancel);
        for (final entry in response.plugins) {
          add(
            RegistryPluginEntry(
              name: entry.name,
              entryPath: entry.entryPath,
              version: entry.version,
              description: entry.description,
              author: entry.author,
              homepage: entry.homepage,
              icon: entry.icon,
              downloadUrl: entry.downloadUrl,
              identity: entry.identity,
              sourceUrl: source.url,
              sourceName: source.name,
            ),
          );
        }
        if (next == 1) catalog.warnings.addAll(response.warnings);
        if (next * 100 >= response.total || response.plugins.isEmpty) break;
      }
    }

    await Future.wait(
      sources.map((source) async {
        final seen = <String>{}, urls = <String>{};
        var connectionFailed = false;
        Future<void> resolve(String address, String credential) async {
          try {
            final data = await _read(
              address,
              proxy,
              credential,
              cancel,
              githubToken: sharedToken,
            );
            String string(String key) =>
                data[key] is String ? data[key] as String : '';
            var download = string('download_url'), update = string('updateUrl');
            final visited = {address};
            for (
              var depth = 0;
              download.isEmpty && update.isNotEmpty && depth < 2;
              depth++
            ) {
              if (!visited.add(update)) {
                throw const FormatException('Update metadata cycle');
              }
              final nextToken =
                  credential.isNotEmpty &&
                          (_sameOrigin(update, address) ||
                              _sameOrigin(update, source.url))
                      ? credential
                      : '';
              final metadata = await _read(
                update,
                proxy,
                nextToken,
                cancel,
                githubToken: sharedToken,
              );
              download =
                  metadata['download_url'] is String
                      ? metadata['download_url'] as String
                      : '';
              update =
                  metadata['updateUrl'] is String
                      ? metadata['updateUrl'] as String
                      : '';
            }
            final entryPath = string('entryPath');
            if (entryPath.isEmpty || download.isEmpty) {
              throw const FormatException(
                'Plugin has no entryPath or download_url',
              );
            }
            _httpAddress(download);
            var icon = string('icon');
            if (icon.isNotEmpty) {
              icon =
                  _httpAddress(address)
                      .resolve(icon.contains('/') ? icon : 'static/$icon')
                      .toString();
              _httpAddress(icon);
              icon = applyGithubProxy(icon, proxy);
            }
            add(
              RegistryPluginEntry(
                name: string('name'),
                entryPath: entryPath,
                version: string('version'),
                description: string('description'),
                author: string('author'),
                homepage: string('homepage'),
                icon: icon.isEmpty ? null : icon,
                downloadUrl: download,
                sourceUrl: source.url,
                sourceName: source.name,
                identity: registryIdentity(
                  string('author'),
                  string('updateUrl'),
                ),
              ),
            );
          } catch (error) {
            if (error is _RegistryConnectionError) connectionFailed = true;
            warn(address, error);
          }
        }

        Future<void> visit(String address, String credential, int depth) async {
          _ensureActive(cancel);
          final key = address.replaceFirst(RegExp(r'/$'), '');
          if (seen.contains(key)) return;
          if (depth > 20 || seen.length >= 512) {
            warn(
              address,
              const FormatException('Registry include limit reached'),
            );
            return;
          }
          seen.add(key);
          final registry = await _read(
            address,
            proxy,
            credential,
            cancel,
            githubToken: sharedToken,
          );
          final plugins = registry['plugins'],
              includes = registry['includes'] ?? [];
          if (plugins is! List ||
              plugins.any((url) => url is! String) ||
              includes is! List ||
              includes.any((url) => url is! String)) {
            throw const FormatException('Invalid registry URL list');
          }
          final work = <Future<void>>[];
          for (final url in plugins.cast<String>()) {
            if (urls.contains(url)) continue;
            if (urls.length >= 500) {
              warn(
                source.url,
                const FormatException('Plugin limit reached (500)'),
              );
              break;
            }
            urls.add(url);
            work.add(resolve(url, credential));
          }
          for (final url in includes.cast<String>()) {
            if (seen.length >= 512) {
              warn(
                source.url,
                const FormatException('Registry include limit reached'),
              );
              break;
            }
            work.add(
              visit(
                url,
                credential.isNotEmpty && _sameOrigin(url, address)
                    ? credential
                    : '',
                depth + 1,
              ).catchError((Object error) {
                if (error is _RegistryConnectionError) connectionFailed = true;
                warn(url, error);
              }),
            );
          }
          await Future.wait(work);
        }

        try {
          await visit(source.url, source.token, 0);
        } catch (error) {
          if (error is _RegistryConnectionError) connectionFailed = true;
          warn(source.url, error);
        }
        if (_web && connectionFailed) {
          try {
            await fallback(source);
          } catch (error) {
            warn(source.url, error);
          }
        }
      }),
    );
    _ensureActive(cancel);
    if (revision == _revision &&
        (catalog.plugins.isNotEmpty || catalog.warnings.isEmpty)) {
      _cache = (
        catalog: catalog,
        until: _now().add(const Duration(minutes: 5)),
      );
    }
    return snapshot(catalog);
  }
}
