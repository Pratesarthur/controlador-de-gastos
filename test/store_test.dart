import 'package:finance_app/store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final s = Store.i;
  final start = DateTime(2030, 1, 31);

  test('parcelado com valor total divide e a última parcela absorve o centavo', () {
    s.add(title: 'TV', categoryId: 'compras', amount: 1000, kind: Kind.expense, date: start, accountId: 'card1', isCard: true, installments: 3);
    final l = s.monthItemsFor(DateTime(2030, 1)).followedBy(s.monthItemsFor(DateTime(2030, 2))).followedBy(s.monthItemsFor(DateTime(2030, 3))).where((t) => t.title == 'TV').toList();
    expect(l.length, 3);
    expect(l.fold(0.0, (a, t) => a + t.amount), closeTo(1000, 0.001));
    expect(l.map((t) => t.inst).toSet(), {1, 2, 3});
    expect(s.monthItemsFor(DateTime(2030, 2)).first.date, DateTime(2030, 2, 28)); // 31 jan → 28 fev
  });

  test('parcelado com valor da parcela repete o valor em cada mês', () {
    s.add(title: 'Sofá', categoryId: 'compras', amount: 250, kind: Kind.expense, date: start, accountId: 'card1', isCard: true, installments: 4, amountIsTotal: false);
    final sum = [1, 2, 3, 4].map((m) => s.monthItemsFor(DateTime(2030, m)).where((t) => t.title == 'Sofá').fold(0.0, (a, t) => a + t.amount)).toList();
    expect(sum, [250, 250, 250, 250]);
  });

  test('ciclo do cartão vai do dia seguinte ao fechamento até o fechamento', () {
    final c = s.cards.first;
    final cy = s.cycleOf(c);
    expect(cy.start.day, c.closingDay + 1);
    expect(cy.end.day, c.closingDay);
    expect(cy.daysLeft, inInclusiveRange(0, 31));
  });
}
