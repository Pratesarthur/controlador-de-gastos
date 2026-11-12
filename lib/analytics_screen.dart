import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data.dart';
import 'theme.dart';
import 'widgets.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _r = 1;

  @override
  Widget build(BuildContext context) {
    final spec = ranges[_r];
    return ScreenList(
      title: 'Analytics',
      subtitle: 'October vs September',
      children: [
        Reveal(
          index: 1,
          child: SegmentedPill(
              labels: [for (final r in ranges) r.label],
              index: _r,
              onChanged: (i) {
                HapticFeedback.selectionClick();
                setState(() => _r = i);
              }),
        ),
        const SizedBox(height: 14),
        Reveal(
          index: 2,
          child: SoftCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('Revenue', style: T.small),
                const SizedBox(width: 6),
                AnimatedSwitcher(
                  duration: Motion.fast,
                  child: Pill(spec.delta, key: ValueKey(spec.delta), fg: C.green, bg: C.greenBg),
                ),
              ]),
              const SizedBox(height: 6),
              AnimatedAmount(spec.headline, format: compact),
              const SizedBox(height: 2),
              AnimatedSwitcher(
                duration: Motion.base,
                child: Text(spec.sub, key: ValueKey(spec.sub), style: T.small),
              ),
              const SizedBox(height: 14),
              // key by range → bars regrow every time the range changes
              BarChart(key: ValueKey(_r), spec: spec),
              const SizedBox(height: 10),
              const Row(children: [
                _Legend(color: C.track, label: 'Daily', box: true),
                SizedBox(width: 14),
                _Legend(color: C.accent, label: '7-day avg'),
                SizedBox(width: 14),
                _Legend(color: C.faint, label: 'Target \$8k', dashed: true),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        Reveal(index: 3, child: const _CashFlowCard()),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final bool box, dashed;
  const _Legend({required this.color, required this.label, this.box = false, this.dashed = false});
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: box ? 8 : 12,
            height: box ? 8 : 2,
            decoration: BoxDecoration(color: dashed ? Colors.transparent : color, borderRadius: BorderRadius.circular(2)),
            child: dashed ? CustomPaint(painter: _DashPainter(color)) : null),
        const SizedBox(width: 5),
        Text(label, style: T.small.copyWith(fontSize: 10.5)),
      ]);
}

class _DashPainter extends CustomPainter {
  final Color c;
  _DashPainter(this.c);
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = c..strokeWidth = 2;
    canvas.drawLine(Offset.zero, Offset(3, 0), p);
    canvas.drawLine(Offset(7, 0), Offset(s.width, 0), p);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ---------------------------------------------------------------- bar chart

class BarChart extends StatefulWidget {
  final RangeSpec spec;
  const BarChart({super.key, required this.spec});
  @override
  State<BarChart> createState() => _BarChartState();
}

class _BarChartState extends State<BarChart> {
  int? _sel;
  static const double _h = 190, _axis = 32;

  void _pick(double dx, double w) {
    final n = widget.spec.n;
    final i = (dx / (w - _axis) * n).floor().clamp(0, n - 1);
    if (i != _sel) {
      HapticFeedback.selectionClick();
      setState(() => _sel = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final values = spec.values;
    return LayoutBuilder(builder: (context, b) {
      final w = b.maxWidth;
      final plotW = w - _axis;
      final slot = plotW / spec.n;
      final sel = _sel;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _pick(d.localPosition.dx, w),
        onHorizontalDragUpdate: (d) => _pick(d.localPosition.dx, w),
        child: SizedBox(
          height: _h,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1100),
                curve: Curves.linear,
                builder: (_, t, _) => CustomPaint(
                  painter: _ChartPainter(spec: spec, values: values, t: t, sel: sel, axisW: _axis),
                ),
              ),
            ),
            if (sel != null)
              AnimatedPositioned(
                duration: Motion.fast,
                curve: Motion.curve,
                left: (slot * sel + slot / 2 - 48).clamp(0, plotW - 96).toDouble(),
                top: (_h - 18) * (1 - values[sel] / 16000) - 50,
                child: Container(
                  width: 96,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(9)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(spec.axis[min(spec.axis.length - 1, (sel / spec.n * spec.axis.length).floor())],
                        style: const TextStyle(color: Colors.white54, fontSize: 9)),
                    Text('${money(values[sel] / 1000, dec: 1)}k/day',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
          ]),
        ),
      );
    });
  }
}

