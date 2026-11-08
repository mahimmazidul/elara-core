import 'package:elara_core/elara_core.dart';

DateTime day(DateTime start, int offset) =>
    DateTime.utc(start.year, start.month, start.day + offset);

List<CycleRecord> historyFor(List<int> lengths, {DateTime? first}) {
  final starts = <CycleRecord>[
    CycleRecord(startDate: first ?? DateTime.utc(2025, 1, 1)),
  ];
  for (final length in lengths) {
    starts.add(CycleRecord(startDate: day(starts.last.startDate, length)));
  }
  return starts;
}
