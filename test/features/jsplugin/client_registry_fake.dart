import 'package:dio/dio.dart';
import 'package:songloft_flutter/features/jsplugin/data/client_registry_api.dart';
import 'package:songloft_flutter/features/jsplugin/data/jsplugin_api.dart';
import 'package:songloft_flutter/features/settings/data/settings_api.dart';

/// Existing page tests inject prepared catalogs; network/parser behavior has separate transport fixtures.
class FakeClientRegistryApi extends ClientRegistryApi {
  final JSPluginApi backend;
  void Function(RegistryRefreshResponse)? progress;
  CancelToken? activeCancel;
  FakeClientRegistryApi(this.backend)
    : super(backend: backend, registries: () async => []);

  @override
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
    progress = onProgress;
    activeCancel = cancelToken;
    return backend.refreshRegistry(
      registryUrl: registryUrl,
      allSources: allSources,
      page: page,
      pageSize: pageSize,
      search: search,
      githubProxy: githubProxy,
      token: token,
      force: force,
    );
  }
}
