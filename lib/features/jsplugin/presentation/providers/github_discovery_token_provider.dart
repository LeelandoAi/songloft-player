import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../settings/presentation/providers/settings_provider.dart';

final githubDiscoveryTokenProvider =
    AsyncNotifierProvider.autoDispose<GithubDiscoveryTokenNotifier, String>(
      GithubDiscoveryTokenNotifier.new,
    );

class GithubDiscoveryTokenNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() =>
      ref.watch(settingsApiProvider).getGithubDiscoveryToken();

  Future<void> save(String token) async {
    final api = ref.read(settingsApiProvider);
    final saved = await api.updateGithubDiscoveryToken(token);
    if (ref.mounted && identical(ref.read(settingsApiProvider), api)) {
      state = AsyncData(saved);
    } else {
      throw StateError('Server changed');
    }
  }
}
