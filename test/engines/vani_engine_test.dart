import 'dart:io';

import 'package:elara_core/elara_core.dart';
import 'package:test/test.dart';

void main() {
  test('Vani is deliberately absent from the default ensemble', () {
    final engines = ElaraFusion().engines;
    expect(engines.map((engine) => engine.name),
        ['OpenCiclo', 'Flowlytics', 'drip']);
    expect(
        engines.where((engine) => engine.isActive).map((engine) => engine.name),
        ['OpenCiclo', 'Flowlytics']);
  });

  test('the inspected methods and reversed-weight issue are documented', () {
    final explanation =
        File('lib/src/engines/vani_engine.dart').readAsStringSync();
    expect(explanation, contains('weighted mean'));
    expect(explanation, contains('older'));
    expect(explanation, contains('skipped'));
  });
}
