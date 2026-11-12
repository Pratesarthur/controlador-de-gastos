import 'dart:math';
import 'package:flutter/material.dart';
import 'theme.dart';

/// Simple in-memory store. Screens listen to it with ListenableBuilder.
/// Swap for a real repository (SQLite/Firebase) later without touching the UI much.

enum Kind { expense, income }

class Category {
  final String id, name;
  final IconData icon;
  final Color color;
  final Kind kind;
  const Category(this.id, this.name, this.icon, this.color, this.kind);
}

const categories = <Category>[
  Category('mercado', 'Mercado', Icons.shopping_basket_outlined, Color(0xFF0B0B0C), Kind.expense),
  Category('moradia', 'Moradia', Icons.home_outlined, Color(0xFFFF4D0D), Kind.expense),
  Category('transporte', 'Transporte', Icons.directions_car_outlined, Color(0xFF8FB0E8), Kind.expense),
  Category('restaurantes', 'Restaurantes', Icons.restaurant_outlined, Color(0xFFD9A37A), Kind.expense),
  Category('lazer', 'Lazer', Icons.sports_esports_outlined, Color(0xFFB4B4B8), Kind.expense),
  Category('saude', 'Saúde', Icons.favorite_border_rounded, Color(0xFF16A34A), Kind.expense),
  Category('educacao', 'Educação', Icons.school_outlined, Color(0xFF7C5CFF), Kind.expense),
  Category('compras', 'Compras', Icons.shopping_bag_outlined, Color(0xFFE5489B), Kind.expense),
  Category('assinaturas', 'Assinaturas', Icons.subscriptions_outlined, Color(0xFF0EA5A5), Kind.expense),
  Category('outros', 'Outros', Icons.more_horiz_rounded, Color(0xFF6B7280), Kind.expense),
  Category('salario', 'Salário', Icons.payments_outlined, Color(0xFF16A34A), Kind.income),
  Category('freela', 'Freelance', Icons.laptop_mac_rounded, Color(0xFF16A34A), Kind.income),
  Category('invest', 'Investimentos', Icons.trending_up_rounded, Color(0xFF16A34A), Kind.income),
];

Category categoryById(String id) => categories.firstWhere((c) => c.id == id);

/// A bank account (money available).
class Account {
  final String id, name;
  final double initial;
  Account(this.id, this.name, this.initial);
}

/// A credit card. The cycle starts the day after [closingDay] and ends on [closingDay].
class CardAcct {
  final String id, name;
  final int closingDay; // 1..28
  final double limit;
  CardAcct(this.id, this.name, this.closingDay, this.limit);
}

class Cycle {
  final DateTime start, end;
  final double spent;
  final int daysLeft;
  const Cycle(this.start, this.end, this.spent, this.daysLeft);
}

class Txn {
  final int id;
  final String title, categoryId;
  final double amount; // always positive
  final Kind kind;
  final DateTime date;
  final String accountId; // account id, or card id when [isCard]
  final bool isCard;
  final int inst, instTotal; // installment number / total (1/1 = à vista)
  const Txn(this.id, this.title, this.categoryId, this.amount, this.kind, this.date,
      {this.accountId = 'cc', this.isCard = false, this.inst = 1, this.instTotal = 1});
  Category get category => categoryById(categoryId);
  bool get isInstallment => instTotal > 1;
}

class Goal {
  final String name, deadline;
  final double target;
  double saved;
  final IconData icon;
  Goal(this.name, this.target, this.saved, this.icon, this.deadline);
  double get progress => (saved / target).clamp(0.0, 1.0);
  bool get done => saved >= target;
}

const monthNames = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
];
const monthShort = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];

String dayLabel(DateTime d) {
  final n = DateTime.now();
  final diff = DateTime(n.year, n.month, n.day).difference(DateTime(d.year, d.month, d.day)).inDays;
  if (diff == 0) return 'Hoje';
  if (diff == 1) return 'Ontem';
  return '${d.day} ${monthShort[d.month - 1]}';
}

