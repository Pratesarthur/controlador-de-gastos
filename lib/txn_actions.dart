import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'add_sheet.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

Future<R?> _sheet<R>(BuildContext context, Widget child) =>
    showModalBottomSheet<R>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black38,
      builder: (_) => Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
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
                child,
              ],
            ),
          ),
        ),
      ),
    );

Widget _option(
  BuildContext context, {
  required IconData icon,
  required String label,
  String? sub,
  Color? color,
  required VoidCallback onTap,
}) => Pressable(
  onTap: onTap,
  child: Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    decoration: BoxDecoration(
      color: C.bg,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Icon(icon, size: 20, color: color ?? C.ink),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: T.body.copyWith(color: color ?? C.ink)),
              if (sub != null) Text(sub, style: T.small),
            ],
          ),
        ),
      ],
    ),
  ),
);

/// For an entry that belongs to a series: only this one, or this and the next ones.
/// Returns null when dismissed; for a single entry returns false without asking.
Future<bool?> askScope(BuildContext context, Txn t, String verb) async {
  final n = Store.i.followingCount(t);
  if (t.group == null || n <= 1) return false;
  return _sheet<bool>(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$verb ${t.recurring ? 'recorrência' : 'parcela'} ${t.inst}/${t.instTotal}',
          style: T.title.copyWith(fontSize: 20),
        ),
        const SizedBox(height: 4),
        Text(t.title, style: T.sub),
        const SizedBox(height: 14),
        _option(
          context,
          icon: Icons.looks_one_outlined,
          label: 'Somente esta',
          onTap: () => Navigator.of(context).pop(false),
        ),
        _option(
          context,
          icon: Icons.layers_outlined,
          label: 'Esta e as próximas',
          sub: '$n lançamentos, a partir de ${shortDate(t.date)}',
          onTap: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
}

Future<void> showTxnActions(BuildContext context, Txn t) async {
  final inc = t.kind == Kind.income;
  final action = await _sheet<String>(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: C.bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(t.category.icon, size: 19, color: C.ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.title,
                    style: T.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${dayLabel(t.date)} · ${Store.i.sourceName(t)}',
                    style: T.small,
                  ),
                ],
              ),
            ),
            Text(
              '${inc ? '+' : '−'} ${brl(t.amount)}',
              style: T.body.copyWith(color: inc ? C.green : C.ink),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _option(
          context,
          icon: Icons.edit_outlined,
          label: 'Editar',
          onTap: () => Navigator.of(context).pop('edit'),
        ),
        _option(
          context,
          icon: Icons.copy_rounded,
          label: 'Duplicar para hoje',
          onTap: () => Navigator.of(context).pop('dup'),
        ),
        _option(
          context,
          icon: Icons.delete_outline_rounded,
          label: 'Excluir',
          color: C.accent,
          onTap: () => Navigator.of(context).pop('del'),
        ),
      ],
    ),
  );
  if (!context.mounted || action == null) return;
  switch (action) {
    case 'edit':
      await showAddSheet(context, editing: t);
    case 'dup':
      HapticFeedback.mediumImpact();
      Store.i.duplicate(t);
    case 'del':
      await confirmDelete(context, t);
  }
}

Future<void> confirmDelete(BuildContext context, Txn t) async {
  final following = await askScope(context, t, 'Excluir');
  if (following == null || !context.mounted) return;
  final n = following ? Store.i.followingCount(t) : 1;
  final ok = await _sheet<bool>(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          n == 1 ? 'Excluir lançamento?' : 'Excluir $n lançamentos?',
          style: T.title.copyWith(fontSize: 20),
        ),
        const SizedBox(height: 6),
        Text(
          '"${t.title}" será removido e o saldo será recalculado. Essa ação não pode ser desfeita.',
          style: T.sub,
        ),
        const SizedBox(height: 16),
        _option(
          context,
          icon: Icons.delete_outline_rounded,
          label: 'Excluir',
          color: C.accent,
          onTap: () => Navigator.of(context).pop(true),
        ),
        _option(
          context,
          icon: Icons.close_rounded,
          label: 'Cancelar',
          onTap: () => Navigator.of(context).pop(false),
        ),
      ],
    ),
  );
  if (ok == true) {
    HapticFeedback.mediumImpact();
    Store.i.remove(t, following: following);
  }
}
