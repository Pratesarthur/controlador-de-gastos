import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

/// Metas: savings goals with progress and quick contributions.
class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});
  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  int _tab = 0;
  static const _tabs = ['Em andamento', 'Concluídas'];

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) {
          final all = Store.i.goals;
          final list = all.where((g) => g.done == (_tab == 1)).toList();
          final saved = all.fold(0.0, (a, g) => a + g.saved);
          final target = all.fold(0.0, (a, g) => a + g.target);
          return ScreenList(
            title: 'Metas',
            subtitle: '${all.where((g) => !g.done).length} em andamento · ${all.where((g) => g.done).length} concluída(s)',
            children: [
              Reveal(
                index: 1,
                child: SoftCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Total guardado', style: T.small),
                    const SizedBox(height: 6),
                    AnimatedAmount(saved, format: brl, style: T.big.copyWith(fontSize: 30)),
                    const SizedBox(height: 2),
                    Text('de ${brl(target, dec: 0)} em ${all.length} metas', style: T.small),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
              Reveal(index: 2, child: SegmentedPill(labels: _tabs, index: _tab, onChanged: (i) => setState(() => _tab = i))),
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
                      Reveal(index: i, child: Padding(padding: const EdgeInsets.only(bottom: 10), child: _GoalCard(list[i]))),
                    if (list.isEmpty)
                      const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Nenhuma meta aqui', style: T.sub))),
                  ],
                ),
              ),
            ],
          );
        },
      );
}

class _GoalCard extends StatelessWidget {
  final Goal g;
  const _GoalCard(this.g);

  @override
  Widget build(BuildContext context) {
    final bar = g.done ? C.green : C.ink;
    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(11)),
            child: Icon(g.icon, size: 17, color: C.ink),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(g.name, style: T.body),
              Text(g.deadline, style: T.small),
            ]),
          ),
          if (g.done)
            const Pill('Concluída', fg: C.green, bg: C.greenBg)
          else
            Pill('${(g.progress * 100).round()}%', fg: C.accent, bg: const Color(0xFFFFEEE6)),
        ]),
        const SizedBox(height: 12),
        Text.rich(TextSpan(children: [
          TextSpan(text: brl(g.saved, dec: 0), style: T.body.copyWith(fontSize: 12.5)),
          TextSpan(text: ' de ${brl(g.target, dec: 0)}', style: T.small),
        ])),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Container(
            height: 5,
            color: C.track,
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: g.progress),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => FractionallySizedBox(
                  widthFactor: v, child: Container(decoration: BoxDecoration(color: bar, borderRadius: BorderRadius.circular(3)))),
            ),
          ),
        ),
        if (!g.done) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Text('Faltam ${brl(g.target - g.saved, dec: 0)}', style: T.small)),
            Pressable(
              onTap: () {
                HapticFeedback.lightImpact();
                Store.i.contribute(g, 100);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(10)),
                child: const Text('+ R\$ 100',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}
