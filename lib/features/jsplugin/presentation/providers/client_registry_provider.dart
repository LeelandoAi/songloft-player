import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../settings/presentation/providers/settings_provider.dart';
import '../../data/client_registry_api.dart';
import 'jsplugin_provider.dart';

final clientRegistryApiProvider = Provider.autoDispose<ClientRegistryApi>((
  ref,
) {
  final settings = ref.watch(settingsApiProvider);
  final api = ClientRegistryApi(
    backend: ref.watch(jsPluginApiProvider),
    registries: settings.getPluginRegistries,
    githubToken: settings.getGithubDiscoveryToken,
  );
  ref.onDispose(api.close);
  return api;
});
