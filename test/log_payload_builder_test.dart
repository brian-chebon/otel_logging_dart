import 'package:otel_logging_dart/otel_logging_dart.dart';
import 'package:test/test.dart';

void main() {
  const builder = LogPayloadBuilder();
  const config = OtelConfig(
    enabled: true,
    endpoint: 'http://collector.test/v1/logs',
    serviceName: 'test-app',
    serviceVersion: '2.0.0',
    environment: 'testing',
    hostName: 'test-host',
    globalAttributes: {'tenant': 'acme'},
  );

  Map<String, Object?> firstLogRecord(Map<String, Object?> payload) {
    final resourceLogs = payload['resourceLogs'] as List;
    final scopeLogs = (resourceLogs.first as Map)['scopeLogs'] as List;
    final logRecords = (scopeLogs.first as Map)['logRecords'] as List;
    return logRecords.first as Map<String, Object?>;
  }

  test('builds the OTLP resourceLogs envelope with resource attributes', () {
    final record = OtelLogRecord(
      severityNumber: SeverityMapper.severityInfo,
      severityText: 'info',
      body: 'hello',
      time: DateTime.utc(2025, 1, 1),
    );

    final payload = builder.build(record, config);
    final resource =
        ((payload['resourceLogs'] as List).first as Map)['resource'] as Map;
    final attrKeys =
        (resource['attributes'] as List).map((a) => (a as Map)['key']).toList();

    expect(
        attrKeys,
        containsAll(<String>[
          'service.name',
          'service.version',
          'deployment.environment',
          'host.name',
        ]));
  });

  test('encodes the timestamp as nanoseconds since epoch', () {
    final time = DateTime.utc(2025, 1, 1);
    final record = OtelLogRecord(
      severityNumber: 9,
      severityText: 'info',
      body: 'hello',
      time: time,
    );

    final log = firstLogRecord(builder.build(record, config));
    expect(
        log['timeUnixNano'], (time.microsecondsSinceEpoch * 1000).toString());
  });

  test('merges global attributes ahead of record attributes', () {
    final record = OtelLogRecord(
      severityNumber: 9,
      severityText: 'info',
      body: 'hello',
      attributes: {'user_id': 123},
    );

    final log = firstLogRecord(builder.build(record, config));
    final keys = (log['attributes'] as List).map((a) => (a as Map)['key']);
    expect(keys, containsAll(<String>['tenant', 'user_id']));
  });

  group('trace context', () {
    test('keeps a valid trace/span id and marks the record sampled', () {
      final record = OtelLogRecord(
        severityNumber: 9,
        severityText: 'info',
        body: 'hello',
        traceId: '0af7651916cd43dd8448eb211c80319c',
        spanId: 'b7ad6b7169203331',
      );

      final log = firstLogRecord(builder.build(record, config));
      expect(log['traceId'], '0af7651916cd43dd8448eb211c80319c');
      expect(log['spanId'], 'b7ad6b7169203331');
      expect(log['flags'], 1);
    });

    test('drops malformed ids and zeroes the flags', () {
      final record = OtelLogRecord(
        severityNumber: 9,
        severityText: 'info',
        body: 'hello',
        traceId: 'not-a-trace-id',
        spanId: 'short',
      );

      final log = firstLogRecord(builder.build(record, config));
      expect(log['traceId'], '');
      expect(log['spanId'], '');
      expect(log['flags'], 0);
    });
  });

  test('expands a record-level error into exception attributes', () {
    final record = OtelLogRecord(
      severityNumber: 17,
      severityText: 'error',
      body: 'failed',
      error: StateError('kaput'),
      stackTrace: StackTrace.fromString('trace'),
    );

    final log = firstLogRecord(builder.build(record, config));
    final keys = (log['attributes'] as List).map((a) => (a as Map)['key']);
    expect(
        keys,
        containsAll(<String>[
          'exception.type',
          'exception.message',
          'exception.stacktrace',
        ]));
  });
}
