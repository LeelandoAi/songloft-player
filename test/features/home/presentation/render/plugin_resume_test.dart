import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/core/theme/app_theme.dart';
import 'package:songloft_flutter/features/home/presentation/render/plugin_color_scheme.dart';
import 'package:songloft_flutter/features/home/presentation/render/plugin_render_controller.dart';
import 'package:songloft_flutter/features/home/presentation/render/plugin_render_surface_webview.dart';
import 'package:songloft_flutter/features/player/domain/player_state.dart';
import 'package:songloft_flutter/features/player/presentation/providers/player_provider.dart';

void main() {
  testWidgets(
    'plugin back is consulted before browser history with safe fallback',
    (tester) async {
      final previousPlatform = InAppWebViewPlatform.instance;
      final platform = _FakeWebViewPlatform();
      InAppWebViewPlatform.instance = platform;
      addTearDown(() {
        if (previousPlatform != null) {
          InAppWebViewPlatform.instance = previousPlatform;
        }
      });
      late PluginRenderController renderController;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [playerStateProvider.overrideWith(_FakePlayer.new)],
          child: MaterialApp(
            home: PluginRenderSurfaceWebView(
              url: 'http://localhost/api/v1/jsplugin/miot/',
              theme: 'light',
              onLoadStart: () {},
              onLoadStop: () {},
              onError: (_) {},
              onControllerReady: (controller) => renderController = controller,
            ),
          ),
        ),
      );
      final webView = platform.webView!;
      final controller = _FakeController();
      final appController = InAppWebViewController.fromPlatform(
        platform: controller,
      );
      webView.params.onWebViewCreated!(appController);

      // Loading pages only consult history; no event dispatch into an unready SPA.
      expect(await renderController.goBackIfPossible(), false);
      expect(controller.scripts, isEmpty);
      webView.params.onLoadStop!(appController, WebUri('http://localhost'));
      controller.scripts.clear();
      controller.historyChecks = 0;

      controller.backResult = true;
      controller.hasHistory = true;
      expect(await renderController.goBackIfPossible(), true);
      expect(
        controller.scripts.single,
        contains("new Event('songloft-back', {cancelable: true})"),
      );
      expect(controller.historyChecks, 0);
      expect(controller.historyBacks, 0);

      for (final result in [false, null, 'true']) {
        controller.backResult = result;
        expect(await renderController.goBackIfPossible(), true);
      }
      expect(controller.historyBacks, 3);
      controller.hasHistory = false;
      expect(await renderController.goBackIfPossible(), false);

      controller.backError = StateError('page is reloading');
      controller.hasHistory = true;
      expect(await renderController.goBackIfPossible(), true);
      expect(controller.historyBacks, 4);
      controller.hasHistory = false;
      expect(await renderController.goBackIfPossible(), false);

      controller.backError = null;
      await tester.pumpWidget(const SizedBox.shrink());
      final checks = controller.historyChecks;
      expect(await renderController.goBackIfPossible(), false);
      expect(controller.historyChecks, checks);
    },
  );

  testWidgets('theme dependency changes push current material without reload', (
    tester,
  ) async {
    final previousPlatform = InAppWebViewPlatform.instance;
    final platform = _FakeWebViewPlatform();
    InAppWebViewPlatform.instance = platform;
    addTearDown(() {
      if (previousPlatform != null) {
        InAppWebViewPlatform.instance = previousPlatform;
      }
    });
    final surface = PluginRenderSurfaceWebView(
      url: 'http://localhost/api/v1/jsplugin/miot/',
      theme: 'light',
      onLoadStart: () {},
      onLoadStop: () {},
      onError: (_) {},
      onControllerReady: (_) {},
    );
    Future<void> pumpTheme(ThemeData theme) => tester.pumpWidget(
      ProviderScope(
        overrides: [playerStateProvider.overrideWith(_FakePlayer.new)],
        child: MaterialApp(
          theme: theme,
          themeAnimationDuration: Duration.zero,
          home: surface,
        ),
      ),
    );
    await pumpTheme(AppTheme.lightTheme());
    final surfaceState = tester.state(find.byType(PluginRenderSurfaceWebView));
    final webViewState = tester.state(find.byType(InAppWebView));
    final webView = platform.webView!;
    final controller = _FakeController();
    final appController = InAppWebViewController.fromPlatform(
      platform: controller,
    );
    webView.params.onWebViewCreated!(appController);
    webView.params.onLoadStop!(appController, WebUri('http://localhost'));
    controller.scripts.clear();

    for (final flags in [(true, false), (false, true), (false, false)]) {
      final theme = AppTheme.lightTheme(
        reduceTransparency: flags.$1,
        increaseContrast: flags.$2,
      );
      await pumpTheme(theme);
      await tester.pump();
      final messages = controller.scripts.where(
        (script) => script.contains("type:'songloft-theme'"),
      );
      expect(messages, hasLength(1));
      expect(messages.single, contains('"reduceTransparency":${flags.$1}'));
      expect(messages.single, contains('"increaseContrast":${flags.$2}'));
      expect(
        messages.single,
        contains(jsonEncode(pluginThemeAppearanceMap(theme))),
      );
      expect(
        tester.state(find.byType(PluginRenderSurfaceWebView)),
        same(surfaceState),
      );
      expect(tester.state(find.byType(InAppWebView)), same(webViewState));
      controller.scripts.clear();
      await pumpTheme(theme);
      await tester.pump();
      expect(controller.scripts, isEmpty);
    }
  });

  testWidgets('resume notifies a loaded plugin without reloading its WebView', (
    tester,
  ) async {
    final previousPlatform = InAppWebViewPlatform.instance;
    final platform = _FakeWebViewPlatform();
    InAppWebViewPlatform.instance = platform;
    addTearDown(() {
      if (previousPlatform != null) {
        InAppWebViewPlatform.instance = previousPlatform;
      }
    });
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [playerStateProvider.overrideWith(_FakePlayer.new)],
        child: MaterialApp(
          home: PluginRenderSurfaceWebView(
            url: 'http://localhost/api/v1/jsplugin/miot/',
            theme: 'light',
            onLoadStart: () {},
            onLoadStop: () {},
            onError: (_) {},
            onControllerReady: (_) {},
          ),
        ),
      ),
    );
    final webView = platform.webView!;
    final controller = _FakeController();
    final appController = InAppWebViewController.fromPlatform(
      platform: controller,
    );
    webView.params.onWebViewCreated!(appController);
    // Resume while still loading must not dispatch into an unready page.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(controller.scripts, isEmpty);

    webView.params.onLoadStop!(appController, WebUri('http://localhost'));
    controller.scripts.clear();
    // A resume immediately followed by another background transition should
    // not request a refresh from a page that is still hidden.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(controller.scripts, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    controller.scripts.clear();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(controller.scripts, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(controller.scripts, [
      "document.dispatchEvent(new Event('visibilitychange'))",
    ]);
    expect(platform.webView, same(webView));

    // A callback queued before unmount must not target the disposed WebView.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(controller.scripts, hasLength(1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(controller.scripts, hasLength(1));
  });
}

