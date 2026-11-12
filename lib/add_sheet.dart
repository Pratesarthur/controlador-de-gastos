import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'calendar_sheet.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> showAddSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black38,
      builder: (_) => const AddSheet(),
    );

enum _Phase { idle, saved }

enum _View { main, categories }

class AddSheet extends StatefulWidget {
  const AddSheet({super.key});
  @override
  State<AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<AddSheet> {
  final _s = Store.i;
  Kind _kind = Kind.expense;
  int _cents = 0;
  String _cat = 'mercado';
  DateTime _date = DateTime.now();
  bool _card = false;
  String? _src;
  bool _installed = false;
  int _n = 2;
  bool _isTotal = true;
  _View _view = _View.main;
  _Phase _phase = _Phase.idle;
  final _title = TextEditingController();

  @override
  void initState() {
    super.initState();
    _src = _s.favAccountId;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  List<Category> get _cats => categories.where((c) => c.kind == _kind).toList();
  bool get _inst => _kind == Kind.expense && _card && _installed;
  double get _amount => _cents / 100;

  void _key(String k) {
    HapticFeedback.lightImpact();
    setState(() {
      if (k == '⌫') {
        _cents ~/= 10;
      } else if (_cents < 99999999) {
        _cents = _cents * 10 + int.parse(k);
      }
    });
  }

  void _setCard(bool card) {
    HapticFeedback.selectionClick();
    setState(() {
      _card = card;
      _src = card ? (_s.cards.isEmpty ? null : _s.favCard!.id) : _s.favAccountId;
    });
  }

  Future<void> _pickDate() async {
    final d = await showCalendarSheet(context, _date);
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    if (_cents == 0 || _src == null || _phase == _Phase.saved) return;
    HapticFeedback.mediumImpact();
    _s.add(
      title: _title.text.trim(),
      categoryId: _cat,
      amount: _amount,
      kind: _kind,
      date: _date,
      accountId: _src!,
      isCard: _card,
      installments: _inst ? _n : 1,
      amountIsTotal: _isTotal,
    );
    setState(() => _phase = _Phase.saved);
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 36, height: 4, decoration: BoxDecoration(color: C.track, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 14),
                AnimatedSize(
                  duration: Motion.base,
                  curve: Motion.curve,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: Motion.base,
                    switchInCurve: Motion.curve,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween(begin: Offset(_view == _View.categories ? 0.12 : -0.12, 0), end: Offset.zero).animate(a),
                        child: child,
                      ),
                    ),
                    layoutBuilder: (cur, prev) => Stack(alignment: Alignment.topCenter, children: [...prev, ?cur]),
                    child: _view == _View.main
                        ? KeyedSubtree(key: const ValueKey('main'), child: _main())
                        : KeyedSubtree(key: const ValueKey('cats'), child: _categoryPage()),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );

  // ------------------------------------------------------------ category sub page

  Widget _categoryPage() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          RoundIcon(Icons.arrow_back_rounded, onTap: () => setState(() => _view = _View.main)),
          const SizedBox(width: 12),
          Text('Escolha a categoria', style: T.title.copyWith(fontSize: 20)),
        ]),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.05,
          children: [
            for (final c in _cats)
              Pressable(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _cat = c.id;
                    _view = _View.main;
                  });
                },
                child: AnimatedContainer(
                  duration: Motion.base,
                  curve: Motion.curve,
                  decoration: BoxDecoration(color: _cat == c.id ? C.ink : C.bg, borderRadius: BorderRadius.circular(18)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(c.icon, size: 24, color: _cat == c.id ? Colors.white : C.ink),
                    const SizedBox(height: 8),
                    Text(c.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _cat == c.id ? Colors.white : C.ink)),
                  ]),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
      ]);

  // ------------------------------------------------------------ main page

  Widget _pickerButton({required IconData icon, required String label, required String value, required VoidCallback onTap, Color? iconColor}) =>
      Expanded(
        child: Pressable(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Icon(icon, size: 18, color: iconColor ?? C.ink),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: T.small.copyWith(fontSize: 10.5)),
                  Text(value, style: T.body.copyWith(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded, size: 18, color: C.faint),
            ]),
          ),
        ),
      );

  Widget _srcChips() {
    final isCard = _card;
    final list = isCard
        ? [for (final c in _s.cards) (c.id, c.name, Icons.credit_card_rounded)]
        : [for (final a in _s.accounts) (a.id, a.name, Icons.account_balance_outlined)];
    if (list.isEmpty) {
      return Text('Nenhum cartão cadastrado. Cadastre em Início ▸ Gerenciar.', style: T.small.copyWith(color: C.accent));
    }
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          for (final e in list)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Pressable(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _src = e.$1);
                },
                child: AnimatedContainer(
                  duration: Motion.base,
                  curve: Motion.curve,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: _src == e.$1 ? C.ink : C.bg, borderRadius: BorderRadius.circular(19)),
                  child: Row(children: [
                    Icon(e.$3, size: 15, color: _src == e.$1 ? Colors.white : C.ink),
                    const SizedBox(width: 6),
                    Text(e.$2,
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _src == e.$1 ? Colors.white : C.ink)),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _installments() {
    final per = _isTotal ? _amount / _n : _amount;
    final total = _isTotal ? _amount : _amount * _n;
    Widget stepBtn(IconData i, VoidCallback f) => Pressable(
          onTap: () {
            HapticFeedback.selectionClick();
            f();
          },
          child: Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(color: C.bg, shape: BoxShape.circle),
            child: Icon(i, size: 18, color: C.ink),
          ),
        );
    return AnimatedSize(
      duration: Motion.base,
      curve: Motion.curve,
      alignment: Alignment.topCenter,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.layers_outlined, size: 18, color: C.ink),
          const SizedBox(width: 8),
          const Expanded(child: Text('Compra parcelada?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.ink))),
          Switch(
            value: _installed,
            activeTrackColor: C.ink,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() => _installed = v);
            },
          ),
        ]),
        if (_installed) ...[
          const SizedBox(height: 4),
          Row(children: [
            const Expanded(child: Text('Quantas parcelas?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.ink))),
            stepBtn(Icons.remove_rounded, () => setState(() => _n = (_n - 1).clamp(2, 48))),
            SizedBox(width: 52, child: Center(child: Text('${_n}x', style: T.body.copyWith(fontSize: 16)))),
            stepBtn(Icons.add_rounded, () => setState(() => _n = (_n + 1).clamp(2, 48))),
          ]),
          const SizedBox(height: 10),
          const Text('O valor digitado é…', style: TextStyle(fontSize: 12, color: C.muted)),
          const SizedBox(height: 6),
          SegmentedPill(labels: const ['Valor total', 'Valor da parcela'], index: _isTotal ? 0 : 1, onChanged: (i) => setState(() => _isTotal = i == 0)),
          const SizedBox(height: 8),
          Text(
            _cents == 0
                ? 'Digite o valor para ver o resumo'
                : '$_n parcelas de ${brl(per)} · total ${brl(total)}\nUma parcela por mês, a partir de ${shortDate(_date)}.',
            style: T.small.copyWith(color: C.ink),
          ),
        ],
      ]),
    );
  }

  Widget _main() {
    final color = kindColor(_kind);
    final saved = _phase == _Phase.saved;
    final cat = categoryById(_cat);
    final canSave = _cents > 0 && _src != null;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SegmentedPill(
        labels: const ['Despesa', 'Receita'],
        index: _kind.index,
        onChanged: (i) => setState(() {
          _kind = Kind.values[i];
          _cat = _cats.first.id;
          if (_kind == Kind.income) {
            _card = false;
            _src = _s.favAccountId;
          }
        }),
      ),
      const SizedBox(height: 16),
      Center(
        child: AnimatedDefaultTextStyle(
          duration: Motion.base,
          style: T.big.copyWith(fontSize: 40, color: _cents == 0 ? C.faint : color),
          child: Text(brl(_amount)),
        ),
      ),
      const SizedBox(height: 14),
      Row(children: [
        _pickerButton(icon: cat.icon, label: 'Categoria', value: cat.name, onTap: () => setState(() => _view = _View.categories)),
        const SizedBox(width: 8),
        _pickerButton(
            icon: Icons.calendar_today_rounded,
            label: _kind == Kind.expense ? 'Data da despesa' : 'Data da receita',
            value: dayLabel(_date),
            onTap: _pickDate),
      ]),
      const SizedBox(height: 12),
      if (_kind == Kind.expense) ...[
        SegmentedPill(labels: const ['Conta', 'Cartão de crédito'], index: _card ? 1 : 0, onChanged: (i) => _setCard(i == 1)),
        const SizedBox(height: 10),
      ] else ...[
        const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Cair em qual conta?', style: T.small)),
      ],
      _srcChips(),
      if (_kind == Kind.expense && _card) ...[
        const SizedBox(height: 6),
        _installments(),
      ],
      const SizedBox(height: 10),
      Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(13)),
        child: TextField(
          controller: _title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Descrição (opcional)',
              hintStyle: TextStyle(color: C.faint, fontWeight: FontWeight.w400)),
        ),
      ),
      const SizedBox(height: 10),
      for (final row in const [
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['7', '8', '9'],
        ['', '0', '⌫']
      ])
        Row(children: [
          for (final k in row)
            Expanded(
              child: k.isEmpty
                  ? const SizedBox(height: 52)
                  : Pressable(
                      onTap: () => _key(k),
                      child: SizedBox(
                        height: 52,
                        child: Center(
                            child: k == '⌫'
                                ? const Icon(Icons.backspace_outlined, size: 20, color: C.ink)
                                : Text(k, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: C.ink))),
                      ),
                    ),
            ),
        ]),
      const SizedBox(height: 8),
      Pressable(
        onTap: _save,
        child: AnimatedContainer(
          duration: Motion.base,
          curve: Motion.curve,
          height: 52,
          decoration: BoxDecoration(color: saved ? C.green : (!canSave ? C.track : C.ink), borderRadius: BorderRadius.circular(26)),
          child: Center(
            child: AnimatedSwitcher(
              duration: Motion.fast,
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)),
              child: saved
                  ? const Row(key: ValueKey('s'), mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.check_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 6),
                      Text('Salvo!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ])
                  : Text(
                      _kind == Kind.income
                          ? 'Adicionar receita'
                          : (_inst ? 'Adicionar em ${_n}x' : 'Adicionar despesa'),
                      key: ValueKey('i$_kind$_inst$_n'),
                      style: TextStyle(color: !canSave ? C.faint : Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ),
    ]);
  }
}
