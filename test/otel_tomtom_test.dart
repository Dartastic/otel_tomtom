// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_tomtom/otel_tomtom.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_tomtom-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('routing records credits + travel_mode + traffic_used', () async {
    await tracedTomtom<String>(
      product: 'routing',
      operation: 'calculate',
      apiVersion: '1',
      invoke: () async => const TomtomCallResult(
        value: 'ok',
        result: TomtomResult(
          itemCount: 2,
          creditsCharged: 10,
          travelMode: 'truck',
          trafficUsed: true,
          tier: 'business',
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('tomtom routing.calculate')!);
    expect(a['tomtom.product'], 'routing');
    expect(a['tomtom.operation'], 'calculate');
    expect(a['tomtom.credits_charged'], 10);
    expect(a['tomtom.travel_mode'], 'truck');
    expect(a['tomtom.traffic_used'], true);
    expect(a['tomtom.tier'], 'business');
  });

  test('suppression skips spans', () async {
    await runWithoutTomtomInstrumentationAsync(() async {
      await tracedTomtom<String>(
        product: 'search',
        invoke: () async => const TomtomCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('tomtom '), isEmpty);
  });
}
