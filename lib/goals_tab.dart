import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

/// Análises ▸ Metas: savings goals with progress and a quick deposit.
/// Money moves in and out of a goal through the "Metas" category of the add sheet.
class GoalsTab extends StatefulWidget {
  const GoalsTab({super.key});
  @override
  State<GoalsTab> createState() => _GoalsTabState();
}

class _GoalsTabState extends State<GoalsTab> {
  int _tab = 0;
  static const _tabs = ['Em andamento', 'Concluídas'];

  @override
  Widget build(BuildContext context) {
    final all = Store.i.goals;
    final list = all.where((g) => g.done == (_tab == 1)).toList();
    final saved = all.fold(0.0, (a, g) => a + g.saved);
    final target = all.fold(0.0, (a, g) => a + g.target);
    return Column(
      children: [
        Reveal(
          index: 1,
          child: SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total guardado', style: T.small),
                const SizedBox(height: 6),
                AnimatedAmount(saved, format: brl, style: T.big.copyWith(fontSize: 30)),
                const SizedBox(height: 2),
                Text(
                  'de ${brl(target, dec: 0)} em ${all.length} ${all.length == 1 ? 'meta' : 'metas'} · '
                  '${all.where((g) => !g.done).length} em andamento',
                  style: T.small,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Reveal(
          index: 2,
          child: SegmentedPill(labels: _tabs, index: _tab, onChanged: (i) => setState(() => _tab = i)),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: Motion.base,
          switchInCurve: Motion.curve,
          transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
          layoutBuilder: (cur, prev) => Stack(alignment: Alignment.topCenter, children: [...prev, ?cur]),
          child: Column(
            key: ValueKey(_tab),
            children: [
              for (var i = 0; i < list.length; i++)
                Reveal(
                  index: i,
                  child: Padding(padding: const EdgeInsets.only(bottom: 10), child: _GoalCard(list[i])),
                ),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      _tab == 0 ? 'Nenhuma meta em andamento. Toque no + para criar uma.' : 'Nenhuma meta concluída ainda',
                      textAlign: TextAlign.center,
                      style: T.sub,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Text(
          'Para guardar ou retirar dinheiro, use o + e escolha a categoria Metas.',
          textAlign: TextAlign.center,
          style: T.small.copyWith(fontSize: 10.5, color: C.faint),
        ),
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  final Goal g;
  const _GoalCard(this.g);

  @override
  Widget build(BuildContext context) {
    final bar = g.done ? C.green : C.ink;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(11)),
                child: Icon(g.icon, size: 17, color: C.ink),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.name, style: T.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(g.deadline, style: T.small),
                  ],
                ),
              ),
              if (g.done)
                Pill('Concluída', fg: C.green, bg: C.greenBg)
              else
                Pill('${(g.progress * 100).round()}%', fg: C.accent, bg: C.accentBg),
            ],
          ),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: brl(g.saved, dec: 0), style: T.body.copyWith(fontSize: 12.5)),
                TextSpan(text: ' de ${brl(g.target, dec: 0)}', style: T.small),
              ],
            ),
          ),
          const SizedBox(height: 7),
          ProgressBar(g.progress, bar),
          if (!g.done) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text('Faltam ${brl(g.target - g.saved, dec: 0)}', style: T.small)),
                Pressable(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Store.i.contribute(g, 100);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      '+ R\$ 100',
                      style: TextStyle(color: C.onInk, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