String shortDate(DateTime d) => '${d.day} ${monthShort[d.month - 1]}';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Same day [k] months later, clamped to the month length (31 jan + 1 → 28/29 fev).
DateTime addMonths(DateTime d, int k) {
  final m = DateTime(d.year, d.month + k, 1);
  final last = DateTime(m.year, m.month + 1, 0).day;
  return DateTime(m.year, m.month, min(d.day, last));
}

class Store extends ChangeNotifier {
  Store._() {
    final n = DateTime.now();
    DateTime day(int back) => DateTime(n.year, n.month, n.day).subtract(Duration(days: back));
    final closing = (n.day + 7) % 28 + 1; // keeps the demo cycle containing recent days
    accounts.addAll([Account('cc', 'Conta Corrente', 3000), Account('poup', 'Poupança', 5200)]);
    cards.addAll([CardAcct('card1', 'Cartão Platinum', closing, 8000), CardAcct('card2', 'Cartão Virtual', 20, 2500)]);
    favAccountId = 'cc';
    favCardId = 'card1';
    _items.addAll([
      Txn(1, 'Salário', 'salario', 6500, Kind.income, DateTime(n.year, n.month, 1)),
      Txn(2, 'Aluguel', 'moradia', 1850, Kind.expense, DateTime(n.year, n.month, 1)),
      Txn(3, 'Supermercado', 'mercado', 412.35, Kind.expense, day(1)),
      Txn(4, 'Uber', 'transporte', 38.90, Kind.expense, day(0), accountId: 'card1', isCard: true),
      Txn(5, 'Jantar com amigos', 'restaurantes', 126.50, Kind.expense, day(2), accountId: 'card1', isCard: true),
      Txn(6, 'Cinema', 'lazer', 64, Kind.expense, day(3), accountId: 'card1', isCard: true),
      Txn(7, 'Farmácia', 'saude', 89.9, Kind.expense, day(4)),
      Txn(8, 'Projeto freelance', 'freela', 800, Kind.income, day(5)),
      Txn(9, 'Feira', 'mercado', 96.75, Kind.expense, day(6)),
      Txn(10, 'Combustível', 'transporte', 210, Kind.expense, day(7), accountId: 'card1', isCard: true),
    ]);
    _items.removeWhere((t) => t.date.isAfter(n)); // early in the month: drop future-dated seeds
    // history for the previous 5 months (feeds Análises)
    const extra = [350.0, 120.0, 540.0, 80.0, 260.0];
    const food = [980.0, 1120.0, 870.0, 1040.0, 930.0];
    for (var k = 1; k <= 5; k++) {
      final id = 100 + k * 10;
      _items.addAll([
        Txn(id, 'Salário', 'salario', 6500, Kind.income, DateTime(n.year, n.month - k, 1)),
        if (k.isEven) Txn(id + 1, 'Projeto freelance', 'freela', 900.0 + k * 60, Kind.income, DateTime(n.year, n.month - k, 12)),
        Txn(id + 2, 'Aluguel', 'moradia', 1850, Kind.expense, DateTime(n.year, n.month - k, 1)),
        Txn(id + 3, 'Mercado', 'mercado', food[k - 1], Kind.expense, DateTime(n.year, n.month - k, 9)),
        Txn(id + 4, 'Lazer e restaurantes', 'lazer', extra[k - 1] + 400, Kind.expense, DateTime(n.year, n.month - k, 18),
            accountId: 'card1', isCard: true),
        Txn(id + 5, 'Transporte', 'transporte', 300.0 + k * 25, Kind.expense, DateTime(n.year, n.month - k, 22),
            accountId: 'card1', isCard: true),
      ]);
    }
    _nextId = 1000;
  }
  static final Store i = Store._();

  final List<Txn> _items = [];
  final List<Account> accounts = [];
  final List<CardAcct> cards = [];
  late String favAccountId, favCardId;
  int _nextId = 1000;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  double budget = 4000;

