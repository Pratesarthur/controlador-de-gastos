import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'overview_screen.dart' show MonthBar;
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

/// Análises: income vs expenses over the last months, savings rate and top categories.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _r = 0;
  static const _spans = [3, 6];

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) {
          final s = Store.i;
          final n = _spans[_r];
          final data = s.monthlyTotals(n);
          final inc = data.fold(0.0, (a, e) => a + e.$2);
          final exp = data.fold(0.0, (a, e) => a + e.$3);
          final saved = inc - exp;
          final rate = inc == 0 ? 0.0 : saved / inc * 100;
          final cats = s.byCategory;
          final catTotal = s.expense;
          return ScreenList(
            title: 'Análises',
            subtitle: 'Últimos $n meses',
            children: [
              Reveal(
                index: 1,
                child: SegmentedPill(
                    labels: const ['3 meses', '6 meses'],
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
                      const Text('Economia no período', style: T.small),
                      const SizedBox(width: 6),
                      Pill('${rate.toStringAsFixed(0)}% da renda',
                          fg: saved >= 0 ? C.green : C.accent,
                          bg: saved >= 0 ? C.greenBg : const Color(0xFFFFEEE6)),
                    ]),
                    const SizedBox(height: 6),
                    AnimatedAmount(saved, format: brl),
                    const SizedBox(height: 2),
                    Text('${brl(inc, dec: 0)} recebidos · ${brl(exp, dec: 0)} gastos', style: T.small),
                    const SizedBox(height: 16),
                    _MonthlyBars(key: ValueKey(n), data: data),
                    const SizedBox(height: 10),
                    const Row(children: [
                      _Legend(color: C.green, label: 'Receitas'),
                      SizedBox(width: 14),
                      _Legend(color: C.accent, label: 'Despesas'),
                    ]),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
              const SizedBox(height: 18),
              Reveal(index: 3, child: MonthBar(s)),
              const SizedBox(height: 14),
              Reveal(index: 4, child: _SummaryTiles(s, cats)),
              const SizedBox(height: 14),
              Reveal(
                index: 5,
                child: SoftCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Gasto por categoria', style: T.body),
                    const SizedBox(height: 4),
                    Text('${monthNames[s.month.month - 1]} · total ${brl(catTotal)}', style: T.small),
                    const SizedBox(height: 10),
                    if (cats.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('Sem despesas neste mês', style: T.sub)),
                    for (final c in cats)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(children: [
                          Row(children: [
                            Icon(c.$1.icon, size: 16, color: C.ink),
                            const SizedBox(width: 8),
                            Expanded(child: Text(c.$1.name, style: T.body.copyWith(fontSize: 13))),
                            Text(brl(c.$2), style: T.body.copyWith(fontSize: 13)),
                            SizedBox(
                              width: 44,
                              child: Text('${(c.$2 / catTotal * 100).toStringAsFixed(0)}%',
                                  textAlign: TextAlign.right, style: T.small),
                            ),
                          ]),
                          const SizedBox(height: 6),
                          _Bar(c.$2 / catTotal, c.$1.color),
                        ]),
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
              Reveal(index: 6, child: _SourceCard(s)),
              const SizedBox(height: 14),
              Reveal(
                index: 7,
                child: SoftCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Maiores despesas do mês', style: T.body),
                    const SizedBox(height: 10),
                    if (s.topExpenses(5).isEmpty) const Text('Sem despesas neste mês', style: T.sub),
                    for (final (i, t) in s.topExpenses(5).indexed)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          SizedBox(width: 22, child: Text('${i + 1}º', style: T.small.copyWith(fontWeight: FontWeight.w700))),
                          Icon(t.category.icon, size: 16, color: C.ink),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(t.title, style: T.body.copyWith(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text('${t.category.name} · ${dayLabel(t.date)}${t.isInstallment ? ' · ${t.inst}/${t.instTotal}' : ''}',
                                  style: T.small),
                            ]),
                          ),
                          Text(brl(t.amount), style: T.body.copyWith(fontSize: 13)),
                        ]),
                      ),
                  ]),
                ),
              ),
            ],
          );
        },
      );
}

class _SummaryTiles extends StatelessWidget {
  final Store s;
  final List<(Category, double)> cats;
  const _SummaryTiles(this.s, this.cats);

