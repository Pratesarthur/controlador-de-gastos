import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'categories.dart';
import 'theme.dart';

export 'categories.dart';

/// Simple in-memory store. Screens listen to it with ListenableBuilder.
/// Swap for a real repository (SQLite/Firebase) later without touching the UI much.

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
  final String? subId;
  final double amount; // always positive
  final Kind kind;
  final DateTime date;
  final String accountId; // account id, or card id when [isCard]
  final bool isCard;
  final int inst,
      instTotal; // installment / occurrence number and total (1/1 = single)
  final bool recurring; // monthly recurrence (instTotal = number of months)
  final int?
  group; // shared by every entry created together (installments / recurrence)
  const Txn(
    this.id,
    this.title,
    this.categoryId,
    this.amount,
    this.kind,
    this.date, {
    this.accountId = 'cc',
    this.isCard = false,
    this.inst = 1,
    this.instTotal = 1,
    this.subId,
    this.recurring = false,
    this.group,
  });
  Category get category => categoryById(categoryId);
  Sub? get sub => category.subById(subId);
  bool get isInstallment => instTotal > 1 && !recurring;
  bool get isSeries => instTotal > 1;

  Txn copyWith({
    String? title,
    String? categoryId,
    Object? subId = _keep,
    double? amount,
    Kind? kind,
    DateTime? date,
    String? accountId,
    bool? isCard,
  }) => Txn(
    id,
    title ?? this.title,
    categoryId ?? this.categoryId,
    amount ?? this.amount,
    kind ?? this.kind,
    date ?? this.date,
    accountId: accountId ?? this.accountId,
    isCard: isCard ?? this.isCard,
    inst: inst,
    instTotal: instTotal,
    subId: identical(subId, _keep) ? this.subId : subId as String?,
    recurring: recurring,
    group: group,
  );
}

const Object _keep = Object();

/// One purchase split into installments, summarised.
class Plan {
  final String title, categoryId, source;
  final bool isCard;
  final int count, paidCount;
  final double total, paid, perInstallment;
  final DateTime first, last;
  const Plan(
    this.title,
    this.categoryId,
    this.source,
    this.isCard,
    this.count,
    this.paidCount,
    this.total,
    this.paid,
    this.perInstallment,
    this.first,
    this.last,
  );
  bool get active => paidCount < count;
  double get remaining => total - paid;
  Category get category => categoryById(categoryId);
}

class Goal {
  final String id, name;
  final String? label; // fixed text shown instead of the deadline (demo goals)
  final double target, base; // base = amount already saved when the goal was created
  final DateTime? due;
  final IconData icon;
  double saved; // base + deposits - withdrawals (kept in sync by the Store)
  Goal(this.id, this.name, this.target, this.base, this.icon, {this.due, this.label}) : saved = base;
  String get deadline => label ?? (due == null ? 'sem prazo' : 'até ${monthShort[due!.month - 1]} ${due!.year}');
  double get progress => target <= 0 ? 0 : (saved / target).clamp(0.0, 1.0);
  bool get done => saved >= target;
}

/// Local-only profile (nothing leaves the device).
class Profile {
  String name = 'Usuário';
  String email = '';
  Uint8List? photo;
}

const monthNames = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];
const monthShort = [
  'jan',
  'fev',
  'mar',
  'abr',
  'mai',
  'jun',
  'jul',
  'ago',
  'set',
  'out',
  'nov',
  'dez',
];

