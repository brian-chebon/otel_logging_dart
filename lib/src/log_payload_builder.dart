import 'attribute_formatter.dart';
import 'otel_config.dart';
import 'otel_log_record.dart';

/// Builds OTLP `resourceLogs` payloads from [OtelLogRecord]s.
class LogPayloadBuilder {
  final AttributeFormatter attributeFormatter;

  const LogPayloadBuilder({
    this.attributeFormatter = const AttributeFormatter(),
  });

  /// Build a complete OTLP/HTTP JSON payload for a single [record].
  Map<String, Object?> build(OtelLogRecord record, OtelConfig config) {
    return {
      'resourceLogs': [
        {
          'resource': {
            'attributes': _resourceAttributes(config),
          },
          'scopeLogs': [
            {
              'scope': {
                'name': config.scopeName,
                'version': config.scopeVersion,
              },
              'logRecords': [_logRecord(record, config)],
            },
          ],
        },
      ],
    };
  }

  List<Map<String, Object?>> _resourceAttributes(OtelConfig config) {
    return [
      attributeFormatter.formatAttribute('service.name', config.serviceName),
      attributeFormatter.formatAttribute(
          'service.version', config.serviceVersion),
      attributeFormatter.formatAttribute(
          'deployment.environment', config.environment),
      attributeFormatter.formatAttribute('host.name', config.hostName),
    ];
  }

  Map<String, Object?> _logRecord(OtelLogRecord record, OtelConfig config) {
    final traceId = _sanitizeId(record.traceId, 32);
    final spanId = _sanitizeId(record.spanId, 16);

    final attributes = <Map<String, Object?>>[
      ...attributeFormatter.processAttributes(config.globalAttributes),
      ...attributeFormatter.processAttributes(
        record.attributes,
        stackTrace: record.stackTrace,
      ),
    ];

    if (record.error != null && !record.attributes.containsKey('exception')) {
      attributes.addAll(
        attributeFormatter.formatErrorAttributes(
          record.error!,
          record.stackTrace,
        ),
      );
    }

    return {
      'timeUnixNano': _timeUnixNano(record.time),
      'severityNumber': record.severityNumber,
      'severityText': record.severityText,
      'body': {'stringValue': record.body},
      'attributes': attributes,
      'droppedAttributesCount': 0,
      'flags': _resolveFlags(record.traceFlags, traceId, spanId),
      'traceId': traceId,
      'spanId': spanId,
    };
  }

  /// Nanoseconds since epoch, as a string (OTLP `fixed64` JSON encoding).
  String _timeUnixNano(DateTime time) =>
      (time.microsecondsSinceEpoch * 1000).toString();

  /// Validate a trace/span id: lowercase hex of [length] chars, non-zero.
  String _sanitizeId(String? value, int length) {
    if (value == null) return '';
    final normalized = value.trim().toLowerCase();
    final pattern = RegExp('^[0-9a-f]{$length}\$');
    if (!pattern.hasMatch(normalized)) return '';
    if (normalized == '0' * length) return '';
    return normalized;
  }

  int _resolveFlags(int? traceFlags, String traceId, String spanId) {
    if (traceId.isEmpty || spanId.isEmpty) return 0;
    if (traceFlags != null && traceFlags >= 0 && traceFlags <= 255) {
      return traceFlags;
    }
    // Mark as sampled by default when a valid trace context is present.
    return 1;
  }
}
