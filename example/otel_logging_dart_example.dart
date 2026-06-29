import 'package:logging/logging.dart';
import 'package:otel_logging_dart/otel_logging_dart.dart';

Future<void> main() async {
  // 1. Configure the exporter. In real apps you might build the config from
  //    environment variables via OtelConfig.fromEnvironment(Platform.environment).
  const config = OtelConfig(
    enabled: true,
    endpoint: 'https://collector.example.com/v1/logs',
    serviceName: 'my-dart-app',
    serviceVersion: '1.4.2',
    environment: 'production',
    globalAttributes: {'team': 'payments'},
  );

  final exporter = OtelLogExporter(
    config: config,
    // Optional: observe transport failures instead of silently dropping them.
    onError: (error, stackTrace) => print('Failed to export log: $error'),
  );

  // 2. Wire it into package:logging.
  Logger.root.level = Level.ALL;
  final subscription = exporter.attachToLogger(Logger.root);

  final log = Logger('orders');

  // 3. Log as usual. Pass a Map as the message object to attach attributes,
  //    including trace correlation via the reserved trace_id / span_id keys.
  log.info({
    'message': 'order processed',
    'order_id': 1234,
    'amount': 49.99,
    'trace_id': '0af7651916cd43dd8448eb211c80319c',
    'span_id': 'b7ad6b7169203331',
  });

  // 4. Errors are expanded into exception.* attributes automatically.
  try {
    throw StateError('payment gateway timed out');
  } catch (error, stackTrace) {
    log.severe('payment failed', error, stackTrace);
  }

  // 5. You can also emit a fully-formed record without package:logging.
  await exporter.emit(
    OtelLogRecord(
      severityNumber: SeverityMapper.severityWarn,
      severityText: 'warn',
      body: 'cache miss',
      attributes: {'key': 'user:42'},
    ),
  );

  // Allow the async listener to drain, then clean up.
  await Future<void>.delayed(const Duration(milliseconds: 50));
  await subscription.cancel();
  exporter.close();
}