  final List<Goal> goals = [
    Goal('Reserva de emergência', 12000, 7800, Icons.shield_outlined, 'até dez 2027'),
    Goal('Viagem de férias', 5000, 2150, Icons.flight_takeoff_rounded, 'até jul 2027'),
    Goal('Notebook novo', 4500, 4500, Icons.laptop_mac_rounded, 'concluída'),
    Goal('Entrada do apartamento', 60000, 9400, Icons.home_outlined, 'até 2030'),
  ];

  // ------------------------------------------------------------ accounts & cards

  Account get favAccount => accounts.firstWhere((a) => a.id == favAccountId, orElse: () => accounts.first);
  CardAcct? get favCard {
    if (cards.isEmpty) return null;
    return cards.firstWhere((c) => c.id == favCardId, orElse: () => cards.first);
  }

  String sourceName(Txn t) {
    final l = t.isCard ? cards.where((c) => c.id == t.accountId) : accounts.where((a) => a.id == t.accountId);
    if (l.isEmpty) return t.isCard ? 'Cartão' : 'Conta';
    return l.first is CardAcct ? (l.first as CardAcct).name : (l.first as Account).name;
  }

  /// initial balance + incomes − expenses already happened (future installments don't count yet)
  double accountBalance(Account a) {
    final now = DateTime.now();
    var v = a.initial;
    for (final t in _items) {
      if (t.isCard || t.accountId != a.id || t.date.isAfter(now)) continue;
      v += t.kind == Kind.income ? t.amount : -t.amount;
    }
    return v;
  }

  double get totalAvailable => accounts.fold(0.0, (s, a) => s + accountBalance(a));

  Cycle cycleOf(CardAcct c) {
    final today = _day(DateTime.now());
    final end = today.day <= c.closingDay
        ? DateTime(today.year, today.month, c.closingDay)
        : DateTime(today.year, today.month + 1, c.closingDay);
    final start = DateTime(end.year, end.month - 1, c.closingDay + 1);
    final spent = _items
        .where((t) => t.isCard && t.accountId == c.id && t.kind == Kind.expense && !t.date.isBefore(start) && !t.date.isAfter(end))
        .fold(0.0, (s, t) => s + t.amount);
    return Cycle(start, end, spent, end.difference(today).inDays);
  }

  void setFavoriteAccount(String id) {
    favAccountId = id;
    notifyListeners();
  }

  void setFavoriteCard(String id) {
    favCardId = id;
    notifyListeners();
  }

  void addAccount(String name, double initial) {
    final a = Account('a${_nextId++}', name, initial);
    accounts.add(a);
    if (accounts.length == 1) favAccountId = a.id;
    notifyListeners();
  }

  void addCard(String name, int closingDay, double limit) {
    final c = CardAcct('c${_nextId++}', name, closingDay.clamp(1, 28), limit);
    cards.add(c);
    if (cards.length == 1) favCardId = c.id;
    notifyListeners();
  }

  // ------------------------------------------------------------ months

  bool get isCurrentMonth => month.year == DateTime.now().year && month.month == DateTime.now().month;

  /// Last month that has data: the current one, or later when installments extend into the future.
  DateTime get lastMonth {
    final now = DateTime.now();
    var last = DateTime(now.year, now.month);
    for (final t in _items) {
      final m = DateTime(t.date.year, t.date.month);
      if (m.isAfter(last)) last = m;
    }
    return last;
  }

  bool get canGoNext => month.isBefore(lastMonth);

  void shiftMonth(int delta) {
    final m = DateTime(month.year, month.month + delta);
    if (m.isAfter(lastMonth)) return;
    month = m;
    notifyListeners();
  }

  List<Txn> get monthItems => monthItemsFor(month);

  List<Txn> monthItemsFor(DateTime m) =>
      _items.where((t) => t.date.year == m.year && t.date.month == m.month).toList()
        ..sort((a, b) => b.date != a.date ? b.date.compareTo(a.date) : b.id.compareTo(a.id));

