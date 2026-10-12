import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../settings/data/settings_api.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../providers/github_discovery_token_provider.dart';

class GithubDiscoveryTokenDialog extends ConsumerStatefulWidget {
  const GithubDiscoveryTokenDialog({super.key});

  @override
  ConsumerState<GithubDiscoveryTokenDialog> createState() =>
      _TokenDialogState();
}

class _TokenDialogState extends ConsumerState<GithubDiscoveryTokenDialog> {
  final _input = TextEditingController();
  late final SettingsApi _openedApi;
  bool _saving = false;
  bool _hidden = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _openedApi = ref.read(settingsApiProvider);
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _save(String token) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(githubDiscoveryTokenProvider.notifier).save(token);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = AppLocalizations.of(context).githubDiscoveryTokenSaveFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final credential = ref.watch(githubDiscoveryTokenProvider);
    ref.listen(settingsApiProvider, (_, api) {
      if (!identical(api, _openedApi) && mounted) Navigator.pop(context);
    });
    final ready =
        credential.hasValue && !credential.isLoading && !credential.hasError;
    return AlertDialog(
      title: Text(l10n.githubDiscoveryTokenTitle),
      scrollable: true,
      content: SizedBox(
        width: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.githubDiscoveryTokenHelp),
            const SizedBox(height: 12),
            if (credential.isLoading) const LinearProgressIndicator(),
            if (ready)
              Text(
                credential.requireValue.isEmpty
                    ? l10n.githubDiscoveryTokenNotConfigured
                    : l10n.githubDiscoveryTokenConfigured,
              ),
            if (credential.hasError) ...[
              Text(l10n.githubDiscoveryTokenLoadFailed),
              TextButton(
                onPressed: () => ref.invalidate(githubDiscoveryTokenProvider),
                child: Text(l10n.commonRetry),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _input,
              enabled: ready && !_saving,
              obscureText: _hidden,
              autocorrect: false,
              enableSuggestions: false,
              maxLength: 512,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.githubDiscoveryTokenTitle,
                hintText: l10n.githubDiscoveryTokenHint,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: l10n.githubDiscoveryTokenVisibility,
                  icon: Icon(_hidden ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _hidden = !_hidden),
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                try {
                  final opened = await launchUrl(
                    Uri.parse('https://github.com/settings/tokens'),
                  );
                  if (!opened) {
                    throw StateError('Could not open link');
                  }
                } catch (_) {
                  if (mounted) {
                    setState(() => _error = l10n.githubDiscoveryOpenFailed);
                  }
                }
              },
              child: Text(l10n.githubDiscoveryTokenCreate),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        if (ready && credential.requireValue.isNotEmpty)
          TextButton(
            onPressed: _saving ? null : () => _save(''),
            child: Text(l10n.githubDiscoveryTokenClear),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed:
              !ready || _saving || _input.text.trim().isEmpty
                  ? null
                  : () => _save(_input.text.trim()),
          child: Text(
            _saving ? l10n.jspluginLoadingList : l10n.githubDiscoveryTokenSave,
          ),
        ),
      ],
    );
  }
}
