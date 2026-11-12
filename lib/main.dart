import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'add_sheet.dart';
import 'analytics_screen.dart';
import 'overview_screen.dart';
import 'projects_screen.dart';
import 'reports_screen.dart';
import 'theme.dart';
import 'widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));
  runApp(const FinanceApp());
}

class FinanceApp extends StatelessWidget {
  const FinanceApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Finanças',
        theme: buildTheme(),
        home: const Shell(),
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;
  bool _adding = false;

  static const items = [
    (Icons.home_rounded, 'Início'),
    (Icons.insights_rounded, 'Análises'),
    (Icons.receipt_long_rounded, 'Transações'),
    (Icons.flag_rounded, 'Metas'),
  ];

  Widget _screen() => switch (_tab) {
        0 => const HomeScreen(),
        1 => const AnalyticsScreen(),
        2 => const ReportsScreen(),
        _ => const ProjectsScreen(),
      };

  Future<void> _add() async {
    HapticFeedback.mediumImpact();
    setState(() => _adding = true);
    await showAddSheet(context);
    if (mounted) setState(() => _adding = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(children: [
          SafeArea(
            bottom: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Motion.curve,
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(a), child: child),
              ),
              child: KeyedSubtree(key: ValueKey(_tab), child: _screen()),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: _NavBar(
                index: _tab,
                adding: _adding,
                onTap: (i) {
                  HapticFeedback.selectionClick();
                  setState(() => _tab = i);
                },
                onAdd: _add,
              ),
            ),
          ),
        ]),
      );
}

class _NavBar extends StatelessWidget {
  final int index;
  final bool adding;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;
  const _NavBar({required this.index, required this.adding, required this.onTap, required this.onAdd});

  Widget _item(int i) {
    final sel = i == index;
    return Expanded(
      child: Pressable(
        onTap: () => onTap(i),
        child: SizedBox(
          height: 60,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            AnimatedScale(
              scale: sel ? 1.12 : 1,
              duration: Motion.base,
              curve: Motion.spring,
              child: Icon(_ShellState.items[i].$1, size: 22, color: sel ? C.ink : C.faint),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: Motion.fast,
              style: TextStyle(fontSize: 10.5, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, color: sel ? C.ink : C.faint),
              child: Text(_ShellState.items[i].$2),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: Motion.base,
              curve: Motion.curve,
              width: sel ? 14 : 0,
              height: 3,
              decoration: BoxDecoration(color: C.accent, borderRadius: BorderRadius.circular(2)),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
          Container(
            margin: const EdgeInsets.only(top: 22), // keeps the + button inside the hit-test area
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 24, offset: Offset(0, 8))],
            ),
            child: Row(children: [
              _item(0),
              _item(1),
              const SizedBox(width: 76), // room for the + button
              _item(2),
              _item(3),
            ]),
          ),
          Positioned(
            top: 0,
            child: Pressable(
              onTap: onAdd,
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: C.ink,
                  shape: BoxShape.circle,
                  border: Border.all(color: C.bg, width: 5),
                  boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6))],
                ),
                child: AnimatedRotation(
                  turns: adding ? 0.125 : 0,
                  duration: Motion.base,
                  curve: Motion.spring,
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
                ),
              ),
            ),
          ),
        ]),
      );
}
