import 'package:flutter/material.dart';
import 'overview_screen.dart' show TxnRow;
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

/// Transações: every transaction of the selected month, with search and type filter.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _tab = 0;
  final _ctrl = TextEditingController();
  static const _tabs = ['Todas', 'Receitas', 'Despesas'];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Free text (título ou categoria) plus an optional "valor:>100" token.
  List<Txn> _filtered(List<Txn> all) {
    final q = _ctrl.text.toLowerCase().trim();
    double? min;
    final words = <String>[];
    for (final t in q.split(RegExp(r'\s+')).where((e) => e.isNotEmpty)) {
      if (t.startsWith('valor:>')) {
        min = double.tryParse(t.substring(7).replaceAll(',', '.'));
      } else {
        words.add(t);
      }
    }
    return all.where((t) {
      if (_tab == 1 && t.kind != Kind.income) return false;
      if (_tab == 2 && t.kind != Kind.expense) return false;
      if (min != null && t.amount <= min) return false;
      final hay = '${t.title} ${t.category.name}'.toLowerCase();
      return words.every(hay.contains);
    }).toList();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) {
          final s = Store.i;
          final all = s.monthItems;
          final list = _filtered(all);
          final total = list.fold(0.0, (a, t) => a + (t.kind == Kind.income ? t.amount : -t.amount));
          return ScreenList(
            title: 'Transações',
            subtitle: '${monthNames[s.month.month - 1]} ${s.month.year} · ${all.length} lançamentos',
            children: [
              Reveal(
                index: 1,
                child: Row(children: [
                  RoundIcon(Icons.chevron_left_rounded, onTap: () => s.shiftMonth(-1)),
                  const SizedBox(width: 8),
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
                                isDense: true,
                                border: InputBorder.none,
                                hintText: 'Buscar ou valor:>100',
                                hintStyle: TextStyle(color: C.faint, fontWeight: FontWeight.w400)),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedOpacity(
                    duration: Motion.fast,
                    opacity: s.canGoNext ? 1 : 0.35,
                    child: RoundIcon(Icons.chevron_right_rounded, onTap: () => s.shiftMonth(1)),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Reveal(index: 2, child: SegmentedPill(labels: _tabs, index: _tab, onChanged: (i) => setState(() => _tab = i))),
              const SizedBox(height: 10),
              Reveal(
                index: 3,
                child: Row(children: [
                  Expanded(
                    child: Text('${list.length} de ${all.length} transações · saldo ${brl(total)}',
                        style: T.small.copyWith(color: C.ink, fontWeight: FontWeight.w600)),
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      _tab = 0;
                      _ctrl.clear();
                    }),
                    child: Text('Limpar', style: T.small.copyWith(color: C.accent, fontWeight: FontWeight.w600)),
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
                    Reveal(
                      key: ValueKey('${list[i].id}$_tab'),
                      index: i < 8 ? i : 8,
                      child: Padding(padding: const EdgeInsets.only(bottom: 8), child: TxnRow(list[i])),
                    ),
                  if (list.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(32), child: Center(child: Text('Nenhuma transação encontrada', style: T.sub))),
                ]),
              ),
            ],
          );
        },
      );
}
