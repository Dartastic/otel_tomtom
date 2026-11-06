// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_tomtom/otel_tomtom.dart';

/// Traces TomTom Maps calls with OpenTelemetry.
///
/// `otel_tomtom` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each TomTom Maps call in
/// [tracedTomtom]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'tomtom-example');

  // Wraps a TomTom Maps API call in a CLIENT span.
  final tomtomId = await tracedTomtom<String>(
    product: 'search',
    apiVersion: '1',
    invoke: () async {
      // Make the TomTom Maps call here, then report what it returned.
      const id = 'tomtom_8f3a2c';
      return const TomtomCallResult(
          value: id,
          result: TomtomResult(
              itemCount: 3,
              creditsCharged: 1,
              travelMode: 'car',
              trafficUsed: true,
              tier: 'essential',
              requestId: 'Tracking-ID',
              statusCode: 200));
    },
  );
  OTelLog.info('tracedTomtom returned $tomtomId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutTomtomInstrumentationAsync.
  await runWithoutTomtomInstrumentationAsync(
    () => tracedTomtom<String>(
      product: 'search',
      apiVersion: '1',
      invoke: () async {
        const id = 'tomtom_8f3a2c';
        return const TomtomCallResult(
            value: id,
            result: TomtomResult(
                itemCount: 3,
                creditsCharged: 1,
                travelMode: 'car',
                trafficUsed: true,
                tier: 'essential',
                requestId: 'Tracking-ID',
                statusCode: 200));
      },
    ),
  );

  await OTel.shutdown();
}