class _ChartPainter extends CustomPainter {
  final RangeSpec spec;
  final List<double> values;
  final double t, axisW;
  final int? sel;
  _ChartPainter({required this.spec, required this.values, required this.t, required this.sel, required this.axisW});

  static const maxY = 16000.0;

  void _text(Canvas c, String s, Offset o, {Color color = C.faint, double size = 9, bool center = false}) {
    final tp = TextPainter(
        text: TextSpan(text: s, style: TextStyle(color: color, fontSize: size)), textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(c, center ? o - Offset(tp.width / 2, 0) : o);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plotW = size.width - axisW, plotH = size.height - 18;
    final n = values.length, slot = plotW / n;
    final bw = max(2.0, slot * 0.58);
    double y(double v) => plotH * (1 - v / maxY);

    // grid + axis labels
    for (final g in [5000.0, 10000.0, 15000.0]) {
      canvas.drawLine(Offset(0, y(g)), Offset(plotW, y(g)), Paint()..color = const Color(0xFFF1F1F3));
      _text(canvas, '\$${(g / 1000).round()}k', Offset(plotW + 6, y(g) - 5));
    }

    // bars (staggered grow)
    for (var i = 0; i < n; i++) {
      final p = Curves.easeOutCubic.transform(((t * 1.5 - i / n * 0.5)).clamp(0.0, 1.0));
      final isSel = i == sel;
      final h = (plotH - y(values[i])) * p;
      final x = slot * i + (slot - bw) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, plotH - h, bw, h), const Radius.circular(2)),
        Paint()..color = isSel ? C.ink : (sel == null ? C.track : const Color(0xFFE4E4E7)),
      );
    }

    // dashed target
    final ty = y(8000);
    for (double x = 0; x < plotW; x += 8) {
      canvas.drawLine(Offset(x, ty), Offset(min(x + 4, plotW), ty), Paint()..color = C.faint);
    }
    _text(canvas, '\$8k', Offset(plotW + 6, ty - 5), color: C.green);

    // moving average
    if (n >= 14) {
      final avg = spec.movingAvg;
      final path = Path();
      for (var i = 0; i < n; i++) {
        final o = Offset(slot * i + slot / 2, y(avg[i]));
        i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      final lt = ((t - 0.35) / 0.65).clamp(0.0, 1.0);
      final m = path.computeMetrics().first;
      canvas.drawPath(
          m.extractPath(0, m.length * Curves.easeInOut.transform(lt)),
          Paint()
            ..color = C.accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round);
    }

    // x labels
    final k = spec.axis.length;
    for (var i = 0; i < k; i++) {
      final x = k == 1 ? 0.0 : plotW * (i / (k - 1));
      _text(canvas, spec.axis[i], Offset(x.clamp(10, plotW - 10).toDouble(), plotH + 5), center: true);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter o) => o.t != t || o.sel != sel;
}

// ---------------------------------------------------------------- cash flow

class _CashFlowCard extends StatelessWidget {
  const _CashFlowCard();
  @override
  Widget build(BuildContext context) => SoftCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Net cash flow · 8 weeks', style: T.body),
          const SizedBox(height: 14),
          SizedBox(
            height: 90,
            child: Row(children: [
              for (var i = 0; i < cashFlow.length; i++)
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: cashFlow[i].abs() / 8),
                    duration: Duration(milliseconds: 600 + i * 80),
                    curve: Motion.curve,
                    builder: (_, f, _) {
                      final up = cashFlow[i] >= 0;
                      return Column(children: [
                        Expanded(child: Align(alignment: Alignment.bottomCenter, child: up ? _bar(f * 70, C.ink) : null)),
                        Expanded(child: Align(alignment: Alignment.topCenter, child: up ? null : _bar(f * 70, C.accent))),
                      ]);
                    },
                  ),
                ),
            ]),
          ),
        ]),
      );

  Widget _bar(double h, Color c) =>
      Container(width: 14, height: h, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)));
}
