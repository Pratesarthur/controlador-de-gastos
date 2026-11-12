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
  Category('salario', 'Salário', Icons.payments_outlined, Color(0xFF16A34A), Kind.income),
  Category('freela', 'Freelance', Icons.laptop_mac_rounded, Color(0xFF16A34A), Kind.income),
  Category('invest', 'Investimentos', Icons.trending_up_rounded, Color(0xFF16A34A), Kind.income),
];

Category categoryById(String id) => categories.firstWhere((c) => c.id == id);

class Txn {
  final int id;
  final String title, categoryId;
  final double amount; // always positive
  final Kind kind;
  final DateTime date;
  const Txn(this.id, this.title, this.categoryId, this.amount, this.kind, this.date);
  Category get category => categoryById(categoryId);
}

class Bill {
  final String name, due;
  final double amount;
  final IconData icon;
  const Bill(this.name, this.due, this.amount, this.icon);
}

const bills = [
  Bill('Aluguel', 'vence em 3 dias', 1850, Icons.home_outlined),
  Bill('Cartão de crédito', 'vence em 6 dias', 962.40, Icons.credit_card_rounded),
];

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

class Store extends ChangeNotifier {
  Store._() {
    final n = DateTime.now();
    DateTime day(int back) => DateTime(n.year, n.month, n.day).subtract(Duration(days: back));
    _items.addAll([
      Txn(1, 'Salário', 'salario', 6500, Kind.income, DateTime(n.year, n.month, 1)),
      Txn(2, 'Aluguel', 'moradia', 1850, Kind.expense, DateTime(n.year, n.month, 1)),
      Txn(3, 'Supermercado', 'mercado', 412.35, Kind.expense, day(1)),
      Txn(4, 'Uber', 'transporte', 38.90, Kind.expense, day(0)),
      Txn(5, 'Jantar com amigos', 'restaurantes', 126.50, Kind.expense, day(2)),
      Txn(6, 'Cinema', 'lazer', 64, Kind.expense, day(3)),
      Txn(7, 'Farmácia', 'saude', 89.9, Kind.expense, day(4)),
      Txn(8, 'Projeto freelance', 'freela', 800, Kind.income, day(5)),
      Txn(9, 'Feira', 'mercado', 96.75, Kind.expense, day(6)),
      Txn(10, 'Combustível', 'transporte', 210, Kind.expense, day(7)),
    ]);
    _items.removeWhere((t) => t.date.isAfter(n)); // early in the month: drop future-dated seeds
    _nextId = 100;
  }
  static final Store i = Store._();

  final List<Txn> _items = [];
  int _nextId = 100;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  double budget = 4000;

  bool get isCurrentMonth => month.year == DateTime.now().year && month.month == DateTime.now().month;

  void shiftMonth(int delta) {
    final m = DateTime(month.year, month.month + delta);
    final now = DateTime.now();
    if (m.isAfter(DateTime(now.year, now.month))) return;
    month = m;
    notifyListeners();
  }

  List<Txn> get monthItems {
    final l = _items.where((t) => t.date.year == month.year && t.date.month == month.month).toList()
      ..sort((a, b) => b.date != a.date ? b.date.compareTo(a.date) : b.id.compareTo(a.id));
    return l;
  }

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

  void add({required String title, required String categoryId, required double amount, required Kind kind}) {
    _items.add(Txn(_nextId++, title.isEmpty ? categoryById(categoryId).name : title, categoryId, amount, kind, DateTime.now()));
    month = DateTime(DateTime.now().year, DateTime.now().month);
    notifyListeners();
  }
}

Color kindColor(Kind k) => k == Kind.expense ? C.accent : C.green;
