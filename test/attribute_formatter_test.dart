import 'package:otel_logging_dart/otel_logging_dart.dart';
import 'package:test/test.dart';

void main() {
  const formatter = AttributeFormatter();

  group('AttributeFormatter.formatAttribute', () {
    test('formats primitive types into typed OTLP values', () {
      expect(formatter.formatAttribute('a', 'hello')['value'],
          {'stringValue': 'hello'});
      expect(formatter.formatAttribute('a', 42)['value'], {'intValue': 42});
      expect(
          formatter.formatAttribute('a', 3.5)['value'], {'doubleValue': 3.5});
      expect(
          formatter.formatAttribute('a', true)['value'], {'boolValue': true});
    });

    test('renders null as the string "null"', () {
      expect(formatter.formatAttribute('a', null)['value'],
          {'stringValue': 'null'});
    });

    test('json-encodes maps and lists into stringValue', () {
      expect(formatter.formatAttribute('a', {'x': 1})['value'],
          {'stringValue': '{"x":1}'});
      expect(formatter.formatAttribute('a', [1, 2])['value'],
          {'stringValue': '[1,2]'});
    });
  });

  group('AttributeFormatter.processAttributes', () {
    test('expands an exception entry into exception.* attributes', () {
      final attrs = formatter.processAttributes(
        {'exception': FormatException('boom'), 'order_id': 7},
        stackTrace: StackTrace.fromString('trace-here'),
      );

      final keys = attrs.map((a) => a['key']).toList();
      expect(keys, contains('exception.type'));
      expect(keys, contains('exception.message'));
      expect(keys, contains('exception.stacktrace'));
      expect(keys, contains('order_id'));
    });

    test('preserves insertion order for plain attributes', () {
      final attrs = formatter.processAttributes({'a': 1, 'b': 2});
      expect(attrs.map((a) => a['key']), ['a', 'b']);
    });
  });
}
