import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

/// Contas e cartões: list, choose the favorite (shown on Início) and add new ones.
class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListenableBuilder(
            listenable: Store.i,
            builder: (context, _) {
              final s = Store.i;
              return ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                children: [
                  Row(children: [
                    RoundIcon(Icons.arrow_back_rounded, onTap: () => Navigator.of(context).pop()),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Contas e cartões', style: T.title)),
                  ]),
                  const SizedBox(height: 18),
                  _Header('Contas', 'Nova conta', () => _newAccount(context)),
                  for (final a in s.accounts)
                    _Row(
                      icon: Icons.account_balance_outlined,
                      title: a.name,
                      sub: 'Saldo ${brl(s.accountBalance(a))}',
                      fav: a.id == s.favAccountId,
                      onFav: () => s.setFavoriteAccount(a.id),
                    ),
                  const SizedBox(height: 18),
                  _Header('Cartões de crédito', 'Novo cartão', () => _newCard(context)),
                  if (s.cards.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Nenhum cartão cadastrado', style: T.sub)),
                  for (final c in s.cards)
                    _Row(
                      icon: Icons.credit_card_rounded,
                      title: c.name,
                      sub: 'Fecha dia ${c.closingDay} · limite ${brl(c.limit, dec: 0)} · ciclo ${brl(s.cycleOf(c).spent)}',
                      fav: c.id == s.favCardId,
                      onFav: () => s.setFavoriteCard(c.id),
                    ),
                ],
              );
            },
          ),
        ),
      );

  void _newAccount(BuildContext context) => _form(context, 'Nova conta', [
        _Field('name', 'Nome da conta', text: true),
        _Field('value', 'Saldo atual (R\$)'),
      ], (v) {
        final name = v['name']!.trim();
        if (name.isEmpty) return false;
        Store.i.addAccount(name, _num(v['value']!));
        return true;
      });

  void _newCard(BuildContext context) => _form(context, 'Novo cartão', [
        _Field('name', 'Nome do cartão', text: true),
        _Field('day', 'Dia do fechamento (1 a 28)', digits: true),
        _Field('value', 'Limite (R\$)'),
      ], (v) {
        final name = v['name']!.trim();
        final day = int.tryParse(v['day']!) ?? 0;
        if (name.isEmpty || day < 1 || day > 28) return false;
        Store.i.addCard(name, day, _num(v['value']!));
        return true;
      });
}

double _num(String s) => double.tryParse(s.trim().replaceAll('.', '').replaceAll(',', '.')) ?? 0;

class _Field {
  final String key, label;
  final bool text, digits;
  const _Field(this.key, this.label, {this.text = false, this.digits = false});
}

void _form(BuildContext context, String title, List<_Field> fields, bool Function(Map<String, String>) onSave) {
  final ctrls = {for (final f in fields) f.key: TextEditingController()};
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: T.title.copyWith(fontSize: 20)),
          const SizedBox(height: 14),
          for (final f in fields)
            Container(
              height: 46,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(13)),
              child: TextField(
                controller: ctrls[f.key],
                keyboardType: f.text ? TextInputType.text : (f.digits ? TextInputType.number : const TextInputType.numberWithOptions(decimal: true)),
                inputFormatters: f.digits ? [FilteringTextInputFormatter.digitsOnly] : null,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: f.label,
                    hintStyle: const TextStyle(color: C.faint, fontWeight: FontWeight.w400)),
              ),
            ),
          const SizedBox(height: 4),
          Pressable(
            onTap: () {
              if (onSave({for (final e in ctrls.entries) e.key: e.value.text})) {
                HapticFeedback.mediumImpact();
                Navigator.of(ctx).pop();
              }
            },
            child: Container(
              height: 50,
              width: double.infinity,
              decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(25)),
              child: const Center(child: Text('Salvar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
            ),
          ),
        ]),
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  final String title, action;
  final VoidCallback onTap;
  const _Header(this.title, this.action, this.onTap);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Expanded(child: Text(title, style: T.body)),
          GestureDetector(
            onTap: onTap,
            child: Text('+ $action', style: T.small.copyWith(color: C.accent, fontWeight: FontWeight.w600)),
          ),
        ]),
      );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  final bool fav;
  final VoidCallback onFav;
  const _Row({required this.icon, required this.title, required this.sub, required this.fav, required this.onFav});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SoftCard(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 18, color: C.ink),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: T.body.copyWith(fontSize: 13)),
                Text(sub, style: T.small),
              ]),
            ),
            Pressable(
              onTap: () {
                HapticFeedback.selectionClick();
                onFav();
              },
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: AnimatedSwitcher(
                  duration: Motion.fast,
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                  child: Icon(fav ? Icons.star_rounded : Icons.star_border_rounded,
                      key: ValueKey(fav), size: 24, color: fav ? C.accent : C.faint),
                ),
              ),
            ),
          ]),
        ),
      );
}
