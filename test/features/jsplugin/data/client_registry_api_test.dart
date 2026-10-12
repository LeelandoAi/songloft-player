import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/features/jsplugin/data/client_registry_api.dart';
import 'package:songloft_flutter/features/jsplugin/data/jsplugin_api.dart';
import 'package:songloft_flutter/features/settings/data/settings_api.dart';

const root = 'https://raw.githubusercontent.com/alice/store/main/registry.json';
String url(String name) =>
    'https://raw.githubusercontent.com/alice/store/main/$name.json';
Map<String, dynamic> manifest(
  String name, {
  String version = '1.0.0',
  String author = 'Alice',
}) => {
  'name': name,
  'entryPath': name,
  'version': version,
  'author': author,
  'download_url':
      'https://github.com/alice/store/releases/download/v1/$name.jsplugin.zip',
};

class _Adapter implements HttpClientAdapter {
  final FutureOr<dynamic> Function(RequestOptions) handle;
  final requests = <RequestOptions>[];
  _Adapter(this.handle);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    final data = await handle(options);
    return ResponseBody.fromString(
      jsonEncode(data),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Backend extends JSPluginApi {
  _Backend() : super(dio: Dio());
  List<JSPlugin> installed = [];
  final fallbackCalls = <({String? proxy, String? token})>[];
  RegistryRefreshResponse fallback = RegistryRefreshResponse(
    plugins: [],
    total: 0,
    page: 1,
    pageSize: 100,
  );
  @override
  Future<List<JSPlugin>> getPlugins() async => installed;
  @override
  Future<RegistryRefreshResponse> refreshRegistry({
    String registryUrl = '',
    bool allSources = false,
    int page = 1,
    int pageSize = 20,
    String? search,
    String? githubProxy,
    String? token,
    bool force = false,
  }) async {
    fallbackCalls.add((proxy: githubProxy, token: token));
    return fallback;
  }
}

void main() {
  List<PluginRegistryConfig> sources({String token = ''}) => [
    PluginRegistryConfig(url: root, name: 'Main', token: token),
  ];
  ({ClientRegistryApi api, _Backend backend, _Adapter adapter}) fixture(
    Map<String, dynamic> routes, {
    bool web = false,
    String token = '',
    Future<String> Function()? githubToken,
    Future<List<PluginRegistryConfig>> Function()? registryReader,
  }) {
    final backend = _Backend();
    final adapter = _Adapter((request) async {
      final address = request.uri.toString().replaceFirst(
        'https://mirror.test/',
        '',
      );
      final result = routes[address];
      if (result is Exception) throw result;
      if (result is Future) return result;
      return result;
    });
    final api = ClientRegistryApi(
      backend: backend,
      registries: registryReader ?? () async => sources(token: token),
      publicDio: Dio()..httpClientAdapter = adapter,
      web: web,
      githubToken: githubToken,
    );
    addTearDown(api.close);
    return (api: api, backend: backend, adapter: adapter);
  }

  test('慢插件和 includes 尚未完成时，已解析插件先产生进度', () async {
    final slow = Completer<Map<String, dynamic>>();
    final f = fixture({
      root: {
        'plugins': [url('fast'), url('slow')],
        'includes': [url('include')],
      },
      url('fast'): manifest('fast'),
      url('slow'): slow.future,
      url('include'): {
        'plugins': [url('third')],
        'includes': [root],
      },
      url('third'): manifest('third'),
    });
    final progress = <RegistryRefreshResponse>[];
    final firstPlugin = Completer<void>();
    var complete = false;
    final pending = f.api
        .refreshRegistry(
          allSources: true,
          registries: sources(),
          onProgress: (page) {
            progress.add(page);
            if (!firstPlugin.isCompleted &&
                page.plugins.any((entry) => entry.name == 'fast')) {
              firstPlugin.complete();
            }
          },
        )
        .then((result) {
          complete = true;
          return result;
        });
    await firstPlugin.future.timeout(const Duration(seconds: 5));
    expect(complete, isFalse);
    expect(
      progress.any((page) => page.plugins.any((entry) => entry.name == 'fast')),
      isTrue,
    );
    slow.complete(manifest('slow'));
    expect(
      (await pending).plugins.map((entry) => entry.name),
      unorderedEquals(['fast', 'slow', 'third']),
    );
    expect(f.backend.fallbackCalls, isEmpty);
  });

  test('私有源 Token 用于源定义的插件直连，跨域 includes 不继承', () async {
    const foreign = 'https://public.test/registry.json',
        plugin = 'https://public.test/plugin.json';
    final f = fixture({
      root: {
        'plugins': [url('private')],
        'includes': [foreign],
      },
      url('private'): manifest('private'),
      foreign: {
        'plugins': [plugin],
      },
      plugin: manifest('public'),
    }, token: 'ghp_private');
    final result = await f.api.refreshRegistry(
      allSources: true,
      registries: sources(token: 'ghp_private'),
      githubProxy: 'https://mirror.test/',
    );
    expect(result.plugins, hasLength(2));
    for (final request in f.adapter.requests) {
      expect(request.uri.host, isNot('mirror.test'));
      expect(
        request.headers['Authorization'],
        request.uri.host == 'raw.githubusercontent.com'
            ? 'Bearer ghp_private'
            : null,
      );
      expect(request.uri.toString(), isNot(contains('ghp_private')));
    }
  });

  test('源 Token 优先于共享 GitHub Token，共享 Token 只用于官方 API', () async {
    const apiRoot = 'https://api.github.com/registry.json';
    const apiPlugin = 'https://api.github.com/plugin.json';
    final f = fixture({
      apiRoot: {
        'plugins': [apiPlugin, url('public')],
      },
      apiPlugin: manifest('api'),
      url('public'): manifest('public'),
    });
    for (final sourceToken in ['ghp_source', '']) {
      f.adapter.requests.clear();
      final result = await f.api.refreshRegistry(
        allSources: true,
        registries: [
          PluginRegistryConfig(url: apiRoot, name: 'API', token: sourceToken),
        ],
        githubToken: 'ghp_shared',
        githubProxy: 'https://mirror.test/',
      );
      expect(result.plugins, hasLength(2));
      for (final request in f.adapter.requests) {
        if (sourceToken.isNotEmpty) {
          expect(request.headers['Authorization'], 'Bearer ghp_source');
          expect(request.uri.host, isNot('mirror.test'));
        } else if (request.uri.host == 'api.github.com') {
          expect(request.headers['Authorization'], 'Bearer ghp_shared');
          expect(request.followRedirects, isFalse);
        } else {
          expect(request.headers['Authorization'], isNull);
          expect(request.uri.host, 'mirror.test');
        }
      }
    }
  });

  test('按规范化作者合并高版本，保留同入口其他作者并判断安装冲突', () async {
    final f = fixture({
      root: {
        'plugins': [url('old'), url('new'), url('other')],
      },
      url('old'): manifest('music', author: ' Alice <a@x> '),
      url('new'): manifest(
        'music',
        version: '2.0.0',
        author: 'ALICE (maintainer)',
      ),
      url('other'): manifest('music', version: '3.0.0', author: 'Bob'),
    });
    f.backend.installed = [
      JSPlugin(
        id: 1,
        name: 'Installed',
        entryPath: 'music',
        author: 'alice',
        version: '1.0.0',
        filePath: '',
        status: 'active',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ];
    final entries =
        (await f.api.refreshRegistry(
          allSources: true,
          registries: sources(),
        )).plugins;
    expect(entries, hasLength(2));
    final alice = entries.singleWhere((entry) => entry.identity == 'alice');
    expect(alice.version, '2.0.0');
    expect(alice.installed && alice.hasUpdate && !alice.conflict, isTrue);
    final bob = entries.singleWhere((entry) => entry.identity == 'bob');
    expect(bob.conflict && !bob.installed && !bob.hasUpdate, isTrue);
  });

  test('共享配置读取失败不阻止私有源认证，警告不包含原始错误', () async {
    final f = fixture(
      {
        root: {
          'plugins': [url('private')],
        },
        url('private'): manifest('private'),
      },
      token: 'ghp_source',
      githubToken: () async => throw Exception('ghp_do_not_log'),
    );
    final result = await f.api.refreshRegistry(
      allSources: true,
      registries: sources(token: 'ghp_source'),
    );
    expect(result.plugins, hasLength(1));
    expect(result.warnings, ['Could not read GitHub token setting.']);
    expect(
      f.adapter.requests.every(
        (request) => request.headers['Authorization'] == 'Bearer ghp_source',
      ),
      isTrue,
    );
  });

  test('主动刷新同步最新源凭据，后续翻页继续使用新缓存', () async {
    final f = fixture(
      {
        root: {
          'plugins': [url('private')],
        },
        url('private'): manifest('private'),
      },
      token: 'ghp_old',
      registryReader: () async => sources(token: 'ghp_new'),
    );
    var current = sources(token: 'ghp_old');
    await f.api.refreshRegistry(allSources: true, registries: current);
    f.adapter.requests.clear();
    await f.api.refreshRegistry(
      allSources: true,
      registries: current,
      force: true,
      onSources: (fresh) => current = fresh,
    );
    expect(current.single.token, 'ghp_new');
    expect(
      f.adapter.requests.every(
        (request) => request.headers['Authorization'] == 'Bearer ghp_new',
      ),
      isTrue,
    );
    final count = f.adapter.requests.length;
    await f.api.refreshRegistry(allSources: true, registries: current, page: 2);
    expect(f.adapter.requests, hasLength(count));
  });

  for (final disabled in [false, true]) {
    test('刷新不再使用被删除或停用源的旧 Token disabled=$disabled', () async {
      const other = 'https://public.test/registry.json',
          plugin = 'https://public.test/plugin.json';
      final f = fixture(
        {
          other: {
            'plugins': [plugin],
          },
          plugin: manifest('remaining'),
        },
        token: 'ghp_old',
        registryReader:
            () async => [
              PluginRegistryConfig(url: other, name: 'Remaining'),
              if (disabled)
                PluginRegistryConfig(
                  url: root,
                  name: 'Old',
                  enabled: false,
                  token: 'ghp_old',
                ),
            ],
      );
      final result = await f.api.refreshRegistry(
        registryUrl: root,
        registries: sources(token: 'ghp_old'),
        token: 'ghp_old',
        force: true,
      );
      expect(result.plugins.map((entry) => entry.entryPath), ['remaining']);
      expect(
        f.adapter.requests.every(
          (request) =>
              request.uri.host == 'public.test' &&
              request.headers['Authorization'] == null,
        ),
        isTrue,
      );
    });
  }

  test('客户端最多并发八个请求', () async {
    var active = 0, maximum = 0;
    final backend = _Backend();
    final urls = List.generate(25, (i) => url('plugin$i'));
    final adapter = _Adapter((request) async {
      if (request.uri.toString() == root) return {'plugins': urls};
      active++;
      if (active > maximum) maximum = active;
      await Future<void>.delayed(const Duration(milliseconds: 1));
      active--;
      return manifest(request.uri.pathSegments.last.replaceFirst('.json', ''));
    });
    final api = ClientRegistryApi(
      backend: backend,
      registries: () async => sources(),
      publicDio: Dio()..httpClientAdapter = adapter,
    );
    addTearDown(api.close);
    expect(
      (await api.refreshRegistry(allSources: true, pageSize: 100)).plugins,
      hasLength(25),
    );
    expect(maximum, 8);
  });

  test('刷新到有效空源后替换旧缓存，搜索不会恢复已删除插件', () async {
    final routes = <String, dynamic>{
      root: {
        'plugins': [url('old')],
      },
      url('old'): manifest('old'),
    };
    final f = fixture(routes);
    expect(
      (await f.api.refreshRegistry(
        allSources: true,
        registries: sources(),
      )).plugins,
      hasLength(1),
    );
    routes[root] = {'plugins': []};
    expect(
      (await f.api.refreshRegistry(
        allSources: true,
        registries: sources(),
        force: true,
      )).total,
      0,
    );
    final count = f.adapter.requests.length;
    expect(
      (await f.api.refreshRegistry(
        allSources: true,
        registries: sources(),
        search: 'old',
      )).total,
      0,
    );
    expect(f.adapter.requests, hasLength(count));
  });

  test('搜索和翻页复用客户端缓存，安装状态重新从服务器读取', () async {
    final f = fixture({
      root: {'plugins': List.generate(25, (index) => url('music$index'))},
      for (var index = 0; index < 25; index++)
        url('music$index'): manifest('music$index'),
    });
    expect(
      (await f.api.refreshRegistry(
        allSources: true,
        registries: sources(),
      )).plugins,
      hasLength(20),
    );
    final count = f.adapter.requests.length;
    expect(
      (await f.api.refreshRegistry(
        allSources: true,
        registries: sources(),
        page: 2,
      )).plugins,
      hasLength(5),
    );
    f.backend.installed = [
      JSPlugin(
        id: 1,
        entryPath: 'music24',
        author: 'Alice',
        version: '1.0.0',
        filePath: '',
        status: 'active',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ];
    expect(
      (await f.api.refreshRegistry(
        allSources: true,
        registries: sources(),
        search: 'music24',
      )).plugins.single.installed,
      isTrue,
    );
    expect(f.adapter.requests, hasLength(count));
    await f.api.refreshRegistry(
      allSources: true,
      registries: sources(),
      force: true,
    );
    expect(f.adapter.requests.length, greaterThan(count));
  });

  test('Web 跨域错误回退后端，私有源回退不传 GitHub 加速代理', () async {
    final f = fixture(
      {
        root: DioException(
          requestOptions: RequestOptions(path: root),
          type: DioExceptionType.connectionError,
        ),
      },
      web: true,
      token: 'ghp_private',
    );
    f.backend.fallback = RegistryRefreshResponse(
      plugins: [
        RegistryPluginEntry(
          name: 'Fallback',
          entryPath: 'fallback',
          version: '1.0.0',
          downloadUrl: 'https://github.com/a/b/releases/download/v1/pkg.zip',
        ),
      ],
      total: 1,
      page: 1,
      pageSize: 100,
    );
    expect(
      (await f.api.refreshRegistry(
        allSources: true,
        registries: sources(token: 'ghp_private'),
        githubProxy: 'https://mirror.test/',
      )).plugins.single.name,
      'Fallback',
    );
    expect(f.backend.fallbackCalls.single, (proxy: null, token: 'ghp_private'));
  });

  test('坏插件仅记警告，取消后不再产生迟到进度', () async {
    final f = fixture({
      root: {
        'plugins': [url('good'), url('bad')],
      },
      url('good'): manifest('good'),
      url('bad'): {'broken': true},
    });
    final result = await f.api.refreshRegistry(
      allSources: true,
      registries: sources(),
    );
    expect(result.plugins, hasLength(1));
    expect(result.warnings, hasLength(1));
    expect(f.backend.fallbackCalls, isEmpty);
    final cancel = CancelToken()..cancel();
    var progress = 0;
    await expectLater(
      f.api.refreshRegistry(
        allSources: true,
        registries: sources(),
        force: true,
        cancelToken: cancel,
        onProgress: (_) => progress++,
      ),
      throwsA(isA<DioException>()),
    );
    expect(progress, 0);
  });

  test('身份和版本比较与后端口径一致', () {
    expect(registryIdentity(' Alice <a@x> (author) ', ''), 'alice');
    expect(
      registryIdentity('', 'https://github.com/Alice/Repo/releases/latest'),
      'repo:alice/repo',
    );
    expect(registryIdentity('', 'https://example.com/Alice/Repo'), '');
    expect(compareRegistryVersions('2026.10.12', '2026.9.30'), greaterThan(0));
    expect(compareRegistryVersions('1.2', '1.2.0'), 0);
  });
}
