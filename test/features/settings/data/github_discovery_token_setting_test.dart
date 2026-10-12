import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/core/network/api_client.dart';
import 'package:songloft_flutter/core/storage/secure_storage.dart';
import 'package:songloft_flutter/features/settings/data/settings_api.dart';

class _TokenSettingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  String token = '';
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    if (options.method == 'PUT') {
      token = (options.data as Map)['token'] as String;
    }
    return ResponseBody.fromString(
      jsonEncode({'token': token}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('业务接口持久化读写使用服务器认证，GitHub 凭据不进入调试日志', () async {
    final original = SecureStorageService.cachedAccessToken;
    SecureStorageService.cachedAccessToken = 'server-jwt';
    addTearDown(() => SecureStorageService.cachedAccessToken = original);
    final dio = createDio(
      secureStorage: SecureStorageService(),
      customBaseUrl: 'https://server.test/music',
    );
    final adapter = _TokenSettingAdapter();
    dio.httpClientAdapter = adapter;
    addTearDown(dio.close);
    final api = SettingsApi(dio: dio);
    final logged = <String>[];
    await runZoned(
      () async {
        expect(await api.getGithubDiscoveryToken(), '');
        expect(
          await api.updateGithubDiscoveryToken('  ghp_log_secret  '),
          'ghp_log_secret',
        );
        expect(await api.getGithubDiscoveryToken(), 'ghp_log_secret');
        expect(await api.updateGithubDiscoveryToken(''), '');
      },
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, line) => logged.add(line),
      ),
    );
    expect(adapter.requests, hasLength(4));
    expect(
      adapter.requests.every(
        (request) =>
            request.uri.path ==
                '/music/api/v1/settings/github-discovery-token' &&
            request.headers['Authorization'] == 'Bearer server-jwt',
      ),
      isTrue,
    );
    expect(logged.join('\n'), isNot(contains('ghp_log_secret')));
  });
}
