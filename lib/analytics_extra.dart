import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'overview_screen.dart' show DonutPainter, MonthBar;
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

String _monthTag(DateTime m) => '${monthShort[m.month - 1]} ${(m.year % 100).toString().padLeft(2, '0')}';

/// Compact money for axes/labels: 1,2k · 3,4M.
String _k(double v) {
  if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1).replaceAll('.', ',')}M';
  if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(v >= 1e4 ? 0 : 1).replaceAll('.', ',')}k';
  return v.toStringAsFixed(0);
}

Widget _divider() => Divider(height: 1, thickness: 1, color: C.track);

// ======================================================================= Parcelas

/// Análises ▸ Parcelas: what is still owed, the monthly commitment horizon and each plan.
class InstallmentsTab extends StatefulWidget {
  const InstallmentsTab({super.key});
  @override
  State<InstallmentsTab> createState() => _InstallmentsTabState();
}

class _InstallmentsTabState extends State<InstallmentsTab> {
  int _filter = 0; // 0 ativos · 1 encerrados

  @override
  Widget build(BuildContext context) {
    final s = Store.i;
    final plans = s.plans;
    final active = plans.where((p) => p.active).toList();
    final done = plans.where((p) => !p.active).toList();
    final horizon = s.installmentHorizon();
    final total = active.fold(0.0, (a, p) => a + p.total);
    final paid = active.fold(0.0, (a, p) => a + p.paid);
    final left = total - paid;
    final remainingCount = active.fold(0, (a, p) => a + (p.count - p.paidCount));
    final thisMonth = horizon.isEmpty ? 0.0 : horizon.first.$2;
    final nextMonth = horizon.length > 1 ? horizon[1].$2 : 0.0;
    final avg = remainingCount == 0 ? 0.0 : left / remainingCount;
    final income = s.monthlyTotals(1).first.$2;
    final pct = income == 0 ? null : thisMonth / income * 100;
    final shown = _filter == 0 ? active : done;

    Widget line(IconData icon, String label, double v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 16, color: C.ink),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: T.body.copyWith(fontSize: 13.5, fontWeight: FontWeight.w500))),
            Text(brl(v), style: T.body),
          ]),
        );

    return Column(children: [
      Reveal(
        index: 1,
        child: SoftCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Falta pagar', style: T.small),
            const SizedBox(height: 4),
            AnimatedAmount(left, format: brl, style: T.big.copyWith(fontSize: 32)),
            const SizedBox(height: 2),
            Text(
              '${active.length} ${active.length == 1 ? 'parcelamento ativo' : 'parcelamentos ativos'} · $remainingCount ${remainingCount == 1 ? 'parcela restante' : 'parcelas restantes'}'
              '${pct == null ? '' : ' · ${pct.toStringAsFixed(1).replaceAll('.', ',')}% da renda do mês'}',
              style: T.small,
            ),
            const SizedBox(height: 14),
            ProgressBar(total == 0 ? 0 : paid / total, C.green, height: 8),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: Text('Já pago ${brl(paid)}', style: T.small)),
              Text('Total ${brl(total)}', style: T.small),
            ]),
            const SizedBox(height: 6),
            line(Icons.calendar_today_rounded, 'Este mês', thisMonth),
            _divider(),
            line(Icons.event_rounded, 'Próximo mês', nextMonth),
            _divider(),
            line(Icons.paid_outlined, 'Parcela média', avg),
          ]),
        ),
      ),
      const SizedBox(height: 14),
      Reveal(
        index: 2,
        child: SoftCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Compromisso mensal', style: T.body),
            const SizedBox(height: 2),
            Text('Quanto das parcelas cai em cada mês, até a última acabar', style: T.small),
            const SizedBox(height: 14),
            if (horizon.isEmpty)
              Padding(padding: EdgeInsets.all(20), child: Center(child: Text('Nenhuma parcela futura', style: T.sub)))
            else
              _HorizonChart(horizon),
          ]),
        ),
      ),
      const SizedBox(height: 14),
      Reveal(
        index: 3,
        child: SoftCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Parcelamentos', style: T.body),
            const SizedBox(height: 10),
            SegmentedPill(
                labels: ['Ativos (${active.length})', 'Encerrados (${done.length})'],
                index: _filter,
                onChanged: (i) => setState(() => _filter = i)),
            const SizedBox(height: 6),
            if (shown.isEmpty)
              Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(child: Text(_filter == 0 ? 'Nenhum parcelamento ativo' : 'Nenhum parcelamento encerrado', style: T.sub))),
            for (final (i, p) in shown.indexed) ...[
              if (i > 0) _divider(),
              _PlanRow(p),
            ],
          ]),
        ),
      ),
    ]);
  }
}