class _FakePlayer extends PlayerNotifier {
  @override
  PlayerState build() => const PlayerState();
}

class _FakeWebViewPlatform extends InAppWebViewPlatform {
  _FakeWebView? webView;

  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) => webView = _FakeWebView(params);
}

class _FakeWebView extends PlatformInAppWebViewWidget {
  _FakeWebView(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();

  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) =>
      InAppWebViewController.fromPlatform(platform: controller) as T;

  @override
  void dispose() {}
}

class _FakeController extends PlatformInAppWebViewController {
  _FakeController()
    : super.implementation(
        const PlatformInAppWebViewControllerCreationParams(id: 0),
      );

  final scripts = <String>[];
  Object? backResult;
  Object? backError;
  bool hasHistory = false;
  int historyChecks = 0;
  int historyBacks = 0;

  @override
  Future<dynamic> evaluateJavascript({
    required String source,
    ContentWorld? contentWorld,
  }) async {
    scripts.add(source);
    if (source.contains("new Event('songloft-back'")) {
      if (backError != null) throw backError!;
      return backResult;
    }
    return null;
  }

  @override
  Future<bool> canGoBack() async {
    historyChecks += 1;
    return hasHistory;
  }

  @override
  Future<void> goBack() async {
    historyBacks += 1;
  }

  @override
  void addJavaScriptHandler({
    required String handlerName,
    required JavaScriptHandlerCallback callback,
  }) {}
}
