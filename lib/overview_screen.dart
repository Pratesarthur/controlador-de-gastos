import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'accounts_screen.dart';
import 'month_picker.dart';
import 'store.dart';
import 'txn_actions.dart';
import 'theme.dart';
import 'widgets.dart';

/// Home ("Início"): total available, spending donut, favorite account + card cycle,
/// recent transactions.
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
          Reveal(child: _TotalCard(s)),
          const SizedBox(height: 16),
          Reveal(index: 1, child: MonthBar(s)),
          const SizedBox(height: 14),
          Reveal(index: 2, child: _CategoryCard(s)),
          const SizedBox(height: 14),
          Reveal(index: 3, child: _AccountsCard(s)),
          const SizedBox(height: 22),
          Reveal(
            index: 4,
            child: Row(
              children: [
                Expanded(child: Text('Últimas transações', style: T.body)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AnimatedSize(
            duration: Motion.base,
            curve: Motion.curve,
            alignment: Alignment.topCenter,
            child: Column(
              children: [
                for (var i = 0; i < min(items.length, 6); i++)
                  Reveal(
                    key: ValueKey('${s.month.month}-${items[i].id}'),
                    index: 5 + i,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TxnRow(items[i]),
                    ),
                  ),
                if (items.isEmpty)
                  Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text('Nenhuma transação neste mês', style: T.sub),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

// ---------------------------------------------------------------- total available

class _TotalCard extends StatelessWidget {
  final Store s;
  const _TotalCard(this.s);
  @override
  Widget build(BuildContext context) => SoftCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Total disponível', style: T.small),
        const SizedBox(height: 6),
        AnimatedAmount(
          s.totalAvailable,
          format: brl,
          style: T.big.copyWith(fontSize: 36),
        ),
        const SizedBox(height: 2),
        Text(
          'somando ${s.accounts.length} ${s.accounts.length == 1 ? 'conta' : 'contas'}',
          style: T.small,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _Flow(
                'Receitas do mês',
                s.income,
                Icons.arrow_downward_rounded,
                C.green,
                C.greenBg,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Flow(
                'Despesas do mês',
                s.expense,
                Icons.arrow_upward_rounded,
                C.accent,
                C.accentBg,
              ),
            ),
          ],
        ),
      ],
    ),
  );
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
    decoration: BoxDecoration(
      color: C.bg,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Icon(icon, size: 15, color: fg),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: T.small.copyWith(fontSize: 10.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              AnimatedAmount(
                value,
                format: (v) => brl(v, dec: 0),
                style: T.body.copyWith(fontSize: 13.5),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------- month bar

class MonthBar extends StatelessWidget {
  final Store s;
  const MonthBar(this.s, {super.key});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      RoundIcon(Icons.chevron_left_rounded, onTap: () => s.shiftMonth(-1)),
      Expanded(
        child: Pressable(
          onTap: () async {
            final m = await showMonthPicker(context, s.month, s.lastMonth);
            if (m != null) s.setMonth(m);
          },
          child: AnimatedSwitcher(
            duration: Motion.base,
            switchInCurve: Motion.curve,
            transitionBuilder: (c, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(a),
                child: c,
              ),
            ),
            child: Column(
              key: ValueKey(s.month),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      monthNames[s.month.month - 1],
                      style: T.title.copyWith(fontSize: 22),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.expand_more_rounded,
                      size: 20,
                      color: C.muted,
                    ),
                  ],
                ),
                Text('${s.month.year}', style: T.sub),
              ],
            ),
          ),
        ),
      ),
      AnimatedOpacity(
        duration: Motion.fast,
        opacity: s.canGoNext ? 1 : 0.35,
        child: RoundIcon(
          Icons.chevron_right_rounded,
          onTap: () => s.shiftMonth(1),
        ),
      ),
    ],
  );
}

// ---------------------------------------------------------------- categories donut