class _PlanRow extends StatelessWidget {
  final Plan p;
  const _PlanRow(this.p);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(children: [
          Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(12)),
              child: Icon(p.category.icon, size: 18, color: C.ink),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.title, style: T.body.copyWith(fontSize: 13.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${brl(p.perInstallment)} × ${p.count} · ${p.source}', style: T.small, maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(p.active ? brl(p.remaining) : brl(p.total), style: T.body.copyWith(fontSize: 13.5)),
              Text(p.active ? 'falta' : 'quitado', style: T.small),
            ]),
          ]),
          const SizedBox(height: 8),
          ProgressBar(p.count == 0 ? 0 : p.paidCount / p.count, p.active ? C.ink : C.green, height: 5),
          const SizedBox(height: 5),
          Row(children: [
            Expanded(child: Text('${p.paidCount} de ${p.count} pagas', style: T.small.copyWith(fontSize: 10.5))),
            Text(p.active ? 'termina em ${_monthTag(p.last)}' : 'encerrou em ${_monthTag(p.last)}',
                style: T.small.copyWith(fontSize: 10.5)),
          ]),
        ]),
      );
}

/// Bars of the monthly installment commitment; scrolls sideways when the horizon is long.
class _HorizonChart extends StatefulWidget {
  final List<(DateTime, double)> data;
  const _HorizonChart(this.data);
  @override
  State<_HorizonChart> createState() => _HorizonChartState();
}

class _HorizonChartState extends State<_HorizonChart> {
  int? _sel;
  static const double _h = 130, _slot = 34;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final top = max(1.0, data.map((e) => e.$2).reduce(max));
    final sel = _sel;
    return LayoutBuilder(builder: (context, b) {
      final width = max(b.maxWidth, data.length * _slot);
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          height: 18,
          child: sel == null
              ? Text('Toque em uma barra para ver o valor', style: T.small.copyWith(fontSize: 10.5))
              : Text('${_monthTag(data[sel].$1)}: ${brl(data[sel].$2)}', style: T.small.copyWith(color: C.ink, fontWeight: FontWeight.w600)),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: SizedBox(
            width: width,
            height: _h + 24,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var i = 0; i < data.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _sel = _sel == i ? null : i);
                    },
                    child: AnimatedOpacity(
                      duration: Motion.fast,
                      opacity: sel == null || sel == i ? 1 : 0.4,
                      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: Duration(milliseconds: 500 + min(i, 12) * 60),
                          curve: Curves.easeOutCubic,
                          builder: (_, t, _) => Container(
                            width: 16,
                            height: max(2, data[i].$2 / top * _h * t),
                            decoration: BoxDecoration(color: C.blue, borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(_monthTag(data[i].$1), style: T.small.copyWith(fontSize: 9.5), maxLines: 1),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: C.blue, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 5),
          Text('Parcelas · pico ${brl(top, dec: 0)}', style: T.small.copyWith(fontSize: 10.5)),
        ]),
      ]);
    });
  }
}

// ======================================================================= Categorias

