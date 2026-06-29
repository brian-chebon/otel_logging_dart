import 'package:logging/logging.dart';

import 'severity_mapper.dart';

/// A single log entry to export, independent of any logging framework.
///
/// Build one directly, or use [OtelLogRecord.fromLogging] to convert a
/// `package:logging` [LogRecord].
class OtelLogRecord {
  /// When the event occurred. Defaults to [DateTime.now] at construction.
  final DateTime time;

  /// The OTLP `severityNumber` (1-24).
  final int severityNumber;

  /// The OTLP `severityText` label.
  final String severityText;

  /// The log message (becomes the OTLP `body`).
  final String body;

  /// Structured attributes for this record.
  final Map<String, Object?> attributes;

  /// A 32 hex-character W3C trace id, or `null`.
  final String? traceId;

  /// A 16 hex-character W3C span id, or `null`.
  final String? spanId;

  /// W3C trace flags (0-255), or `null` to derive a sensible default.
  final int? traceFlags;

  /// An associated error/exception, expanded into `exception.*` attributes.
  final Object? error;

  /// A stack trace associated with [error].
  final StackTrace? stackTrace;

  OtelLogRecord({
    required this.severityNumber,
    required this.severityText,
    required this.body,
    DateTime? time,
    Map<String, Object?>? attributes,
    this.traceId,
    this.spanId,
    this.traceFlags,
    this.error,
    this.stackTrace,
  })  : time = time ?? DateTime.now(),
        attributes = attributes ?? const {};

  /// Convert a `package:logging` [record] into an [OtelLogRecord].
  ///
  /// Severity is derived from the record's [Level] via [mapper]. When the
  /// record's `object` is a [Map] it is used as the attribute set, and the
  /// reserved keys `trace_id`, `span_id` and `trace_flags` are lifted out of
  /// the attributes into the dedicated fields.
  factory OtelLogRecord.fromLogging(
    LogRecord record, {
    SeverityMapper mapper = const SeverityMapper(),
  }) {
    final severity = mapper.fromLevel(record.level);

    final attributes = <String, Object?>{};
    final object = record.object;

    // When a Map is logged as the message object, treat its entries as
    // attributes. A `message` key (if present) supplies the log body so the
    // body isn't the Map's raw `toString()`.
    var body = record.message;
    if (object is Map) {
      object.forEach((key, value) {
        attributes['$key'] = value;
      });
      final messageAttribute = attributes.remove('message');
      if (messageAttribute != null) {
        body = messageAttribute.toString();
      }
    }
    attributes.putIfAbsent('logger.name', () => record.loggerName);

    final traceId = _takeString(attributes.remove('trace_id'));
    final spanId = _takeString(attributes.remove('span_id'));
    final traceFlags = _takeInt(attributes.remove('trace_flags'));

    return OtelLogRecord(
      time: record.time,
      severityNumber: severity.number,
      severityText: severity.text,
      body: body,
      attributes: attributes,
      traceId: traceId,
      spanId: spanId,
      traceFlags: traceFlags,
      error: record.error,
      stackTrace: record.stackTrace,
    );
  }

  static String? _takeString(Object? value) => value?.toString();

  static int? _takeInt(Object? value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}