class _CategoryCard extends StatefulWidget {
  final Store s;
  const _CategoryCard(this.s);
  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  int? _sel;
  static const double _size = 190;

  void _pickAt(Offset p, List<(Category, double)> cats, double total) {
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
    for (var i = 0; i < cats.length; i++) {
      acc += cats[i].$2 / total * 2 * pi;
      if (a <= acc) {
        HapticFeedback.selectionClick();
        setState(() => _sel = _sel == i ? null : i);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final cats = s.byCategory;
    final total = s.expense;
    final sel = (_sel != null && _sel! < cats.length) ? _sel : null;
    final used = (s.expense / s.budget).clamp(0.0, 1.0);
    final hot = used >= 0.8;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gastos por categoria', style: T.body),
          const SizedBox(height: 14),
          Center(
            child: GestureDetector(
              onTapDown: (d) => _pickAt(d.localPosition, cats, total),
              child: SizedBox(
                width: _size,
                height: _size,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey('${s.month}-${cats.length}-${total.round()}'),
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1100),
                  curve: Curves.easeInOutCubic,
                  builder: (_, t, _) => CustomPaint(
                    painter: DonutPainter(
                      [for (final c in cats) (c.$2, c.$1.color)],
                      t,
                      sel,
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: Motion.fast,
                        child: Column(
                          key: ValueKey(sel),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              sel == null ? 'Total gasto' : cats[sel].$1.name,
                              style: T.small,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              brl(sel == null ? total : cats[sel].$2, dec: 0),
                              style: T.big.copyWith(fontSize: 22),
                            ),
                            if (sel != null && total > 0)
                              Text(
                                '${(cats[sel].$2 / total * 100).toStringAsFixed(0)}% dos gastos',
                                style: T.small.copyWith(
                                  color: cats[sel].$1.color == C.ink
                                      ? C.ink
                                      : C.muted,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (cats.isEmpty)
            Center(child: Text('Sem despesas neste mês', style: T.sub)),
          for (var i = 0; i < cats.length; i++)
            Pressable(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _sel = _sel == i ? null : i);
              },
              child: AnimatedContainer(
                duration: Motion.fast,
                margin: const EdgeInsets.only(bottom: 2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                decoration: BoxDecoration(
                  color: sel == i ? C.bg : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: cats[i].$1.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        cats[i].$1.name,
                        style: T.body.copyWith(fontSize: 13),
                      ),
                    ),
                    Text(
                      brl(cats[i].$2),
                      style: T.small.copyWith(color: C.ink),
                    ),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '${(cats[i].$2 / total * 100).toStringAsFixed(0)}%',
                        textAlign: TextAlign.right,
                        style: T.body.copyWith(fontSize: 13, color: C.muted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Orçamento · ${brl(s.budget, dec: 0)}',
                  style: T.small,
                ),
              ),
              Text(
                '${(s.expense / s.budget * 100).round()}% usado',
                style: T.small.copyWith(
                  color: hot ? C.accent : C.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ProgressBar(used, hot ? C.accent : C.ink, height: 6),
        ],
      ),
    );
  }
}

class DonutPainter extends CustomPainter {
  final List<(double, Color)> segs;
  final double t;
  final int? sel;
  DonutPainter(this.segs, this.t, this.sel);
  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 22.0;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: min(size.width, size.height) / 2 - stroke / 2 - 4,
    );
    canvas.drawArc(
      rect,
      0,
      2 * pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = C.track,
    );
    final total = segs.fold(0.0, (a, b) => a + b.$1);
    if (total == 0) return;
    var used = 0.0, start = -pi / 2;
    final budget = 2 * pi * t;
    for (var i = 0; i < segs.length; i++) {
      final full = segs[i].$1 / total * 2 * pi;
      final drawn = (budget - used).clamp(0.0, full);
      used += full;
      const gap = 0.05;
      final isSel = i == sel;
      if (drawn > gap) {
        canvas.drawArc(
          rect,
          start + gap / 2,
          drawn - gap,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = isSel ? stroke + 8 : stroke
            ..strokeCap = StrokeCap.butt
            ..color = sel == null || isSel
                ? segs[i].$2
                : segs[i].$2.withValues(alpha: 0.28),
        );
      }
      start += full;
    }
  }

  @override
  bool shouldRepaint(DonutPainter o) =>
      o.t != t || o.sel != sel || o.segs != segs;
}

// ---------------------------------------------------------------- favorite account + card cycle

class _AccountsCard extends StatelessWidget {
  final Store s;
  const _AccountsCard(this.s);

  @override
  Widget build(BuildContext context) {
    final acc = s.favAccount;
    final card = s.favCard;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Conta e cartão favoritos', style: T.body),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AccountsScreen(),
                  ),
                ),
                child: Text(
                  'Gerenciar ▸',
                  style: T.small.copyWith(
                    color: C.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Tile(
            icon: Icons.account_balance_outlined,
            title: acc.name,
            caption: 'Dinheiro disponível',
            child: AnimatedAmount(
              s.accountBalance(acc),
              format: brl,
              style: T.big.copyWith(fontSize: 24),
            ),
          ),
          if (card != null) ...[const SizedBox(height: 8), _CardTile(s, card)],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title, caption;
  final Widget child;
  const _Tile({
    required this.icon,
    required this.title,
    required this.caption,
    required this.child,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: C.bg,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: C.ink),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: T.body.copyWith(fontSize: 13))),
          ],
        ),
        const SizedBox(height: 10),
        Text(caption, style: T.small),
        const SizedBox(height: 2),
        child,
      ],
    ),
  );
}