/// Análises ▸ Categorias: spending / income per category (donut + ranking), then the 6-month evolution.
class CategoriesTab extends StatefulWidget {
  const CategoriesTab({super.key});
  @override
  State<CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<CategoriesTab> {
  int _kind = 0; // 0 gastos · 1 receitas
  int _level = 0; // 0 categorias · 1 subcategorias
  int? _sel;
  int _evoKind = 0;
  static const double _size = 190;

  Kind get _k => _kind == 0 ? Kind.expense : Kind.income;

  void _pickAt(Offset p, List<double> values) {
    final total = values.fold(0.0, (a, b) => a + b);
    const c = Offset(_size / 2, _size / 2);
    final d = p - c;
    final r = d.distance;
    if (total == 0 || r < _size * 0.28 || r > _size / 2 + 6) {
      setState(() => _sel = null);
      return;
    }
    var a = atan2(d.dy, d.dx) + pi / 2;
    if (a < 0) a += 2 * pi;
    var acc = 0.0;
    for (var i = 0; i < values.length; i++) {
      acc += values[i] / total * 2 * pi;
      if (a <= acc) {
        HapticFeedback.selectionClick();
        setState(() => _sel = _sel == i ? null : i);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Store.i;
    // rows: name, icon, color, value
    final rows = _level == 0
        ? [for (final c in s.catTotals(s.month, _k)) (c.$1.name, c.$1.icon, c.$1.color, c.$2)]
        : [
            for (final c in s.subTotals(s.month, _k))
              (c.$2 == null ? '${c.$1.name} (geral)' : c.$2!.name, c.$1.icon, c.$1.color, c.$3)
          ];
    final total = rows.fold(0.0, (a, r) => a + r.$4);
    final sel = (_sel != null && _sel! < rows.length) ? _sel : null;
    final noun = _kind == 0 ? 'gastos' : 'receitas';

    return Column(children: [
      Reveal(index: 1, child: MonthBar(s)),
      const SizedBox(height: 14),
      Reveal(
        index: 2,
        child: SoftCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_kind == 0 ? 'Gastos por categoria' : 'Renda por categoria', style: T.body),
            const SizedBox(height: 10),
            SegmentedPill(
                labels: const ['Gastos', 'Receitas'],
                index: _kind,
                onChanged: (i) => setState(() {
                      _kind = i;
                      _sel = null;
                    })),
            const SizedBox(height: 8),
            UnderlineTabs(
                labels: const ['Categorias', 'Subcategorias'],
                index: _level,
                onChanged: (i) => setState(() {
                      _level = i;
                      _sel = null;
                    })),
            const SizedBox(height: 16),
            if (rows.isEmpty)
              Padding(
                  padding: const EdgeInsets.all(24), child: Center(child: Text('Sem $noun em ${monthNames[s.month.month - 1].toLowerCase()}', style: T.sub)))
            else ...[
              Center(
                child: GestureDetector(
                  onTapDown: (d) => _pickAt(d.localPosition, [for (final r in rows) r.$4]),
                  child: SizedBox(
                    width: _size,
                    height: _size,
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey('$_kind$_level${s.month}${total.round()}'),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.easeInOutCubic,
                      builder: (_, t, _) => CustomPaint(
                        painter: DonutPainter([for (final r in rows) (r.$4, r.$3)], t, sel),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 36),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                Text(sel == null ? 'Total' : rows[sel].$1, style: T.small, maxLines: 1),
                                Text(brl(sel == null ? total : rows[sel].$4, dec: 0), style: T.big.copyWith(fontSize: 21)),
                              ]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              for (final (i, r) in rows.indexed) ...[
                _divider(),
                Pressable(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _sel = _sel == i ? null : i);
                  },
                  child: AnimatedContainer(
                    duration: Motion.fast,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    color: sel == i ? C.bg : Colors.transparent,
                    child: Row(children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(color: r.$3, borderRadius: BorderRadius.circular(12)),
                        child: Icon(r.$2, size: 18, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(r.$1, style: T.body.copyWith(fontSize: 13.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('${(r.$4 / total * 100).toStringAsFixed(2).replaceAll('.', ',')}%', style: T.small),
                        ]),
                      ),
                      Text(brl(r.$4), style: T.body.copyWith(fontSize: 13.5)),
                    ]),
                  ),
                ),
              ],
            ],
          ]),
        ),
      ),
      const SizedBox(height: 14),
      Reveal(index: 3, child: _evolution(s)),
    ]);
  }

  // ---- evolution: stacked bars for the last 6 months

  Widget _evolution(Store s) {
    final kind = _evoKind == 0 ? Kind.expense : Kind.income;
    final months = s.monthlyByCategory(6, kind);
    final totals = <String, double>{};
    for (final m in months) {
      m.$2.forEach((k, v) => totals[k] = (totals[k] ?? 0) + v);
    }
    final order = totals.keys.toList()..sort((a, b) => totals[b]!.compareTo(totals[a]!));
    final topIds = order.take(5).toList();
    final hasOthers = order.length > 5;
    final grand = totals.values.fold(0.0, (a, b) => a + b);
    const othersColor = Color(0xFF8A8A8F);

    // per month: segments bottom→top
    List<(Color, double)> segs(Map<String, double> m) {
      var others = 0.0;
      final out = <(Color, double)>[];
      for (final id in topIds) {
        out.add((categoryById(id).color, m[id] ?? 0));
      }
      for (final e in m.entries) {
        if (!topIds.contains(e.key)) others += e.value;
      }
      if (hasOthers) out.add((othersColor, others));
      return out;
    }

    // trend: last month vs. the previous one
    double? trend(String id) {
      final a = months[months.length - 1].$2[id] ?? 0, b = months[months.length - 2].$2[id] ?? 0;
      if (b == 0) return null;
      return (a - b) / b * 100;
    }

    final bars = [for (final m in months) (m.$1, segs(m.$2))];
    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Evolução por categoria', style: T.body),
        const SizedBox(height: 2),
        Text('Últimos 6 meses, independente do período', style: T.small),
        const SizedBox(height: 12),
        SegmentedPill(labels: const ['Gastos', 'Receitas'], index: _evoKind, onChanged: (i) => setState(() => _evoKind = i)),
        const SizedBox(height: 14),
        if (grand == 0)
          Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Sem dados nos últimos 6 meses', style: T.sub)))
        else ...[
          _StackedBars(key: ValueKey(_evoKind), bars: bars),
          const SizedBox(height: 12),
          Wrap(spacing: 14, runSpacing: 6, children: [
            for (final id in topIds) _dot(categoryById(id).color, categoryById(id).name),
            if (hasOthers) _dot(othersColor, 'Outras'),
          ]),
          const SizedBox(height: 6),
          for (final id in order) ...[
            _divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: categoryById(id).color, borderRadius: BorderRadius.circular(12)),
                  child: Icon(categoryById(id).icon, size: 18, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(categoryById(id).name, style: T.body.copyWith(fontSize: 13.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('média mensal ${brl(totals[id]! / 6)} · ${(totals[id]! / grand * 100).toStringAsFixed(1).replaceAll('.', ',')}%',
                        style: T.small, maxLines: 2),
                  ]),
                ),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(brl(totals[id]!), style: T.body.copyWith(fontSize: 13.5)),
                  _TrendPill(trend(id), upIsBad: kind == Kind.expense),
                ]),
              ]),
            ),
          ],
        ],
      ]),
    );
  }

  Widget _dot(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(label, style: T.small.copyWith(fontSize: 11)),
      ]);
}

