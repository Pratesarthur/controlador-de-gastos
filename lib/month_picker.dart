import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

/// Month grid for a whole year, so jumping from December to January is a single tap.
/// Months after [last] are disabled.
Future<DateTime?> showMonthPicker(
  BuildContext context,
  DateTime initial,
  DateTime last,
) => showModalBottomSheet<DateTime>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  barrierColor: Colors.black38,
  useSafeArea: true,
  builder: (_) => _MonthPicker(initial, last),
);

class _MonthPicker extends StatefulWidget {
  final DateTime initial, last;
  const _MonthPicker(this.initial, this.last);
  @override
  State<_MonthPicker> createState() => _MonthPickerState();
}

class _MonthPickerState extends State<_MonthPicker> {
  late int _year = widget.initial.year;

  void _go(int d) {
    final y = _year + d;
    if (y > widget.last.year || y < 2000) return;
    HapticFeedback.selectionClick();
    setState(() => _year = y);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(30),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: Motion.fast,
                      transitionBuilder: (c, a) =>
                          FadeTransition(opacity: a, child: c),
                      layoutBuilder: (cur, prev) => Stack(
                        alignment: Alignment.centerLeft,
                        children: [...prev, ?cur],
                      ),
                      child: Text(
                        '$_year',
                        key: ValueKey(_year),
                        style: T.title.copyWith(fontSize: 22),
                      ),
                    ),
                  ),
                  RoundIcon(Icons.chevron_left_rounded, onTap: () => _go(-1)),
                  const SizedBox(width: 8),
                  AnimatedOpacity(
                    duration: Motion.fast,
                    opacity: _year < widget.last.year ? 1 : 0.35,
                    child: RoundIcon(
                      Icons.chevron_right_rounded,
                      onTap: () => _go(1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.9,
                children: [for (var m = 1; m <= 12; m++) _cell(m, now)],
              ),
              const SizedBox(height: 12),
              Pressable(
                onTap: () {
                  HapticFeedback.selectionClick();
                  final c = DateTime(now.year, now.month);
                  Navigator.of(context)
                      .pop(c.isAfter(widget.last) ? widget.last : c);
                },
                child: Container(
                  height: 46,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: C.bg,
                    borderRadius: BorderRadius.circular(23),
                  ),
                  child: Center(
                    child: Text(
                      'Mês atual',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: C.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell(int m, DateTime now) {
    final d = DateTime(_year, m);
    final enabled = !d.isAfter(widget.last);
    final sel =
        d.year == widget.initial.year && d.month == widget.initial.month;
    final isNow = d.year == now.year && d.month == now.month;
    return Pressable(
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              Navigator.of(context).pop(d);
            }
          : null,
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.curve,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: sel ? C.ink : C.bg,
          borderRadius: BorderRadius.circular(16),
          border: isNow && !sel ? Border.all(color: C.ink, width: 1.2) : null,
        ),
        child: Text(
          monthNames[m - 1].substring(0, 3),
          style: TextStyle(
            fontSize: 14,
            fontWeight: sel || isNow ? FontWeight.w700 : FontWeight.w500,
            color: sel ? C.onInk : (enabled ? C.ink : C.faint),
          ),
        ),
      ),
    );
  }
}
