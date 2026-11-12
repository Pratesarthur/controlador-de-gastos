import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> showAddSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black38,
      builder: (_) => const AddSheet(),
    );

enum _Phase { idle, saved }

class AddSheet extends StatefulWidget {
  const AddSheet({super.key});
  @override
  State<AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<AddSheet> {
  Kind _kind = Kind.expense;
  int _cents = 0;
  String _cat = 'mercado';
  _Phase _phase = _Phase.idle;
  final _title = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  List<Category> get _cats => categories.where((c) => c.kind == _kind).toList();

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

  Future<void> _save() async {
    if (_cents == 0 || _phase == _Phase.saved) return;
    HapticFeedback.mediumImpact();
    Store.i.add(title: _title.text.trim(), categoryId: _cat, amount: _cents / 100, kind: _kind);
    setState(() => _phase = _Phase.saved);
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final color = kindColor(_kind);
    final saved = _phase == _Phase.saved;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 36, height: 4, decoration: BoxDecoration(color: C.track, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 14),
              SegmentedPill(
                labels: const ['Despesa', 'Receita'],
                index: _kind.index,
                onChanged: (i) => setState(() {
                  _kind = Kind.values[i];
                  _cat = _cats.first.id;
                }),
              ),
              const SizedBox(height: 18),
              // amount
              AnimatedDefaultTextStyle(
                duration: Motion.base,
                style: T.big.copyWith(fontSize: 40, color: _cents == 0 ? C.faint : color),
                child: Text(brl(_cents / 100)),
              ),
              const SizedBox(height: 14),
              // category chips
              SizedBox(
                height: 38,
                child: AnimatedSwitcher(
                  duration: Motion.base,
                  child: ListView(
                    key: ValueKey(_kind),
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      for (final c in _cats)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Pressable(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _cat = c.id);
                            },
                            child: AnimatedContainer(
                              duration: Motion.base,
                              curve: Motion.curve,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                  color: _cat == c.id ? C.ink : C.bg, borderRadius: BorderRadius.circular(19)),
                              child: Row(children: [
                                Icon(c.icon, size: 15, color: _cat == c.id ? Colors.white : C.ink),
                                const SizedBox(width: 6),
                                Text(c.name,
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: _cat == c.id ? Colors.white : C.ink)),
                              ]),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
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
              // keypad
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
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: saved ? C.green : (_cents == 0 ? C.track : C.ink), borderRadius: BorderRadius.circular(26)),
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
                          : Text(_kind == Kind.expense ? 'Adicionar despesa' : 'Adicionar receita',
                              key: const ValueKey('i'),
                              style: TextStyle(color: _cents == 0 ? C.faint : Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
