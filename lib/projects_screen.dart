import 'package:flutter/material.dart';
import 'data.dart';
import 'theme.dart';
import 'widgets.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});
  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  int _tab = 0;
  static const _tabs = ['Active', 'Completed', 'Archived'];
  static const _meta = [
    ('active projects', 'Due date', C.accent),
    ('completed this quarter', 'Latest', C.accent),
    ('archived projects', 'Restore', C.accent),
  ];

  @override
  Widget build(BuildContext context) {
    final list = projects.where((p) => p.state.index == _tab).toList();
    final m = _meta[_tab];
    return ScreenList(
      title: 'Projects',
      subtitle: '12 active · 3 due this week',
      children: [
        Reveal(index: 1, child: SegmentedPill(labels: _tabs, index: _tab, onChanged: (i) => setState(() => _tab = i))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: Motion.fast,
              child: Text('${list.length} ${m.$1}', key: ValueKey(_tab), style: T.small),
            ),
          ),
          Text(m.$2, style: T.small.copyWith(color: m.$3, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        // Keyed by tab → whole list cross-fades and cards re-stagger in.
        AnimatedSwitcher(
          duration: Motion.base,
          switchInCurve: Motion.curve,
          transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
          layoutBuilder: (cur, prev) => Stack(alignment: Alignment.topCenter, children: [...prev, ?cur]),
          child: Column(
            key: ValueKey(_tab),
            children: [
              for (var i = 0; i < list.length; i++)
                Reveal(index: i, child: Padding(padding: const EdgeInsets.only(bottom: 10), child: _ProjectCard(list[i]))),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project p;
  const _ProjectCard(this.p);

  @override
  Widget build(BuildContext context) {
    final done = p.state == ProjectState.completed;
    final archived = p.state == ProjectState.archived;
    final bar = done ? C.green : (archived ? C.faint : C.ink);
    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(11)),
            child: Icon(p.icon, size: 17, color: C.ink),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: T.body),
              Text(p.client, style: T.small),
            ]),
          ),
          const Icon(Icons.more_horiz_rounded, color: C.muted, size: 18),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: compact(p.spent), style: T.body.copyWith(fontSize: 12.5)),
              TextSpan(text: ' of ${compact(p.budget)}', style: T.small),
            ])),
          ),
          Text('${(p.progress * 100).round()}%', style: T.body.copyWith(fontSize: 12.5)),
        ]),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Container(
            height: 5,
            color: C.track,
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: p.progress),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => FractionallySizedBox(
                  widthFactor: v, child: Container(decoration: BoxDecoration(color: bar, borderRadius: BorderRadius.circular(3)))),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          AvatarStack(p.team),
          const Spacer(),
          Pill(p.tag,
              fg: done ? C.green : (archived ? C.muted : C.accent),
              bg: done ? C.greenBg : (archived ? C.bg : const Color(0xFFFFEEE6))),
        ]),
      ]),
    );
  }
}
