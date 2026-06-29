import 'dart:convert';

/// Converts Dart values into OpenTelemetry (OTLP) attribute structures.
///
/// Each formatted attribute is a `{'key': ..., 'value': {<typed value>}}` map,
/// matching the OTLP JSON `KeyValue`/`AnyValue` shape.
class AttributeFormatter {
  const AttributeFormatter();

  /// Format a single key/value pair into an OTLP `KeyValue` map.
  Map<String, Object?> formatAttribute(String key, Object? value) {
    return {'key': key, 'value': _formatValue(value)};
  }

  /// Convert a [Map] of attributes into a list of OTLP `KeyValue` maps.
  ///
  /// A `'exception'` (or `'error'`) entry whose value is an [Object] is
  /// expanded into the semantic `exception.*` attributes. Pass [stackTrace] to
  /// attach `exception.stacktrace` for the primary error.
  List<Map<String, Object?>> processAttributes(
    Map<String, Object?> attributes, {
    StackTrace? stackTrace,
  }) {
    final result = <Map<String, Object?>>[];

    attributes.forEach((key, value) {
      if ((key == 'exception' || key == 'error') && _isError(value)) {
        result.addAll(_formatError(value!, stackTrace));
      } else {
        result.add(formatAttribute(key, value));
      }
    });

    return result;
  }

  /// Build the OTLP `exception.*` attributes for an [error].
  List<Map<String, Object?>> formatErrorAttributes(
    Object error, [
    StackTrace? stackTrace,
  ]) {
    return _formatError(error, stackTrace);
  }

  Map<String, Object?> _formatValue(Object? value) {
    if (value == null) {
      return {'stringValue': 'null'};
    }
    if (value is bool) {
      return {'boolValue': value};
    }
    if (value is int) {
      return {'intValue': value};
    }
    if (value is double) {
      return {'doubleValue': value};
    }
    if (value is String) {
      return {'stringValue': value};
    }
    if (value is Map || value is Iterable) {
      return {'stringValue': _encodeJson(value)};
    }
    return {'stringValue': value.toString()};
  }

  String _encodeJson(Object value) {
    try {
      return jsonEncode(value);
    } catch (_) {
      return value.toString();
    }
  }

  bool _isError(Object? value) =>
      value != null && value is! String && value is! num && value is! bool;

  List<Map<String, Object?>> _formatError(
      Object error, StackTrace? stackTrace) {
    final attributes = <Map<String, Object?>>[
      formatAttribute('exception.type', error.runtimeType.toString()),
      formatAttribute('exception.message', error.toString()),
    ];

    if (stackTrace != null) {
      attributes.add(
        formatAttribute('exception.stacktrace', stackTrace.toString()),
      );
    }

    return attributes;
  }
}
