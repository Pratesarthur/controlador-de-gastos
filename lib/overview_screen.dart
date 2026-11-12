import 'dart:math';
import 'package:flutter/material.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

/// Home ("Início"): month selector, balance, budget, category donut,
/// upcoming bills and recent transactions.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) {
          final s = Store.i;
          final items = s.monthItems;
          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 130),
            children: [
              Reveal(child: _MonthBar(s)),
              const SizedBox(height: 16),
              Reveal(index: 1, child: _BalanceCard(s)),
              const SizedBox(height: 14),
              Reveal(index: 2, child: _CategoryCard(s)),
              const SizedBox(height: 14),
              Reveal(index: 3, child: const _BillsCard()),
              const SizedBox(height: 22),
              Reveal(
                index: 4,
                child: Row(children: [
                  const Expanded(child: Text('Últimas transações', style: T.body)),
                  Text('Ver todas ▸', style: T.small.copyWith(color: C.ink, fontWeight: FontWeight.w600)),
                ]),
              ),
              const SizedBox(height: 10),
              AnimatedSize(
                duration: Motion.base,
                curve: Motion.curve,
                alignment: Alignment.topCenter,
                child: Column(children: [
                  for (var i = 0; i < min(items.length, 6); i++)
                    Reveal(
                      key: ValueKey('${s.month.month}-${items[i].id}'),
                      index: 5 + i,
                      child: Padding(padding: const EdgeInsets.only(bottom: 8), child: TxnRow(items[i])),
                    ),
                  if (items.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: Text('Nenhuma transação neste mês', style: T.sub))),
                ]),
              ),
            ],
          );
        },
      );
}

// ---------------------------------------------------------------- month bar

class _MonthBar extends StatelessWidget {
  final Store s;
  const _MonthBar(this.s);
  @override
  Widget build(BuildContext context) => Row(children: [
        RoundIcon(Icons.chevron_left_rounded, onTap: () => s.shiftMonth(-1)),
        Expanded(
          child: AnimatedSwitcher(
            duration: Motion.base,
            switchInCurve: Motion.curve,
            transitionBuilder: (c, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(a), child: c)),
            child: Column(
              key: ValueKey(s.month),
              children: [
                Text(monthNames[s.month.month - 1], style: T.title.copyWith(fontSize: 22), textAlign: TextAlign.center),
                Text('${s.month.year}', style: T.sub),
              ],
            ),
          ),
        ),
        AnimatedOpacity(
          duration: Motion.fast,
          opacity: s.isCurrentMonth ? 0.35 : 1,
          child: RoundIcon(Icons.chevron_right_rounded, onTap: () => s.shiftMonth(1)),
        ),
      ]);
}

// ---------------------------------------------------------------- balance

class _BalanceCard extends StatelessWidget {
  final Store s;
  const _BalanceCard(this.s);
  @override
  Widget build(BuildContext context) {
    final used = (s.expense / s.budget).clamp(0.0, 1.0);
    final hot = used >= 0.8;
    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Saldo do mês', style: T.small),
        const SizedBox(height: 6),
        AnimatedAmount(s.balance, format: brl, style: T.big.copyWith(fontSize: 32)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _Flow('Receitas', s.income, Icons.arrow_downward_rounded, C.green, C.greenBg)),
          const SizedBox(width: 10),
          Expanded(child: _Flow('Despesas', s.expense, Icons.arrow_upward_rounded, C.accent, const Color(0xFFFFEEE6))),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Text('Orçamento · ${brl(s.budget, dec: 0)}', style: T.small)),
          Text('${(s.expense / s.budget * 100).round()}% usado',
              style: T.small.copyWith(color: hot ? C.accent : C.ink, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Container(
            height: 6,
            color: C.track,
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: used),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => FractionallySizedBox(
                widthFactor: v,
                child: AnimatedContainer(
                    duration: Motion.base,
                    decoration: BoxDecoration(color: hot ? C.accent : C.ink, borderRadius: BorderRadius.circular(3))),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Flow extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final Color fg, bg;
  const _Flow(this.label, this.value, this.icon, this.fg, this.bg);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, size: 15, color: fg)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: T.small.copyWith(fontSize: 10.5)),
              AnimatedAmount(value, format: (v) => brl(v, dec: 0), style: T.body.copyWith(fontSize: 13.5)),
            ]),
          ),
        ]),
      );
}

