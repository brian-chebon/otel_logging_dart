import 'package:logging/logging.dart';
import 'package:otel_logging_dart/otel_logging_dart.dart';
import 'package:test/test.dart';

/// Mirrors how `package:logging` builds a record: a non-String message is
/// stringified into `message` and preserved in `object`.
LogRecord makeRecord(Object message, {String logger = 'test'}) {
  final isString = message is String;
  return LogRecord(
    Level.INFO,
    isString ? message : message.toString(),
    logger,
    null,
    null,
    null,
    isString ? null : message,
  );
}

void main() {
  group('OtelLogRecord.fromLogging', () {
    test('uses a string message as the body', () {
      final record = OtelLogRecord.fromLogging(makeRecord('hello'));
      expect(record.body, 'hello');
    });

    test('lifts the map "message" key into the body', () {
      final record = OtelLogRecord.fromLogging(
        makeRecord({'message': 'order processed', 'order_id': 1234}),
      );

      expect(record.body, 'order processed');
      expect(record.attributes.containsKey('message'), isFalse);
      expect(record.attributes['order_id'], 1234);
    });

    test('always adds logger.name', () {
      final record =
          OtelLogRecord.fromLogging(makeRecord('hi', logger: 'orders'));
      expect(record.attributes['logger.name'], 'orders');
    });

    test('lifts trace context out of the attributes', () {
      final record = OtelLogRecord.fromLogging(makeRecord({
        'message': 'processing',
        'trace_id': '0af7651916cd43dd8448eb211c80319c',
        'span_id': 'b7ad6b7169203331',
        'trace_flags': 1,
      }));

      expect(record.traceId, '0af7651916cd43dd8448eb211c80319c');
      expect(record.spanId, 'b7ad6b7169203331');
      expect(record.traceFlags, 1);
      expect(record.attributes.containsKey('trace_id'), isFalse);
      expect(record.attributes.containsKey('span_id'), isFalse);
    });

    test('maps the severity from the level', () {
      final record =
          OtelLogRecord.fromLogging(LogRecord(Level.SEVERE, 'boom', 'x'));
      expect(record.severityNumber, SeverityMapper.severityError);
      expect(record.severityText, 'severe');
    });
  });
}