class _CardTile extends StatelessWidget {
  final Store s;
  final CardAcct card;
  const _CardTile(this.s, this.card);
  @override
  Widget build(BuildContext context) {
    final cy = s.cycleOf(card);
    final frac = card.limit == 0
        ? 0.0
        : (cy.spent / card.limit).clamp(0.0, 1.0);
    final left = cy.daysLeft;
    return _Tile(
      icon: Icons.credit_card_rounded,
      title: card.name,
      caption: 'Gasto no ciclo atual',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedAmount(
            cy.spent,
            format: brl,
            style: T.big.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 10),
          ProgressBar(frac, frac >= 0.8 ? C.accent : C.ink),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Limite ${brl(card.limit, dec: 0)}',
                  style: T.small,
                ),
              ),
              Pill(
                left == 0
                    ? 'Fecha hoje'
                    : 'Fecha em $left ${left == 1 ? 'dia' : 'dias'}',
                fg: left <= 3 ? C.accent : C.muted,
                bg: left <= 3 ? C.accentBg : C.surface,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Ciclo: ${shortDate(cy.start)} a ${shortDate(cy.end)}',
            style: T.small,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- transaction row

class TxnRow extends StatelessWidget {
  final Txn t;
  const TxnRow(this.t, {super.key});
  @override
  Widget build(BuildContext context) {
    final inc = t.kind == Kind.income;
    final sub = [
      t.sub == null ? t.category.name : '${t.category.name} › ${t.sub!.name}',
      dayLabel(t.date),
      if (t.isInstallment) '${t.inst}/${t.instTotal}',
      if (t.recurring) 'Recorrente ${t.inst}/${t.instTotal}',
    ].join(' · ');
    return Pressable(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        showTxnActions(context, t);
      },
      child: SoftCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: C.bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(t.category.icon, size: 18, color: C.ink),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.title,
                    style: T.body.copyWith(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    sub,
                    style: T.small,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${inc ? '+' : '−'} ${brl(t.amount)}',
                  style: T.body.copyWith(
                    fontSize: 13,
                    color: inc ? C.green : C.ink,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      t.isCard
                          ? Icons.credit_card_rounded
                          : Icons.account_balance_outlined,
                      size: 10,
                      color: C.faint,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      Store.i.sourceName(t),
                      style: T.small.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