// ---------------------------------------------------------------- categories

class _CategoryCard extends StatelessWidget {
  final Store s;
  const _CategoryCard(this.s);
  @override
  Widget build(BuildContext context) {
    final cats = s.byCategory;
    final total = s.expense;
    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Gastos por categoria', style: T.body),
        const SizedBox(height: 14),
        Row(children: [
          SizedBox(
            width: 124,
            height: 124,
            child: TweenAnimationBuilder<double>(
              key: ValueKey('${s.month}-${cats.length}-${total.round()}'),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeInOutCubic,
              builder: (_, t, _) => CustomPaint(
                painter: _DonutPainter([for (final c in cats) (c.$2, c.$1.color)], t),
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Total', style: T.small),
                    Text(brl(total, dec: 0), style: T.body.copyWith(fontSize: 14)),
                  ]),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(children: [
              for (final c in cats.take(5))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3.5),
                  child: Row(children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: c.$1.color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(c.$1.name, style: T.small.copyWith(color: C.ink))),
                    Text('${(c.$2 / total * 100).round()}%', style: T.small),
                  ]),
                ),
            ]),
          ),
        ]),
      ]),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<(double, Color)> segs;
  final double t;
  _DonutPainter(this.segs, this.t);
  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: min(size.width, size.height) / 2 - stroke / 2);
    canvas.drawArc(rect, 0, 2 * pi, false, Paint()..style = PaintingStyle.stroke..strokeWidth = stroke..color = C.track);
    final total = segs.fold(0.0, (a, b) => a + b.$1);
    if (total == 0) return;
    var used = 0.0, start = -pi / 2;
    final budget = 2 * pi * t;
    for (final s in segs) {
      final full = s.$1 / total * 2 * pi;
      final drawn = (budget - used).clamp(0.0, full);
      used += full;
      const gap = 0.07;
      if (drawn > gap) {
        canvas.drawArc(rect, start + gap / 2, drawn - gap, false,
            Paint()..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.round..color = s.$2);
      }
      start += full;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter o) => o.t != t || o.segs != segs;
}

// ---------------------------------------------------------------- bills

class _BillsCard extends StatelessWidget {
  const _BillsCard();
  @override
  Widget build(BuildContext context) => SoftCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Próximas contas', style: T.body),
          const SizedBox(height: 8),
          for (final b in bills)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(11)),
                    child: Icon(b.icon, size: 17, color: C.ink)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(b.name, style: T.body.copyWith(fontSize: 13)),
                    Text(b.due, style: T.small.copyWith(color: C.accent)),
                  ]),
                ),
                Text(brl(b.amount), style: T.body.copyWith(fontSize: 13)),
              ]),
            ),
        ]),
      );
}

// ---------------------------------------------------------------- transaction row

class TxnRow extends StatelessWidget {
  final Txn t;
  const TxnRow(this.t, {super.key});
  @override
  Widget build(BuildContext context) {
    final inc = t.kind == Kind.income;
    return Pressable(
      onTap: () {},
      child: SoftCard(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(12)),
            child: Icon(t.category.icon, size: 18, color: C.ink),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.title, style: T.body.copyWith(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${t.category.name} · ${dayLabel(t.date)}', style: T.small),
            ]),
          ),
          Text('${inc ? '+' : '−'} ${brl(t.amount)}',
              style: T.body.copyWith(fontSize: 13, color: inc ? C.green : C.ink)),
        ]),
      ),
    );
  }
}