  double get income => monthItems.where((t) => t.kind == Kind.income).fold(0.0, (s, t) => s + t.amount);
  double get expense => monthItems.where((t) => t.kind == Kind.expense).fold(0.0, (s, t) => s + t.amount);
  double get balance => income - expense;

  /// expense total per category, largest first
  List<(Category, double)> get byCategory {
    final m = <String, double>{};
    for (final t in monthItems.where((t) => t.kind == Kind.expense)) {
      m[t.categoryId] = (m[t.categoryId] ?? 0) + t.amount;
    }
    return (m.entries.map((e) => (categoryById(e.key), e.value)).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2)));
  }

  /// (paid from accounts, paid with cards) for the selected month
  (double, double) get accountVsCard {
    var a = 0.0, c = 0.0;
    for (final t in monthItems.where((t) => t.kind == Kind.expense)) {
      t.isCard ? c += t.amount : a += t.amount;
    }
    return (a, c);
  }

  /// expense per account/card in the selected month, largest first
  List<(String, bool, double)> get bySource {
    final m = <String, (String, bool, double)>{};
    for (final t in monthItems.where((t) => t.kind == Kind.expense)) {
      final key = '${t.isCard}-${t.accountId}';
      final cur = m[key];
      m[key] = (sourceName(t), t.isCard, (cur?.$3 ?? 0) + t.amount);
    }
    return m.values.toList()..sort((a, b) => b.$3.compareTo(a.$3));
  }

  List<Txn> topExpenses(int n) =>
      (monthItems.where((t) => t.kind == Kind.expense).toList()..sort((a, b) => b.amount.compareTo(a.amount))).take(n).toList();

  /// installments still to be charged after today
  double get futureInstallments => _items
      .where((t) => t.isInstallment && t.kind == Kind.expense && t.date.isAfter(DateTime.now()))
      .fold(0.0, (s, t) => s + t.amount);

  /// Income/expense totals for the last [n] months, oldest first (ending at the current month).
  List<(DateTime, double, double)> monthlyTotals(int n) {
    final now = DateTime.now();
    return [
      for (var k = n - 1; k >= 0; k--)
        () {
          final m = DateTime(now.year, now.month - k);
          final l = _items.where((t) => t.date.year == m.year && t.date.month == m.month);
          double sum(Kind kd) => l.where((t) => t.kind == kd).fold(0.0, (s, t) => s + t.amount);
          return (m, sum(Kind.income), sum(Kind.expense));
        }()
    ];
  }

  void contribute(Goal g, double v) {
    g.saved = (g.saved + v).clamp(0, g.target).toDouble();
    notifyListeners();
  }

  // ------------------------------------------------------------ adding

  /// Adds a transaction. For installments ([installments] > 1) one entry is created per month:
  /// when [amountIsTotal] the total is split (the last installment absorbs the rounding),
  /// otherwise [amount] is the value of each installment.
  void add({
    required String title,
    required String categoryId,
    required double amount,
    required Kind kind,
    required DateTime date,
    required String accountId,
    bool isCard = false,
    int installments = 1,
    bool amountIsTotal = true,
  }) {
    final name = title.isEmpty ? categoryById(categoryId).name : title;
    final n = max(1, installments);
    if (n == 1) {
      _items.add(Txn(_nextId++, name, categoryId, amount, kind, date, accountId: accountId, isCard: isCard));
    } else {
      final totalCents = (amount * 100).round() * (amountIsTotal ? 1 : n);
      final perCents = amountIsTotal ? totalCents ~/ n : (amount * 100).round();
      for (var k = 0; k < n; k++) {
        final cents = (amountIsTotal && k == n - 1) ? totalCents - perCents * (n - 1) : perCents;
        _items.add(Txn(_nextId++, name, categoryId, cents / 100, kind, addMonths(date, k),
            accountId: accountId, isCard: isCard, inst: k + 1, instTotal: n));
      }
    }
    month = DateTime(DateTime.now().year, DateTime.now().month);
    notifyListeners();
  }
}

Color kindColor(Kind k) => k == Kind.expense ? C.accent : C.green;