  Widget _tile(String label, String value, String sub) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: T.small.copyWith(fontSize: 10.5)),
            const SizedBox(height: 4),
            Text(value, style: T.body.copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(sub, style: T.small.copyWith(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = s.isCurrentMonth ? now.day : DateTime(s.month.year, s.month.month + 1, 0).day;
    final avg = s.expense / days;
    final top = cats.isEmpty ? null : cats.first;
    return Row(children: [
      _tile('Média por dia', brl(avg, dec: 0), 'em $days dias'),
      const SizedBox(width: 8),
      _tile('Maior categoria', top?.$1.name ?? '—', top == null ? 'sem gastos' : brl(top.$2, dec: 0)),
      const SizedBox(width: 8),
      _tile('Parcelas futuras', brl(s.futureInstallments, dec: 0), 'a pagar'),
    ]);
  }
}

/// Account vs credit card: how the month's spending was paid, and per-source breakdown.
class _SourceCard extends StatelessWidget {
  final Store s;
  const _SourceCard(this.s);

  @override
  Widget build(BuildContext context) {
    final (acc, card) = s.accountVsCard;
    final total = acc + card;
    final accPct = total == 0 ? 0.0 : acc / total;
    final src = s.bySource;
    Widget legend(String label, double v, double pct, Color c, IconData icon) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 14, color: c),
              const SizedBox(width: 5),
              Text(label, style: T.small),
            ]),
            const SizedBox(height: 3),
            Text(brl(v), style: T.body.copyWith(fontSize: 15)),
            Text('${(pct * 100).toStringAsFixed(0)}% dos gastos', style: T.small),
          ]),
        );
    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Conta x cartão de crédito', style: T.body),
        const SizedBox(height: 4),
        Text('De onde saiu o dinheiro em ${monthNames[s.month.month - 1].toLowerCase()}', style: T.small),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: total == 0
                ? Container(color: C.track)
                : TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: accPct),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => Row(children: [
                      Expanded(flex: (v * 1000).round().clamp(0, 1000), child: Container(color: C.ink)),
                      const SizedBox(width: 2),
                      Expanded(flex: ((1 - v) * 1000).round().clamp(0, 1000), child: Container(color: C.accent)),
                    ]),
                  ),
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          legend('Conta', acc, accPct, C.ink, Icons.account_balance_outlined),
          legend('Cartão', card, total == 0 ? 0 : 1 - accPct, C.accent, Icons.credit_card_rounded),
        ]),
        if (total > 0) ...[
          const SizedBox(height: 12),
          Text(
            card > acc
                ? 'Você gastou ${brl(card - acc)} a mais no cartão do que na conta.'
                : card < acc
                    ? 'Você gastou ${brl(acc - card)} a mais na conta do que no cartão.'
                    : 'Gastos iguais entre conta e cartão.',
            style: T.small.copyWith(color: C.ink, fontWeight: FontWeight.w600),
          ),
        ],
        if (src.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('Por conta e cartão', style: T.small),
          const SizedBox(height: 6),
          for (final e in src)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Icon(e.$2 ? Icons.credit_card_rounded : Icons.account_balance_outlined, size: 15, color: C.ink),
                const SizedBox(width: 8),
                Expanded(child: Text(e.$1, style: T.body.copyWith(fontSize: 13))),
                Text(brl(e.$3), style: T.body.copyWith(fontSize: 13)),
              ]),
            ),
        ],
      ]),
    );
  }
}

class _Bar extends StatelessWidget {
  final double value;
  final Color color;
  const _Bar(this.value, this.color);
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Container(
          height: 5,
          color: C.track,
          alignment: Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => FractionallySizedBox(
                widthFactor: v, child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)))),
          ),
        ),
      );
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 5),
        Text(label, style: T.small.copyWith(fontSize: 10.5)),
      ]);
}

/// Paired income/expense bars per month. Tap a month to see its values.
class _MonthlyBars extends StatefulWidget {
  final List<(DateTime, double, double)> data;
  const _MonthlyBars({super.key, required this.data});
  @override
  State<_MonthlyBars> createState() => _MonthlyBarsState();
}

class _MonthlyBarsState extends State<_MonthlyBars> {
  int? _sel;
  static const double _h = 130;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final top = max(1.0, data.map((e) => max(e.$2, e.$3)).reduce(max));
    final sel = _sel;
    return Column(children: [
      SizedBox(
        height: 16,
        child: sel == null
            ? null
            : Align(
                alignment: Alignment.centerLeft,
                child: Text(
                    '${monthShort[data[sel].$1.month - 1]}: +${brl(data[sel].$2, dec: 0)} · −${brl(data[sel].$3, dec: 0)}',
                    style: T.small.copyWith(color: C.ink, fontWeight: FontWeight.w600)),
              ),
      ),
      SizedBox(
        height: _h + 20,
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
                      duration: Duration(milliseconds: 600 + i * 80),
                      curve: Curves.easeOutCubic,
                      builder: (_, t, _) => Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                        _col(data[i].$2 / top * _h * t, C.green),
                        const SizedBox(width: 3),
                        _col(data[i].$3 / top * _h * t, C.accent),
                      ]),
                    ),
                    const SizedBox(height: 6),
                    Text(monthShort[data[i].$1.month - 1], style: T.small.copyWith(fontSize: 10.5)),
                  ]),
                ),
              ),
            ),
        ]),
      ),
    ]);
  }

  Widget _col(double h, Color c) => Container(
      width: 10, height: max(2, h), decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)));
}
