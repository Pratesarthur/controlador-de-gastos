import 'package:finance_app/add_sheet.dart';
import 'package:finance_app/analytics_extra.dart';
import 'package:finance_app/calendar_sheet.dart';
import 'package:finance_app/main.dart';
import 'package:finance_app/month_picker.dart';
import 'package:finance_app/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_app/goal_sheet.dart';
import 'package:finance_app/theme.dart';

void main() {
  final s = Store.i;
  final start = DateTime(2040, 1, 15);

  test('recorrente repete o mesmo valor por até 120 meses', () {
    s.add(title: 'Academia', categoryId: 'saude', subId: 'academia', amount: 99.9, kind: Kind.expense, date: start, accountId: 'cc', installments: 120, recurring: true);
    final all = [for (var k = 0; k < 120; k++) ...s.monthItemsFor(addMonths(start, k)).where((t) => t.title == 'Academia')];
    expect(all.length, 120);
    expect(all.every((t) => t.amount == 99.9 && t.recurring && !t.isInstallment), isTrue);
  });

  test('editar e excluir "esta e as próximas"', () {
    s.add(title: 'Plano', categoryId: 'assinaturas', amount: 50, kind: Kind.expense, date: start, accountId: 'cc', installments: 6, recurring: true);
    List<Txn> items() => [for (var k = 0; k < 6; k++) ...s.monthItemsFor(addMonths(start, k)).where((t) => t.title.startsWith('Plano'))];
    final third = items()[2];
    s.update(third.copyWith(title: 'Plano Pro', amount: 70), following: true);
    expect(items().map((t) => t.amount), [50, 50, 70, 70, 70, 70]);
    s.remove(items()[4], following: true);
    expect(items().length, 4);
    s.remove(items().first);
    expect(items().length, 3);
  });

  test('parcelas viram planos com progresso', () {
    final p = s.plans.firstWhere((p) => p.title == 'Notebook');
    expect(p.count, 10);
    expect(p.paidCount, greaterThanOrEqualTo(3));
    expect(p.total, closeTo(4200, 0.01));
    expect(s.installmentHorizon(), isNotEmpty);
  });

  testWidgets('telas novas renderizam sem overflow', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const FinanceApp());
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.text('Análises'));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('Parcelas'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(InstallmentsTab), findsOneWidget);
    await tester.tap(find.text('Categorias'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(CategoriesTab), findsOneWidget);
    await tester.tap(find.text('Subcategorias'));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('Receitas').first);
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.text('Transações'));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byIcon(Icons.filter_list_rounded));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Filtrar transações'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('calendário e seletor de mês sem overflow', (tester) async {
    tester.view.physicalSize = const Size(1080, 1500); // short screen
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) => Scaffold(body: Column(children: [
      TextButton(onPressed: () => showCalendarSheet(c, DateTime.now()), child: const Text('cal')),
      TextButton(onPressed: () => showMonthPicker(c, DateTime.now(), addMonths(DateTime.now(), 24)), child: const Text('mes')),
      TextButton(onPressed: () => showAddSheet(c), child: const Text('add')),
    ])))));
    for (final t in ['cal', 'mes', 'add']) {
      await tester.tap(find.text(t));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull, reason: t);
      await tester.tapAt(const Offset(20, 20));
      await tester.pump(const Duration(seconds: 1));
    }
  });

  test('metas: aporte e retirada pela categoria Metas', () {
    s.addGoal('Teste', 1000, DateTime(2045, 1, 1), Icons.flag_rounded, 100);
    final g = s.goals.last;
    expect(g.saved, 100);
    expect(categoryById('metas').subs.any((x) => x.id == g.id), isTrue);
    s.add(title: '', categoryId: 'metas', subId: g.id, amount: 300, kind: Kind.expense, date: DateTime.now(), accountId: 'cc');
    expect(g.saved, 400);
    s.add(title: '', categoryId: 'metas_ret', subId: g.id, amount: 150, kind: Kind.income, date: DateTime.now(), accountId: 'cc');
    expect(g.saved, 250);
    final dep = s.monthItemsFor(DateTime.now()).firstWhere((t) => t.subId == g.id && t.categoryId == 'metas');
    s.remove(dep);
    expect(g.saved, 0); // 100 - 150 clamped
    expect(parseMoney('1.234,56'), 1234.56);
  });

  testWidgets('configurações: tema escuro, perfil e sair', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 3;
    addTearDown(() {
      tester.view.reset();
      setDarkMode(false);
    });
    await tester.pumpWidget(const FinanceApp());
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('Ajustes'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Configurações'), findsOneWidget);
    expect(find.text('Minhas contas'), findsOneWidget);
    expect(find.text('Meus cartões'), findsOneWidget);
    await tester.tap(find.text('Escuro'));
    await tester.pump(const Duration(seconds: 2));
    expect(C.dark, isTrue);
    expect(find.text('Configurações'), findsOneWidget); // stays on the same tab
    await tester.tap(find.text('Usuário'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 3));
    expect(find.text('Editar perfil'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Análises'));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('Metas'));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Nova meta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
