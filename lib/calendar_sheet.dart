import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

const _weekdays = [
  'Domingo',
  'Segunda-feira',
  'Terça-feira',
  'Quarta-feira',
  'Quinta-feira',
  'Sexta-feira',
  'Sábado',
];

/// Calendar bottom sheet: a blue selection bubble glides between days, months cross-fade.
Future<DateTime?> showCalendarSheet(BuildContext context, DateTime initial) =>
    showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black38,
      useSafeArea: true,
      builder: (_) => _CalendarSheet(initial),
    );

class _CalendarSheet extends StatefulWidget {
  final DateTime initial;
  const _CalendarSheet(this.initial);
  @override
  State<_CalendarSheet> createState() => _CalendarSheetState();
}

class _CalendarSheetState extends State<_CalendarSheet> {
  late DateTime _sel = DateTime(
    widget.initial.year,
    widget.initial.month,
    widget.initial.day,
  );
  late DateTime _shown = DateTime(widget.initial.year, widget.initial.month);
  static const double _rowH = 48, _bubble = 40;

  void _go(int d) {
    HapticFeedback.selectionClick();
    setState(() => _shown = DateTime(_shown.year, _shown.month + d));
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final lead =
        DateTime(_shown.year, _shown.month, 1).weekday % 7; // Sunday first
    final days = DateTime(_shown.year, _shown.month + 1, 0).day;
    final rows = ((lead + days) / 7).ceil();
    final selVisible = _sel.year == _shown.year && _sel.month == _shown.month;
    final selIdx = lead + _sel.day - 1;

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
                        '${monthNames[_shown.month - 1]} ${_shown.year}',
                        key: ValueKey(_shown),
                        style: T.title.copyWith(fontSize: 20),
                      ),
                    ),
                  ),
                  RoundIcon(Icons.chevron_left_rounded, onTap: () => _go(-1)),
                  const SizedBox(width: 8),
                  RoundIcon(Icons.chevron_right_rounded, onTap: () => _go(1)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (final w in const ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'])
                    Expanded(
                      child: Center(
                        child: Text(
                          w,
                          style: T.small.copyWith(
                            color: C.faint,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (context, b) {
                  final cw = b.maxWidth / 7;
                  return AnimatedContainer(
                    duration: Motion.fast,
                    curve: Motion.curve,
                    height: rows * _rowH,
                    child: Stack(
                      children: [
                        // the gliding selection bubble
                        AnimatedPositioned(
                          duration: Motion.fast,
                          curve: Curves.easeOutBack,
                          left: (selIdx % 7) * cw + (cw - _bubble) / 2,
                          top: (selIdx ~/ 7) * _rowH + (_rowH - _bubble) / 2,
                          width: _bubble,
                          height: _bubble,
                          child: AnimatedOpacity(
                            duration: Motion.fast,
                            opacity: selVisible ? 1 : 0,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [C.blueLight, C.blue],
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x552F6BFF),
                                    blurRadius: 14,
                                    offset: Offset(0, 5),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: Motion.fast,
                          transitionBuilder: (c, a) =>
                              FadeTransition(opacity: a, child: c),
                          layoutBuilder: (cur, prev) =>
                              Stack(children: [...prev, ?cur]),
                          child: Column(
                            key: ValueKey(_shown),
                            children: [
                              for (var r = 0; r < rows; r++)
                                SizedBox(
                                  height: _rowH,
                                  child: Row(
                                    children: [
                                      for (var c = 0; c < 7; c++)
                                        _cell(
                                          r * 7 + c - lead + 1,
                                          days,
                                          today,
                                          selVisible,
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: C.bg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: C.ink,
                    ),
                    const SizedBox(width: 10),
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
                          '${_weekdays[_sel.weekday % 7]}, ${_sel.day} de ${monthNames[_sel.month - 1].toLowerCase()}',
                          key: ValueKey(_sel),
                          style: T.body.copyWith(fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Pressable(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.of(context).pop(_sel);
                },
                child: Container(
                  height: 50,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: C.ink,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Center(
                    child: Text(
                      'Confirmar',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
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

  Widget _cell(int day, int days, DateTime today, bool selVisible) {
    if (day < 1 || day > days) return const Expanded(child: SizedBox());
    final d = DateTime(_shown.year, _shown.month, day);
    final isSel = selVisible && d == _sel;
    final isToday =
        d.year == today.year && d.month == today.month && d.day == today.day;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _sel = d);
        },
        child: Center(
          child: Container(
            width: _bubble,
            height: _bubble,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isToday && !isSel ? C.track : Colors.transparent,
            ),
            child: AnimatedDefaultTextStyle(
              duration: Motion.fast,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSel || isToday
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: isSel ? Colors.white : C.ink,
              ),
              child: Text('$day'),
            ),
          ),
        ),
      ),
    );
  }
}
