import 'package:flutter/material.dart';
import 'data.dart';
import 'theme.dart';
import 'widgets.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _tab = 0;
  final _ctrl = TextEditingController();
  static const _tabs = ['All', 'Paid', 'Pending', 'Overdue'];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Supports free text plus an "amount:>1000" token.
  List<Report> get _filtered {
    final q = _ctrl.text.toLowerCase().trim();
    double? min;
    final words = <String>[];
    for (final t in q.split(RegExp(r'\s+')).where((e) => e.isNotEmpty)) {
      if (t.startsWith('amount:>')) {
        min = double.tryParse(t.substring(8));
      } else {
        words.add(t);
      }
    }
    return reports.where((r) {
      if (_tab > 0 && r.status.index != _tab - 1) return false;
      if (min != null && r.amount <= min) return false;
      final hay = '${r.title} ${r.sub}'.toLowerCase();
      return words.every(hay.contains);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    final filterCount = _tab == 0 ? 3 : 1;
    return ScreenList(
      title: 'Reports',
      subtitle: '${reports.length} reports · 12 clients',
      children: [
        Reveal(
          index: 1,
          child: Row(children: [
            Expanded(
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  const Icon(Icons.search_rounded, size: 17, color: C.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      decoration: const InputDecoration(
                          isDense: true, border: InputBorder.none, hintText: 'Search or amount:>1000', hintStyle: TextStyle(color: C.faint, fontWeight: FontWeight.w400)),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            Stack(clipBehavior: Clip.none, children: [
              const RoundIcon(Icons.filter_alt_rounded),
              Positioned(
                right: -2,
                top: -3,
                child: AnimatedSwitcher(
                  duration: Motion.fast,
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                  child: Container(
                    key: ValueKey(filterCount),
                    width: 15,
                    height: 15,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: C.accent, shape: BoxShape.circle),
                    child: Text('$filterCount', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        Reveal(index: 2, child: SegmentedPill(labels: _tabs, index: _tab, onChanged: (i) => setState(() => _tab = i))),
        const SizedBox(height: 10),
        Reveal(
          index: 3,
          child: Row(children: [
            Expanded(
              child: Text('${list.length} of ${reports.length} reports', style: T.small.copyWith(color: C.ink, fontWeight: FontWeight.w600)),
            ),
            GestureDetector(
              onTap: () => setState(() {
                _tab = 0;
                _ctrl.clear();
              }),
              child: Text('Clear all', style: T.small.copyWith(color: C.accent, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        AnimatedSize(
          duration: Motion.base,
          curve: Motion.curve,
          alignment: Alignment.topCenter,
          child: Column(children: [
            for (var i = 0; i < list.length; i++)
              // ValueKey(title) → surviving rows keep their identity (no re-animate)
              Reveal(
                key: ValueKey('${list[i].title}$_tab'),
                index: i,
                child: Padding(padding: const EdgeInsets.only(bottom: 8), child: _ReportRow(list[i])),
              ),
            if (list.isEmpty)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No reports match', style: T.sub))),
          ]),
        ),
      ],
    );
  }
}

class _ReportRow extends StatelessWidget {
  final Report r;
  const _ReportRow(this.r);
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: () {},
        child: SoftCard(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(12)),
              child: Icon(r.icon, size: 17, color: C.ink),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.title, style: T.body.copyWith(fontSize: 13)),
                Text(r.sub, style: T.small),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              SplitText(money(r.amount, dec: r.amount % 1 == 0 ? 0 : 2),
                  style: T.body.copyWith(fontSize: 13)),
              const SizedBox(height: 4),
              Pill(statusLabel(r.status), fg: statusFg(r.status), bg: statusBg(r.status)),
            ]),
          ]),
        ),
      );
}
