import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'calendar_sheet.dart';
import 'store.dart';
import 'txn_actions.dart' show askScope;
import 'theme.dart';
import 'widgets.dart';

Future<void> showAddSheet(BuildContext context, {Txn? editing}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black38,
      builder: (_) => AddSheet(editing: editing),
    );

enum _Phase { idle, saved }

enum _View { main, categories, subs }

class AddSheet extends StatefulWidget {
  final Txn? editing;
  const AddSheet({super.key, this.editing});
  @override
  State<AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<AddSheet> {
  final _s = Store.i;
  Kind _kind = Kind.expense;
  int _cents = 0;
  String _cat = 'alimentacao';
  String? _sub = 'mercado';
  Category? _pending; // category whose subcategories are being chosen
  DateTime _date = DateTime.now();
  bool _card = false;
  String? _src;
  int _mode = 0; // 0 à vista · 1 parcelado · 2 recorrente
  int _n = 2;
  bool _isTotal = true;
  _View _view = _View.main;
  _Phase _phase = _Phase.idle;
  final _title = TextEditingController();

  @override
  void initState() {
    super.initState();
    _src = _s.favAccountId;
    final e = widget.editing;
    if (e != null) {
      _kind = e.kind;
      _cents = (e.amount * 100).round();
      _cat = e.categoryId;
      _sub = e.subId;
      _date = e.date;
      _card = e.isCard;
      _src = e.accountId;
      _title.text = e.title;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  static const _maxCents = 99999999999; // R$ 999.999.999,99

  List<Category> get _cats => categories.where((c) => c.kind == _kind).toList();
  bool get _editing => widget.editing != null;
  bool get _inst => !_editing && _kind == Kind.expense && _card && _mode == 1;
  bool get _rec => !_editing && _mode == 2;
  double get _amount => _cents / 100;

  void _key(String k) {
    HapticFeedback.lightImpact();
    setState(() {
      if (k == '⌫') {
        _cents ~/= 10;
      } else if (_cents * 10 + int.parse(k) <= _maxCents) {
        _cents = _cents * 10 + int.parse(k);
      }
    });
  }

  void _setCard(bool card) {
    HapticFeedback.selectionClick();
    setState(() {
      _card = card;
      if (!card && _mode == 1) _mode = 0; // installments exist only on cards
      _src = card
          ? (_s.cards.isEmpty ? null : _s.favCard!.id)
          : _s.favAccountId;
    });
  }

  Future<void> _pickDate() async {
    final d = await showCalendarSheet(context, _date);
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    if (_cents == 0 || _src == null || _phase == _Phase.saved) return;
    final e = widget.editing;
    if (e != null) {
      final following = await askScope(context, e, 'Alterar');
      if (following == null || !mounted) return;
      HapticFeedback.mediumImpact();
      final name = _title.text.trim();
      final cat = categoryById(_cat);
      _s.update(
        e.copyWith(
          title: name.isEmpty ? (cat.subById(_sub)?.name ?? cat.name) : name,
          categoryId: _cat,
          subId: _sub,
          amount: _amount,
          kind: _kind,
          date: _date,
          accountId: _src!,
          isCard: _card,
        ),
        following: following,
      );
    } else {
      HapticFeedback.mediumImpact();
      _s.add(
        title: _title.text.trim(),
        categoryId: _cat,
        subId: _sub,
        amount: _amount,
        kind: _kind,
        date: _date,
        accountId: _src!,
        isCard: _card,
        installments: (_inst || _rec) ? _n : 1,
        amountIsTotal: _isTotal,
        recurring: _rec,
      );
    }
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
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(30),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: C.track,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
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
                      position: Tween(
                        begin: Offset(_view == _View.main ? -0.12 : 0.12, 0),
                        end: Offset.zero,
                      ).animate(a),
                      child: child,
                    ),
                  ),
                  layoutBuilder: (cur, prev) => Stack(
                    alignment: Alignment.topCenter,
                    children: [...prev, ?cur],
                  ),
                  child: switch (_view) {
                    _View.main => KeyedSubtree(
                      key: const ValueKey('main'),
                      child: _main(),
                    ),
                    _View.categories => KeyedSubtree(
                      key: const ValueKey('cats'),
                      child: _categoryPage(),
                    ),
                    _View.subs => KeyedSubtree(
                      key: const ValueKey('subs'),
                      child: _subPage(),
                    ),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  // ------------------------------------------------------------ category sub page

  Widget _categoryPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          RoundIcon(
            Icons.arrow_back_rounded,
            onTap: () => setState(() => _view = _View.main),
          ),
          const SizedBox(width: 12),
          Text('Escolha a categoria', style: T.title.copyWith(fontSize: 20)),
        ],
      ),
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
                  if (c.subs.isEmpty && !c.dynamicSubs) {
                    _cat = c.id;
                    _sub = null;
                    _view = _View.main;
                  } else {
                    _pending = c;
                    _view = _View.subs;
                  }
                });
              },
              child: AnimatedContainer(
                duration: Motion.base,
                curve: Motion.curve,
                decoration: BoxDecoration(
                  color: _cat == c.id ? C.ink : C.bg,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      c.icon,
                      size: 24,
                      color: _cat == c.id ? C.onInk : C.ink,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      c.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _cat == c.id ? C.onInk : C.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 6),
    ],
  );

  Widget _subPage() {
    final c = _pending ?? categoryById(_cat);
    void pick(String? sub) {
      HapticFeedback.selectionClick();
      setState(() {
        _cat = c.id;
        _sub = sub;
        _view = _View.main;
      });
    }

    Widget row(String label, String? id, {IconData? icon}) {
      final sel = _cat == c.id && _sub == id;
      return Pressable(
        onTap: () => pick(id),
        child: AnimatedContainer(
          duration: Motion.base,
          curve: Motion.curve,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: sel ? C.ink : C.bg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: sel ? C.onInk : C.ink),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: sel ? C.onInk : C.ink,
                  ),
                ),
              ),
              if (sel)
                Icon(Icons.check_rounded, size: 18, color: C.onInk),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            RoundIcon(
              Icons.arrow_back_rounded,
              onTap: () => setState(() => _view = _View.categories),
            ),
            const SizedBox(width: 12),
            Icon(c.icon, size: 20, color: C.ink),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                c.name,
                style: T.title.copyWith(fontSize: 20),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (final sub in c.subs) row(sub.name, sub.id),
        if (c.dynamicSubs && c.subs.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Você ainda não tem metas. Crie uma em Análises ▸ Metas e volte aqui para guardar ou retirar dinheiro.',
              style: T.sub,
            ),
          ),
        if (!c.dynamicSubs) row('Sem subcategoria', null, icon: Icons.remove_rounded),
      ],
    );
  }

  // ------------------------------------------------------------ main page

  Widget _pickerButton({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    Color? iconColor,
  }) => Expanded(
    child: Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: C.bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor ?? C.ink),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: T.small.copyWith(fontSize: 10.5)),
                  Text(
                    value,
                    style: T.body.copyWith(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: C.faint),
          ],
        ),
      ),
    ),
  );

  Widget _srcChips() {
    final isCard = _card;
    final list = isCard
        ? [for (final c in _s.cards) (c.id, c.name, Icons.credit_card_rounded)]
        : [
            for (final a in _s.accounts)
              (a.id, a.name, Icons.account_balance_outlined),
          ];
    if (list.isEmpty) {
      return Text(
        'Nenhum cartão cadastrado. Cadastre em Início ▸ Gerenciar.',
        style: T.small.copyWith(color: C.accent),
      );
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
                  decoration: BoxDecoration(
                    color: _src == e.$1 ? C.ink : C.bg,
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        e.$3,
                        size: 15,
                        color: _src == e.$1 ? C.onInk : C.ink,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        e.$2,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _src == e.$1 ? C.onInk : C.ink,
                        ),
                      ),
                    ],
                  ),
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
        decoration: BoxDecoration(color: C.bg, shape: BoxShape.circle),
        child: Icon(i, size: 18, color: C.ink),
      ),
    );
    final rec = _mode == 2;
    final modes = _kind == Kind.expense && _card
        ? const ['À vista', 'Parcelado', 'Recorrente']
        : const ['À vista', 'Recorrente'];
    final modeIndex = modes.length == 3 ? _mode : (_mode == 2 ? 1 : 0);
    return AnimatedSize(
      duration: Motion.base,
      curve: Motion.curve,
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedPill(
            labels: modes,
            index: modeIndex,
            onChanged: (i) {
              HapticFeedback.selectionClick();
              setState(() => _mode = modes.length == 3 ? i : (i == 1 ? 2 : 0));
            },
          ),
          if (_mode != 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    rec ? 'Repetir por quantos meses?' : 'Quantas parcelas?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: C.ink,
                    ),
                  ),
                ),
                stepBtn(
                  Icons.remove_rounded,
                  () => setState(() => _n = (_n - 1).clamp(2, maxInstallments)),
                ),
                SizedBox(
                  width: 56,
                  child: Center(
                    child: Text('${_n}x', style: T.body.copyWith(fontSize: 16)),
                  ),
                ),
                stepBtn(
                  Icons.add_rounded,
                  () => setState(() => _n = (_n + 1).clamp(2, maxInstallments)),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: C.ink,
                inactiveTrackColor: C.track,
                thumbColor: C.ink,
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                min: 2,
                max: maxInstallments.toDouble(),
                divisions: maxInstallments - 2,
                value: _n.toDouble(),
                onChanged: (v) => setState(() => _n = v.round()),
              ),
            ),
            if (!rec) ...[
              Text(
                'O valor digitado é…',
                style: TextStyle(fontSize: 12, color: C.muted),
              ),
              const SizedBox(height: 6),
              SegmentedPill(
                labels: const ['Valor total', 'Valor da parcela'],
                index: _isTotal ? 0 : 1,
                onChanged: (i) => setState(() => _isTotal = i == 0),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              _cents == 0
                  ? 'Digite o valor para ver o resumo'
                  : rec
                  ? '${brl(_amount)} por mês, durante $_n meses · total ${brl(_amount * _n)}\nTodo mês no dia ${_date.day}, a partir de ${shortDate(_date)}.'
                  : '$_n parcelas de ${brl(per)} · total ${brl(total)}\nUma parcela por mês, a partir de ${shortDate(_date)}.',
              style: T.small.copyWith(color: C.ink),
            ),
          ],
        ],
      ),
    );
  }

  Widget _main() {
    final color = kindColor(_kind);
    final saved = _phase == _Phase.saved;
    final cat = categoryById(_cat);
    final canSave = _cents > 0 && _src != null && !(cat.dynamicSubs && cat.subById(_sub) == null);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedPill(
          labels: const ['Despesa', 'Receita'],
          index: _kind.index,
          onChanged: (i) => setState(() {
            _kind = Kind.values[i];
            _cat = _cats.first.id;
            _sub = _cats.first.subs.isEmpty ? null : _cats.first.subs.first.id;
            if (_kind == Kind.income) {
              _card = false;
              if (_mode == 1) _mode = 0;
              _src = _s.favAccountId;
            }
          }),
        ),
        const SizedBox(height: 16),
        Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: AnimatedDefaultTextStyle(
              duration: Motion.base,
              style: T.big.copyWith(
                fontSize: 40,
                color: _cents == 0 ? C.faint : color,
              ),
              child: Text(brl(_amount)),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _pickerButton(
              icon: cat.icon,
              label: 'Categoria',
              value: cat.subById(_sub) == null
                  ? cat.name
                  : '${cat.name} › ${cat.subById(_sub)!.name}',
              onTap: () => setState(() => _view = _View.categories),
            ),
            const SizedBox(width: 8),
            _pickerButton(
              icon: Icons.calendar_today_rounded,
              label: _kind == Kind.expense
                  ? 'Data da despesa'
                  : 'Data da receita',
              value: dayLabel(_date),
              onTap: _pickDate,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_kind == Kind.expense) ...[
          SegmentedPill(
            labels: const ['Conta', 'Cartão de crédito'],
            index: _card ? 1 : 0,
            onChanged: (i) => _setCard(i == 1),
          ),
          const SizedBox(height: 10),
        ] else ...[
          Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Cair em qual conta?', style: T.small),
          ),
        ],
        _srcChips(),
        if (!_editing) ...[
          const SizedBox(height: 6),
          _installments(),
        ] else if (widget.editing!.isSeries) ...[
          const SizedBox(height: 6),
          Text(
            '${widget.editing!.recurring ? 'Recorrência' : 'Parcela'} ${widget.editing!.inst}/${widget.editing!.instTotal} · ao salvar você escolhe se a alteração vale só para esta ou também para as próximas.',
            style: T.small.copyWith(color: C.ink),
          ),
        ],
        const SizedBox(height: 10),
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: C.bg,
            borderRadius: BorderRadius.circular(13),
          ),
          child: TextField(
            controller: _title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Descrição (opcional)',
              hintStyle: TextStyle(color: C.faint, fontWeight: FontWeight.w400),
            ),
          ),
        ),
        const SizedBox(height: 10),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', '⌫'],
        ])
          Row(
            children: [
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
                                  ? Icon(
                                      Icons.backspace_outlined,
                                      size: 20,
                                      color: C.ink,
                                    )
                                  : Text(
                                      k,
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w600,
                                        color: C.ink,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                ),
            ],
          ),
        const SizedBox(height: 8),
        Pressable(
          onTap: _save,
          child: AnimatedContainer(
            duration: Motion.base,
            curve: Motion.curve,
            height: 52,
            decoration: BoxDecoration(
              color: saved ? C.green : (!canSave ? C.track : C.ink),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: Motion.fast,
                transitionBuilder: (c, a) => ScaleTransition(
                  scale: a,
                  child: FadeTransition(opacity: a, child: c),
                ),
                child: saved
                    ? const Row(
                        key: ValueKey('s'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Salvo!',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        _editing
                            ? 'Salvar alterações'
                            : _kind == Kind.income
                            ? 'Adicionar receita'
                            : (_inst
                                  ? 'Adicionar em ${_n}x'
                                  : (_rec
                                        ? 'Adicionar recorrente'
                                        : 'Adicionar despesa')),
                        key: ValueKey('i$_kind$_inst$_n'),
                        style: TextStyle(
                          color: !canSave ? C.faint : C.onInk,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
