import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'month_picker.dart';
import 'overview_screen.dart' show TxnRow;
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

/// Transações: every transaction of the selected month, with search, type and source filters.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _tab = 0;
  final _ctrl = TextEditingController();
  static const _tabs = ['Todas', 'Receitas', 'Despesas'];

  /// Selected source: null = all, otherwise (isCard, id).
  (bool, String)? _source;

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
      if (_source != null && (t.isCard != _source!.$1 || t.accountId != _source!.$2)) return false;
      if (min != null && t.amount <= min) return false;
      final hay = '${t.title} ${t.category.name} ${t.sub?.name ?? ''}'.toLowerCase();
      return words.every(hay.contains);
    }).toList();
  }

  String? _sourceLabel() {
    final s = _source;
    if (s == null) return null;
    final st = Store.i;
    return s.$1 ? st.cards.where((c) => c.id == s.$2).firstOrNull?.name : st.accounts.where((a) => a.id == s.$2).firstOrNull?.name;
  }

  Future<void> _openFilter() async {
    HapticFeedback.selectionClick();
    final r = await showModalBottomSheet<_FilterResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black38,
      builder: (_) => _FilterSheet(_source),
    );
    if (r != null && mounted) setState(() => _source = r.source);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) {
          final s = Store.i;
          final all = s.monthItems;
          final list = _filtered(all);
          final total = list.fold(0.0, (a, t) => a + (t.kind == Kind.income ? t.amount : -t.amount));
          final srcName = _sourceLabel();
          return ScreenList(
            title: 'Transações',
            subtitle: '${monthNames[s.month.month - 1]} ${s.month.year} · ${all.length} lançamentos',
            trailing: RoundIcon(Icons.filter_list_rounded, dot: _source != null || !s.isCurrentMonth, onTap: _openFilter),
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
                      decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [
                        Icon(Icons.search_rounded, size: 17, color: C.muted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _ctrl,
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
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
              if (srcName != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Pressable(
                    onTap: () => setState(() => _source = null),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
                      decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(16)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_source!.$1 ? Icons.credit_card_rounded : Icons.account_balance_outlined, size: 14, color: C.onInk),
                        const SizedBox(width: 6),
                        Text(srcName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.onInk)),
                        const SizedBox(width: 6),
                        Icon(Icons.close_rounded, size: 14, color: C.onInk),
                      ]),
                    ),
                  ),
                ),
              ],
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
                      _source = null;
                      _ctrl.clear();
                    }),
                    child: Text('Limpar', style: T.small.copyWith(color: C.accent, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
              const SizedBox(height: 4),
              Text('Segure um lançamento para editar, duplicar ou excluir.', style: T.small.copyWith(fontSize: 10.5, color: C.faint)),
              const SizedBox(height: 8),
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
                    Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Nenhuma transação encontrada', style: T.sub))),
                ]),
              ),
            ],
          );
        },
      );
}

class _FilterResult {
  final (bool, String)? source;
  const _FilterResult(this.source);
}

/// Filter sheet: month, account, credit card.
class _FilterSheet extends StatefulWidget {
  final (bool, String)? source;
  const _FilterSheet(this.source);
  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late (bool, String)? _src = widget.source;
  final _s = Store.i;

  Widget _chip(String label, IconData icon, bool sel, VoidCallback onTap) => Pressable(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: Motion.base,
          curve: Motion.curve,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(color: sel ? C.ink : C.bg, borderRadius: BorderRadius.circular(19)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: sel ? C.onInk : C.ink),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: sel ? C.onInk : C.ink)),
          ]),
        ),
      );

  Widget _group(String title, List<Widget> chips) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 16),
        Text(title, style: T.small.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: chips),
      ]);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _s,
        builder: (context, _) => Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(30)),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: C.track, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 14),
                Text('Filtrar transações', style: T.title.copyWith(fontSize: 20)),
                const SizedBox(height: 14),
                Text('Mês', style: T.small.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Pressable(
                  onTap: () async {
                    final m = await showMonthPicker(context, _s.month, _s.lastMonth);
                    if (m != null) _s.setMonth(m);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      Icon(Icons.calendar_month_rounded, size: 18, color: C.ink),
                      const SizedBox(width: 10),
                      Expanded(child: Text('${monthNames[_s.month.month - 1]} ${_s.month.year}', style: T.body.copyWith(fontSize: 13.5))),
                      Icon(Icons.chevron_right_rounded, size: 18, color: C.faint),
                    ]),
                  ),
                ),
                _group('Conta', [
                  _chip('Todas', Icons.all_inclusive_rounded, _src == null, () => setState(() => _src = null)),
                  for (final a in _s.accounts)
                    _chip(a.name, Icons.account_balance_outlined, _src == (false, a.id), () => setState(() => _src = (false, a.id))),
                ]),
                _group('Cartão', [
                  for (final c in _s.cards)
                    _chip(c.name, Icons.credit_card_rounded, _src == (true, c.id), () => setState(() => _src = (true, c.id))),
                  if (_s.cards.isEmpty) Text('Nenhum cartão cadastrado', style: T.small),
                ]),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(
                    child: Pressable(
                      onTap: () => setState(() => _src = null),
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(25)),
                        child: Center(child: Text('Limpar', style: TextStyle(fontWeight: FontWeight.w600, color: C.ink))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Pressable(
                      onTap: () => Navigator.of(context).pop(_FilterResult(_src)),
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(25)),
                        child: Center(child: Text('Aplicar', style: TextStyle(color: C.onInk, fontWeight: FontWeight.w600))),
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      );
}
