import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:logging/logging.dart';
import 'package:otel_logging_dart/otel_logging_dart.dart';
import 'package:test/test.dart';

void main() {
  const config = OtelConfig(
    enabled: true,
    endpoint: 'http://collector.test/v1/logs',
    serviceName: 'test-app',
  );

  OtelLogRecord record() => OtelLogRecord(
        severityNumber: SeverityMapper.severityInfo,
        severityText: 'info',
        body: 'order processed',
      );

  test('posts a JSON payload to the configured endpoint', () async {
    Uri? calledUri;
    Map<String, Object?>? sentBody;

    final client = MockClient((request) async {
      calledUri = request.url;
      sentBody = jsonDecode(request.body) as Map<String, Object?>;
      return http.Response('', 204);
    });

    final exporter = OtelLogExporter(config: config, client: client);
    await exporter.emit(record());

    expect(calledUri.toString(), 'http://collector.test/v1/logs');
    expect(sentBody, contains('resourceLogs'));
  });

  test('does nothing when disabled', () async {
    var called = false;
    final client = MockClient((request) async {
      called = true;
      return http.Response('', 204);
    });

    final exporter = OtelLogExporter(
      config: config.copyWith(enabled: false),
      client: client,
    );
    await exporter.emit(record());

    expect(called, isFalse);
  });

  test('routes non-2xx responses to the error handler without throwing',
      () async {
    Object? reported;
    final client = MockClient((request) async => http.Response('nope', 500));

    final exporter = OtelLogExporter(
      config: config,
      client: client,
      onError: (error, _) => reported = error,
    );

    await exporter.emit(record());
    expect(reported, isA<http.ClientException>());
    expect(reported.toString(), contains('HTTP 500'));
  });

  test('reports an error when the endpoint is empty', () async {
    Object? reported;
    final client = MockClient((request) async => http.Response('', 204));

    final exporter = OtelLogExporter(
      config: config.copyWith(endpoint: '   '),
      client: client,
      onError: (error, _) => reported = error,
    );

    await exporter.emit(record());
    expect(reported, isA<StateError>());
  });

  test('attachToLogger exports emitted log records', () async {
    final bodies = <String>[];
    final client = MockClient((request) async {
      final decoded = jsonDecode(request.body) as Map<String, Object?>;
      final resourceLogs = decoded['resourceLogs'] as List;
      final scopeLogs = (resourceLogs.first as Map)['scopeLogs'] as List;
      final logRecords = (scopeLogs.first as Map)['logRecords'] as List;
      final body = (logRecords.first as Map)['body'] as Map;
      bodies.add(body['stringValue'] as String);
      return http.Response('', 204);
    });

    final logger = Logger.detached('test')..level = Level.ALL;
    final exporter = OtelLogExporter(config: config, client: client);
    final subscription = exporter.attachToLogger(logger);

    logger.info('hello from logging');
    await Future<void>.delayed(Duration.zero);

    expect(bodies, contains('hello from logging'));
    await subscription.cancel();
  });
}
