/// Send Dart application logs to an OpenTelemetry collector over OTLP/HTTP.
///
/// Integrates with `package:logging` and properly formats log attributes,
/// severities, and distributed-tracing context (trace/span ids) according to
/// the OpenTelemetry logs data model.
library;

export 'src/attribute_formatter.dart';
export 'src/log_payload_builder.dart';
export 'src/otel_config.dart';
export 'src/otel_log_exporter.dart';
export 'src/otel_log_record.dart';
export 'src/severity_mapper.dart';