String dayLabel(DateTime d) {
  final n = DateTime.now();
  final diff = DateTime(
    n.year,
    n.month,
    n.day,
  ).difference(DateTime(d.year, d.month, d.day)).inDays;
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
    goalSubsProvider = () => [for (final g in goals) Sub(g.id, g.name)];
    final n = DateTime.now();
    DateTime day(int back) =>
        DateTime(n.year, n.month, n.day).subtract(Duration(days: back));
    final closing =
        (n.day + 7) % 28 + 1; // keeps the demo cycle containing recent days
    accounts.addAll([
      Account('cc', 'Conta Corrente', 3000),
      Account('poup', 'Poupança', 5200),
    ]);
    cards.addAll([
      CardAcct('card1', 'Cartão Platinum', closing, 8000),
      CardAcct('card2', 'Cartão Virtual', 20, 2500),
    ]);
    favAccountId = 'cc';
    favCardId = 'card1';
    _items.addAll([
      Txn(
        1,
        'Salário',
        'salario',
        6500,
        Kind.income,
        DateTime(n.year, n.month, 1),
      ),
      Txn(
        2,
        'Aluguel',
        'moradia',
        1850,
        Kind.expense,
        DateTime(n.year, n.month, 1),
      ),
      Txn(
        3,
        'Supermercado',
        'alimentacao',
        412.35,
        Kind.expense,
        day(1),
        subId: 'mercado',
      ),
      Txn(
        4,
        'Uber',
        'transporte',
        38.90,
        Kind.expense,
        day(0),
        accountId: 'card1',
        isCard: true,
      ),
      Txn(
        5,
        'Jantar com amigos',
        'alimentacao',
        126.50,
        Kind.expense,
        day(2),
        subId: 'restaurantes',
        accountId: 'card1',
        isCard: true,
      ),
      Txn(
        6,
        'Cinema',
        'lazer',
        64,
        Kind.expense,
        day(3),
        accountId: 'card1',
        isCard: true,
      ),
      Txn(7, 'Farmácia', 'saude', 89.9, Kind.expense, day(4)),
      Txn(8, 'Projeto freelance', 'freela', 800, Kind.income, day(5)),
      Txn(
        9,
        'Feira',
        'alimentacao',
        96.75,
        Kind.expense,
        day(6),
        subId: 'mercado',
      ),
      Txn(
        10,
        'Combustível',
        'transporte',
        210,
        Kind.expense,
        day(7),
        accountId: 'card1',
        isCard: true,
      ),
    ]);
    _items.removeWhere(
      (t) => t.date.isAfter(n),
    ); // early in the month: drop future-dated seeds
    // history for the previous 5 months (feeds Análises)
    const extra = [350.0, 120.0, 540.0, 80.0, 260.0];
    const food = [980.0, 1120.0, 870.0, 1040.0, 930.0];
    for (var k = 1; k <= 5; k++) {
      final id = 100 + k * 10;
      _items.addAll([
        Txn(
          id,
          'Salário',
          'salario',
          6500,
          Kind.income,
          DateTime(n.year, n.month - k, 1),
        ),
        if (k.isEven)
          Txn(
            id + 1,
            'Projeto freelance',
            'freela',
            900.0 + k * 60,
            Kind.income,
            DateTime(n.year, n.month - k, 12),
          ),
        Txn(
          id + 2,
          'Aluguel',
          'moradia',
          1850,
          Kind.expense,
          DateTime(n.year, n.month - k, 1),
        ),
        Txn(
          id + 3,
          'Mercado',
          'alimentacao',
          food[k - 1],
          Kind.expense,
          DateTime(n.year, n.month - k, 9),
          subId: 'mercado',
        ),
        Txn(
          id + 4,
          'Lazer e restaurantes',
          'lazer',
          extra[k - 1] + 400,
          Kind.expense,
          DateTime(n.year, n.month - k, 18),
          accountId: 'card1',
          isCard: true,
        ),
        Txn(
          id + 5,
          'Transporte',
          'transporte',
          300.0 + k * 25,
          Kind.expense,
          DateTime(n.year, n.month - k, 22),
          accountId: 'card1',
          isCard: true,
        ),
      ]);
    }
    _nextId = 1000;
    // demo installments + a recurring subscription (feeds Análises ▸ Parcelas)
    final base = DateTime(n.year, n.month, 5);
    _create(
      title: 'Notebook',
      categoryId: 'compras',
      subId: 'eletronicos',
      amount: 4200,
      kind: Kind.expense,
      date: addMonths(base, -3),
      accountId: 'card1',
      isCard: true,
      count: 10,
    );
    _create(
      title: 'Geladeira',
      categoryId: 'compras',
      subId: 'casa',
      amount: 3000,
      kind: Kind.expense,
      date: addMonths(base, -1),
      accountId: 'card1',
      isCard: true,
      count: 6,
    );
    _create(
      title: 'Curso de inglês',
      categoryId: 'educacao',
      subId: 'cursos',
      amount: 2400,
      kind: Kind.expense,
      date: base,
      accountId: 'card2',
      isCard: true,
      count: 12,
    );
    _create(
      title: 'Streaming',
      categoryId: 'assinaturas',
      subId: 'streaming',
      amount: 39.9,
      kind: Kind.expense,
      date: addMonths(base, -2),
      accountId: 'card2',
      isCard: true,
      count: 24,
      recurring: true,
    );
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
    Goal('g1', 'Reserva de emergência', 12000, 7800, Icons.shield_outlined, label: 'até dez 2027'),
    Goal('g2', 'Viagem de férias', 5000, 2150, Icons.flight_takeoff_rounded, label: 'até jul 2027'),
    Goal('g3', 'Notebook novo', 4500, 4500, Icons.laptop_mac_rounded, label: 'concluída'),
    Goal('g4', 'Entrada do apartamento', 60000, 9400, Icons.home_outlined, label: 'até 2030'),
  ];

  final Profile profile = Profile();
  bool signedIn = true;
  String? password; // local lock only; null = no password set

  @override
  void notifyListeners() {
    _syncGoals();
    super.notifyListeners();
  }

  void _syncGoals() {
    for (final g in goals) {
      var v = g.base;
      for (final t in _items) {
        if (t.subId != g.id) continue;
        if (t.categoryId == 'metas') v += t.amount;
        if (t.categoryId == 'metas_ret') v -= t.amount;
      }
      g.saved = max(0, v);
    }
  }

  void addGoal(String name, double target, DateTime? due, IconData icon, double initial) {
    goals.add(Goal('g${_nextId++}', name, target, initial, icon, due: due));
    notifyListeners();
  }

  void removeGoal(Goal g) {
    goals.remove(g);
    notifyListeners();
  }

  void signOut() {
    signedIn = false;
    notifyListeners();
  }

  /// Returns false when a password is set and [pass] does not match.
  bool signIn(String pass) {
    if (password != null && pass != password) return false;
    signedIn = true;
    notifyListeners();
    return true;
  }

  /// Returns an error message, or null on success.
  String? changePassword(String current, String next) {
    if (password != null && current != password) return 'Senha atual incorreta';
    if (next.length < 6) return 'A nova senha precisa ter ao menos 6 caracteres';
    password = next;
    notifyListeners();
    return null;
  }

  void updateProfile({String? name, String? email, Object? photo = _keep}) {
    if (name != null) profile.name = name;
    if (email != null) profile.email = email;
    if (!identical(photo, _keep)) profile.photo = photo as Uint8List?;
    notifyListeners();
  }


  // ------------------------------------------------------------ accounts & cards

  Account get favAccount => accounts.firstWhere(
    (a) => a.id == favAccountId,
    orElse: () => accounts.first,
  );
  CardAcct? get favCard {
    if (cards.isEmpty) return null;
    return cards.firstWhere(
      (c) => c.id == favCardId,
      orElse: () => cards.first,
    );
  }

  String sourceName(Txn t) {
    final l = t.isCard
        ? cards.where((c) => c.id == t.accountId)
        : accounts.where((a) => a.id == t.accountId);
    if (l.isEmpty) return t.isCard ? 'Cartão' : 'Conta';
    return l.first is CardAcct
        ? (l.first as CardAcct).name
        : (l.first as Account).name;
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

  double get totalAvailable =>
      accounts.fold(0.0, (s, a) => s + accountBalance(a));

  Cycle cycleOf(CardAcct c) {
    final today = _day(DateTime.now());
    final end = today.day <= c.closingDay
        ? DateTime(today.year, today.month, c.closingDay)
        : DateTime(today.year, today.month + 1, c.closingDay);
    final start = DateTime(end.year, end.month - 1, c.closingDay + 1);
    final spent = _items
        .where(
          (t) =>
              t.isCard &&
              t.accountId == c.id &&
              t.kind == Kind.expense &&
              !t.date.isBefore(start) &&
              !t.date.isAfter(end),
        )
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

  bool get isCurrentMonth =>
      month.year == DateTime.now().year && month.month == DateTime.now().month;

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

  /// Jumps straight to [m] (clamped to the last month that has data).
  void setMonth(DateTime m) {
    var t = DateTime(m.year, m.month);
    if (t.isAfter(lastMonth)) t = lastMonth;
    month = t;
    notifyListeners();
  }

  void shiftMonth(int delta) {
    final m = DateTime(month.year, month.month + delta);
    if (m.isAfter(lastMonth)) return;
    month = m;
    notifyListeners();
  }

  List<Txn> get monthItems => monthItemsFor(month);

  List<Txn> monthItemsFor(DateTime m) =>
      _items
          .where((t) => t.date.year == m.year && t.date.month == m.month)
          .toList()
        ..sort(
          (a, b) => b.date != a.date
              ? b.date.compareTo(a.date)
              : b.id.compareTo(a.id),
        );

  double get income => monthItems
      .where((t) => t.kind == Kind.income)
      .fold(0.0, (s, t) => s + t.amount);
  double get expense => monthItems
      .where((t) => t.kind == Kind.expense)
      .fold(0.0, (s, t) => s + t.amount);
  double get balance => income - expense;

  /// total per category for [kind] in the selected month, largest first
  List<(Category, double)> get byCategory => catTotals(month, Kind.expense);

  /// total per category for [kind] in month [m], largest first
  List<(Category, double)> catTotals(DateTime m, Kind kind) {
    final r = <String, double>{};
    for (final t in monthItemsFor(m).where((t) => t.kind == kind)) {
      r[t.categoryId] = (r[t.categoryId] ?? 0) + t.amount;
    }
    return r.entries.map((e) => (categoryById(e.key), e.value)).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
  }

  /// total per (category, subcategory) for [kind] in month [m], largest first
  List<(Category, Sub?, double)> subTotals(DateTime m, Kind kind) {
    final r = <String, double>{};
    for (final t in monthItemsFor(m).where((t) => t.kind == kind)) {
      final k = '${t.categoryId}|${t.subId ?? ''}';
      r[k] = (r[k] ?? 0) + t.amount;
    }
    return r.entries.map((e) {
      final p = e.key.split('|');
      final c = categoryById(p[0]);
      return (c, c.subById(p[1].isEmpty ? null : p[1]), e.value);
    }).toList()..sort((a, b) => b.$3.compareTo(a.$3));
  }

  /// Per-category totals for the last [n] months (ending at the current month), oldest first.
  List<(DateTime, Map<String, double>)> monthlyByCategory(int n, Kind kind) {
    final now = DateTime.now();
    return [
      for (var k = n - 1; k >= 0; k--)
        () {
          final m = DateTime(now.year, now.month - k);
          final r = <String, double>{};
          for (final t in monthItemsFor(m).where((t) => t.kind == kind)) {
            r[t.categoryId] = (r[t.categoryId] ?? 0) + t.amount;
          }
          return (m, r);
        }(),
    ];
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
      (monthItems.where((t) => t.kind == Kind.expense).toList()
            ..sort((a, b) => b.amount.compareTo(a.amount)))
          .take(n)
          .toList();

  /// Every installment purchase (not recurring), summarised.
  List<Plan> get plans {
    final now = DateTime.now();
    final g = <int, List<Txn>>{};
    for (final t in _items.where(
      (t) => t.isInstallment && t.kind == Kind.expense && t.group != null,
    )) {
      g.putIfAbsent(t.group!, () => []).add(t);
    }
    return g.values.map((l) {
      l.sort((a, b) => a.date.compareTo(b.date));
      final total = l.fold(0.0, (a, t) => a + t.amount);
      final paidL = l.where((t) => !t.date.isAfter(now));
      final paid = paidL.fold(0.0, (a, t) => a + t.amount);
      return Plan(
        l.first.title,
        l.first.categoryId,
        sourceName(l.first),
        l.first.isCard,
        l.length,
        paidL.length,
        total,
        paid,
        l.first.amount,
        l.first.date,
        l.last.date,
      );
    }).toList()..sort((a, b) => a.last.compareTo(b.last));
  }

  /// Sum of installments per month, from the current month up to the last pending one.
  List<(DateTime, double)> installmentHorizon() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month);
    final active = <int>{
      for (final p in _items.where(
        (t) => t.isInstallment && t.group != null && t.date.isAfter(now),
      ))
        p.group!,
    };
    final sums = <DateTime, double>{};
    for (final t in _items.where(
      (t) =>
          t.isInstallment && t.kind == Kind.expense && active.contains(t.group),
    )) {
      final m = DateTime(t.date.year, t.date.month);
      if (m.isBefore(start)) continue;
      sums[m] = (sums[m] ?? 0) + t.amount;
    }
    if (sums.isEmpty) return [];
    final last = sums.keys.reduce((a, b) => a.isAfter(b) ? a : b);
    final out = <(DateTime, double)>[];
    for (var m = start; !m.isAfter(last); m = DateTime(m.year, m.month + 1)) {
      out.add((m, sums[m] ?? 0));
    }
    return out;
  }

  /// installments still to be charged after today
  double get futureInstallments => _items
      .where(
        (t) =>
            t.isInstallment &&
            t.kind == Kind.expense &&
            t.date.isAfter(DateTime.now()),
      )
      .fold(0.0, (s, t) => s + t.amount);

  /// Income/expense totals for the last [n] months, oldest first (ending at the current month).
  List<(DateTime, double, double)> monthlyTotals(int n) {
    final now = DateTime.now();
    return [
      for (var k = n - 1; k >= 0; k--)
        () {
          final m = DateTime(now.year, now.month - k);
          final l = _items.where(
            (t) => t.date.year == m.year && t.date.month == m.month,
          );
          double sum(Kind kd) =>
              l.where((t) => t.kind == kd).fold(0.0, (s, t) => s + t.amount);
          return (m, sum(Kind.income), sum(Kind.expense));
        }(),
    ];
  }

  /// Deposits [v] into goal [g] from the favourite account (recorded as a transaction).
  void contribute(Goal g, double v) => add(
        title: 'Aporte: ${g.name}',
        categoryId: 'metas',
        subId: g.id,
        amount: v,
        kind: Kind.expense,
        date: DateTime.now(),
        accountId: favAccountId,
      );

  // ------------------------------------------------------------ adding / editing

  /// Creates the entries without notifying. For [count] > 1 one entry is created per month.
  /// Installments: when [amountIsTotal] the total is split (the last one absorbs the rounding),
  /// otherwise [amount] is the value of each one. Recurring entries always repeat [amount].
  void _create({
    required String title,
    required String categoryId,
    String? subId,
    required double amount,
    required Kind kind,
    required DateTime date,
    required String accountId,
    bool isCard = false,
    int count = 1,
    bool amountIsTotal = true,
    bool recurring = false,
  }) {
    final cat = categoryById(categoryId);
    final name = title.isEmpty ? (cat.subById(subId)?.name ?? cat.name) : title;
    final n = max(1, min(count, maxInstallments));
    if (n == 1) {
      _items.add(
        Txn(
          _nextId++,
          name,
          categoryId,
          amount,
          kind,
          date,
          accountId: accountId,
          isCard: isCard,
          subId: subId,
        ),
      );
      return;
    }
    final split = amountIsTotal && !recurring;
    final totalCents = (amount * 100).round() * (split ? 1 : n);
    final perCents = split ? totalCents ~/ n : (amount * 100).round();
    final group = _nextId;
    for (var k = 0; k < n; k++) {
      final cents = (split && k == n - 1)
          ? totalCents - perCents * (n - 1)
          : perCents;
      _items.add(
        Txn(
          _nextId++,
          name,
          categoryId,
          cents / 100,
          kind,
          addMonths(date, k),
          accountId: accountId,
          isCard: isCard,
          inst: k + 1,
          instTotal: n,
          subId: subId,
          recurring: recurring,
          group: group,
        ),
      );
    }
  }

  void add({
    required String title,
    required String categoryId,
    String? subId,
    required double amount,
    required Kind kind,
    required DateTime date,
    required String accountId,
    bool isCard = false,
    int installments = 1,
    bool amountIsTotal = true,
    bool recurring = false,
  }) {
    _create(
      title: title,
      categoryId: categoryId,
      subId: subId,
      amount: amount,
      kind: kind,
      date: date,
      accountId: accountId,
      isCard: isCard,
      count: installments,
      amountIsTotal: amountIsTotal,
      recurring: recurring,
    );
    month = DateTime(DateTime.now().year, DateTime.now().month);
    notifyListeners();
  }

  Txn? byId(int id) {
    for (final t in _items) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Entries of the same series as [t] from [t] onward (just [t] when it is not part of a series).
  List<Txn> _scope(Txn t, bool following) => (following && t.group != null)
      ? _items.where((e) => e.group == t.group && e.inst >= t.inst).toList()
      : [t];

  /// How many entries a "this and the next ones" change would touch.
  int followingCount(Txn t) => _scope(t, true).length;

  /// Replaces [updated] (matched by id). With [following], the same fields are applied to the next
  /// entries of its series too; the date moves them month by month.
  void update(Txn updated, {bool following = false}) {
    final old = byId(updated.id);
    if (old == null) return;
    for (final e in _scope(old, following)) {
      final i = _items.indexWhere((x) => x.id == e.id);
      final date = updated.date == old.date
          ? e.date
          : addMonths(updated.date, e.inst - old.inst);
      _items[i] = e.copyWith(
        title: updated.title,
        categoryId: updated.categoryId,
        subId: updated.subId,
        amount: updated.amount,
        kind: updated.kind,
        date: date,
        accountId: updated.accountId,
        isCard: updated.isCard,
      );
    }
    notifyListeners();
  }

  void remove(Txn t, {bool following = false}) {
    final ids = _scope(t, following).map((e) => e.id).toSet();
    _items.removeWhere((e) => ids.contains(e.id));
    if (month.isAfter(lastMonth)) month = lastMonth;
    notifyListeners();
  }

  /// Copies a single entry to today.
  void duplicate(Txn t) {
    final n = DateTime.now();
    _items.add(
      Txn(
        _nextId++,
        t.title,
        t.categoryId,
        t.amount,
        t.kind,
        DateTime(n.year, n.month, n.day),
        accountId: t.accountId,
        isCard: t.isCard,
        subId: t.subId,
      ),
    );
    notifyListeners();
  }
}

/// Maximum number of installments / monthly repetitions.
const maxInstallments = 120;

Color kindColor(Kind k) => k == Kind.expense ? C.accent : C.green;
