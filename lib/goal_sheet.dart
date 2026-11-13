import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'calendar_sheet.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

/// Parses "1.234,56" / "1234.56" / "1234" into a double (0 when invalid).
double parseMoney(String s) {
  final t = s.trim();
  if (t.isEmpty) return 0;
  final n = t.contains(',') ? t.replaceAll('.', '').replaceAll(',', '.') : t;
  return double.tryParse(n) ?? 0;
}

const _goalIcons = <IconData>[
  Icons.flag_rounded,
  Icons.shield_outlined,
  Icons.flight_takeoff_rounded,
  Icons.home_outlined,
  Icons.directions_car_outlined,
  Icons.laptop_mac_rounded,
  Icons.school_outlined,
  Icons.favorite_border_rounded,
  Icons.celebration_outlined,
  Icons.savings_outlined,
];

Future<void> showGoalSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  barrierColor: Colors.black38,
  builder: (_) => const _GoalSheet(),
);

class _GoalSheet extends StatefulWidget {
  const _GoalSheet();
  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  final _name = TextEditingController();
  final _target = TextEditingController();
  final _initial = TextEditingController();
  DateTime _due = DateTime(DateTime.now().year + 1, DateTime.now().month, DateTime.now().day);
  int _icon = 0;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _initial.dispose();
    super.dispose();
  }

  Widget _field(TextEditingController c, String hint, {bool money = false, IconData? icon}) => Container(
    height: 48,
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(14)),
    child: Row(
      children: [
        if (icon != null) ...[Icon(icon, size: 18, color: C.ink), const SizedBox(width: 10)],
        Expanded(
          child: TextField(
            controller: c,
            keyboardType: money ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
            inputFormatters: money ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))] : null,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: C.ink),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hint,
              hintStyle: TextStyle(color: C.faint, fontWeight: FontWeight.w400),
            ),
          ),
        ),
      ],
    ),
  );

  Future<void> _pickDue() async {
    final d = await showCalendarSheet(context, _due);
    if (d != null) setState(() => _due = d);
  }

  void _save() {
    final name = _name.text.trim();
    final target = parseMoney(_target.text);
    if (name.isEmpty) return setState(() => _error = 'Dê um nome para a meta');
    if (target <= 0) return setState(() => _error = 'Informe o valor que quer alcançar');
    if (!_due.isAfter(DateTime.now().subtract(const Duration(days: 1)))) {
      return setState(() => _error = 'Escolha uma data de hoje em diante');
    }
    HapticFeedback.mediumImpact();
    Store.i.addGoal(name, target, _due, _goalIcons[_icon], parseMoney(_initial.text).clamp(0, target).toDouble());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(30)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: C.track, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              Text('Nova meta', style: T.title.copyWith(fontSize: 20)),
              const SizedBox(height: 14),
              _field(_name, 'Nome da meta (ex.: Viagem)', icon: Icons.edit_outlined),
              _field(_target, 'Quanto quer juntar (R\$)', money: true, icon: Icons.flag_rounded),
              _field(_initial, 'Já tenho guardado (R\$, opcional)', money: true, icon: Icons.savings_outlined),
              Pressable(
                onTap: _pickDue,
                child: Container(
                  height: 48,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 18, color: C.ink),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Até quando · ${_due.day} de ${monthNames[_due.month - 1].toLowerCase()} de ${_due.year}', style: T.body.copyWith(fontSize: 14))),
                      Icon(Icons.chevron_right_rounded, size: 18, color: C.faint),
                    ],
                  ),
                ),
              ),
              Text('Ícone', style: T.small.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < _goalIcons.length; i++)
                    Pressable(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _icon = i);
                      },
                      child: AnimatedContainer(
                        duration: Motion.base,
                        curve: Motion.curve,
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: _icon == i ? C.ink : C.bg, borderRadius: BorderRadius.circular(14)),
                        child: Icon(_goalIcons[i], size: 20, color: _icon == i ? C.onInk : C.ink),
                      ),
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: T.small.copyWith(color: C.accent, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 16),
              Pressable(
                onTap: _save,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(26)),
                  child: Center(child: Text('Criar meta', style: TextStyle(color: C.onInk, fontWeight: FontWeight.w600))),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
