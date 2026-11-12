import 'dart:math';
import 'package:flutter/material.dart';
import 'theme.dart';

/// Mock data. Replace with your repository / API layer later.

const people = <(String, Color)>[
  ('AK', Color(0xFFFF6B3D)),
  ('L', Color(0xFFE9E9EC)),
  ('JM', Color(0xFF1B1B1D)),
  ('M', Color(0xFFFF4D0D)),
  ('TS', Color(0xFF8FB0E8)),
];

class OverdueInvoice {
  final String client, ref, late;
  final double amount;
  final Color color;
  const OverdueInvoice(this.client, this.ref, this.late, this.amount, this.color);
}

const overdue = [
  OverdueInvoice('Kite Health', '#1042', '12 days late', 2140, Color(0xFF8FB0E8)),
  OverdueInvoice('Mono Labs', '#1047', '8 days late', 1872, Color(0xFF1B1B1D)),
  OverdueInvoice('Northwind Labs', '#1051', '3 days late', 800, Color(0xFFD9A37A)),
];

const sparkline = <double>[3, 4, 3.5, 5, 4.6, 6, 5.4, 7, 6.2, 8, 7.4, 9.5, 9];

class Activity {
  final String who, what, time, tag;
  final Color color;
  const Activity(this.who, this.what, this.time, this.tag, this.color);
}

const activity = [
  Activity('Aylin K.', 'approved Brand Refresh billing', '2m ago', 'Approved', Color(0xFFFF6B3D)),
  Activity('Jonas M.', 'sent Q3 revenue summary', '1h ago', 'Sent', Color(0xFF1B1B1D)),
];

class RangeSpec {
  final String label, sub;
  final double headline;
  final String delta;
  final int n;
  final List<String> axis;
  final int seed;
  final double trend;
  const RangeSpec(this.label, this.headline, this.delta, this.sub, this.n, this.axis, this.seed, this.trend);

  List<double> get values {
    final r = Random(seed);
    return List.generate(n, (i) {
      final wave = 0.75 + 0.25 * sin(i / 2.2);
      return (5200 + 5200 * r.nextDouble() * wave + trend * 4200 * i / n).clamp(800, 15200).toDouble();
    });
  }

  List<double> get movingAvg => List.generate(n, (i) {
        final v = values;
        final from = max(0, i - 6);
        return v.sublist(from, i + 1).reduce((a, b) => a + b) / (i + 1 - from);
      });
}

const ranges = [
  RangeSpec('7D', 61800, '+6.3%', '\$8.8k avg/day · Saturday payout', 7,
      ['Sun', 'Wed', 'Sat'], 7, 0.2),
  RangeSpec('30D', 248900, '+18.2%', '\$8.0k avg/day · best Oct 15', 31,
      ['Oct 1', 'Oct 8', 'Oct 15', 'Oct 22', 'Oct 31'], 30, 0.3),
  RangeSpec('90D', 712400, '+11.6%', '\$7.9k avg/day · vs \$638.1k prior 90D', 45,
      ['Aug 3', 'Aug 24', 'Sep 14', 'Oct 5', 'Oct 31'], 90, 0.6),
  RangeSpec('1Y', 2610000, '+24.1%', 'Best month October · slowest January', 12,
      ['Nov', 'Feb', 'May', 'Aug', 'Oct'], 365, 1.2),
];

const cashFlow = <double>[4.2, -1.8, 3.1, 5.6, -2.4, 6.2, 4.8, 7.1];

enum ProjectState { active, completed, archived }

class Project {
  final String name, client, tag;
  final double spent, budget;
  final ProjectState state;
  final IconData icon;
  final List<(String, Color)> team;
  const Project(this.name, this.client, this.spent, this.budget, this.state, this.tag, this.icon, this.team);
  double get progress => spent / budget;
}

final projects = <Project>[
  Project('Payroll automation', 'Northwind HR', 18700, 22000, ProjectState.active, 'Due Nov 5', Icons.groups_2_outlined, people.sublist(0, 3)),
  Project('Brand Refresh', 'Fieldwork Studio', 24500, 36000, ProjectState.active, 'Due Nov 8', Icons.star_border_rounded, people.sublist(2, 4)),
  Project('Atlas billing migration', 'Kite Health', 9800, 40000, ProjectState.active, 'Due Nov 19', Icons.sync_alt_rounded, people.sublist(1, 3)),
  Project('Website relaunch', 'Kite Health', 31200, 32000, ProjectState.completed, 'Done Oct 28', Icons.web_asset_rounded, people.sublist(0, 3)),
  Project('Stripe migration', 'maydin.co', 14800, 15000, ProjectState.completed, 'Done Oct 19', Icons.account_balance_wallet_outlined, people.sublist(0, 2)),
  Project('Vendor audit 2026', 'Mono Labs', 12000, 12000, ProjectState.completed, 'Done Oct 11', Icons.fact_check_outlined, people.sublist(3, 5)),
  Project('Holiday campaign', 'Fieldwork Studio', 8200, 20000, ProjectState.archived, 'Archived Aug 14', Icons.star_border_rounded, people.sublist(1, 3)),
  Project('Legacy invoicing', 'Northwind Labs', 21600, 30000, ProjectState.archived, 'Archived Jul 2', Icons.folder_outlined, people.sublist(0, 3)),
];

enum ReportStatus { paid, pending, overdue }

class Report {
  final String title, sub;
  final double amount;
  final ReportStatus status;
  final IconData icon;
  const Report(this.title, this.sub, this.amount, this.status, this.icon);
}

const reports = <Report>[
  Report('Q3 revenue summary', 'Ledgerly · Oct 31', 48920, ReportStatus.paid, Icons.pie_chart_outline_rounded),
  Report('Payroll reconciliation', 'Northwind HR · Oct 30', 112400, ReportStatus.pending, Icons.groups_2_outlined),
  Report('Stripe payouts — October', 'maydin.co · Oct 29', 31276.50, ReportStatus.paid, Icons.account_balance_wallet_outlined),
  Report('Refunds & disputes', 'Kite Health · Oct 27', 4812, ReportStatus.overdue, Icons.undo_rounded),
  Report('Vendor spend audit', 'Mono Labs · Oct 26', 9305.75, ReportStatus.pending, Icons.grid_view_rounded),
  Report('Brand Refresh billing', 'Fieldwork Studio · Oct 24', 22500, ReportStatus.pending, Icons.star_border_rounded),
  Report('Small expenses', 'Northwind Labs · Oct 20', 640, ReportStatus.paid, Icons.receipt_long_outlined),
];

Color statusFg(ReportStatus s) =>
    switch (s) { ReportStatus.paid => C.green, ReportStatus.pending => C.amber, ReportStatus.overdue => C.accent };
Color statusBg(ReportStatus s) => switch (s) {
      ReportStatus.paid => C.greenBg,
      ReportStatus.pending => C.amberBg,
      ReportStatus.overdue => const Color(0xFFFFE9E0)
    };
String statusLabel(ReportStatus s) => switch (s) {
      ReportStatus.paid => 'Paid',
      ReportStatus.pending => 'Pending',
      ReportStatus.overdue => 'Overdue'
    };