class _TrendPill extends StatelessWidget {
  final double? pct;
  final bool upIsBad;
  const _TrendPill(this.pct, {required this.upIsBad});
  @override
  Widget build(BuildContext context) {
    final p = pct;
    if (p == null) return const SizedBox(height: 18);
    final up = p >= 0;
    final good = up != upIsBad;
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Pill('${up ? '↗' : '↘'} ${p.abs().toStringAsFixed(1).replaceAll('.', ',')}%',
          fg: good ? C.green : C.accent, bg: good ? C.greenBg : C.accentBg),
    );
  }
}

class _StackedBars extends StatefulWidget {
  final List<(DateTime, List<(Color, double)>)> bars;
  const _StackedBars({super.key, required this.bars});
  @override
  State<_StackedBars> createState() => _StackedBarsState();
}

class _StackedBarsState extends State<_StackedBars> {
  int? _sel;
  static const double _h = 150;

  @override
  Widget build(BuildContext context) {
    final bars = widget.bars;
    final sums = [for (final b in bars) b.$2.fold(0.0, (a, e) => a + e.$2)];
    final top = max(1.0, sums.reduce(max));
    final sel = _sel;
    return Column(children: [
      SizedBox(
        height: 18,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(sel == null ? 'Toque em um mês para ver o total' : '${_monthTag(bars[sel].$1)}: ${brl(sums[sel])}',
              style: T.small.copyWith(color: sel == null ? C.muted : C.ink, fontWeight: sel == null ? FontWeight.w400 : FontWeight.w600)),
        ),
      ),
      SizedBox(
        height: _h + 24,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < bars.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _sel = _sel == i ? null : i);
                },
                child: AnimatedOpacity(
                  duration: Motion.fast,
                  opacity: sel == null || sel == i ? 1 : 0.4,
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 600 + i * 80),
                      curve: Curves.easeOutCubic,
                      builder: (_, t, _) => ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: SizedBox(
                          width: 30,
                          height: max(2, sums[i] / top * _h * t),
                          child: Column(verticalDirection: VerticalDirection.up, children: [
                            for (final seg in bars[i].$2)
                              if (seg.$2 > 0) Expanded(flex: max(1, (seg.$2 * 100).round()), child: Container(color: seg.$1)),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(_monthTag(bars[i].$1), style: T.small.copyWith(fontSize: 10), maxLines: 1),
                  ]),
                ),
              ),
            ),
        ]),
      ),
      Align(alignment: Alignment.centerLeft, child: Text('Máximo ${_k(top)}', style: T.small.copyWith(fontSize: 10, color: C.faint))),
    ]);
  }
}
