import 'dart:async';
import 'package:flutter/material.dart';
import 'theme.dart';

String money(double v, {int dec = 0}) {
  final parts = v.toStringAsFixed(dec).split('.');
  final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return '\$$whole${dec > 0 ? '.${parts[1]}' : ''}';
}

/// Brazilian format: R$ 1.234,56
String brl(double v, {int dec = 2}) {
  final parts = v.abs().toStringAsFixed(dec).split('.');
  final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
  return '${v < 0 ? '-' : ''}R\$ $whole${dec > 0 ? ',${parts[1]}' : ''}';
}

String compact(double v) =>
    v >= 1e6 ? '\$${(v / 1e6).toStringAsFixed(2)}M' : '\$${(v / 1e3).toStringAsFixed(1)}k';

/// Text whose decimal part is greyed out, like "$86,420.18".
class SplitText extends StatelessWidget {
  final String text;
  final TextStyle style;
  const SplitText(this.text, {super.key, this.style = T.big});
  @override
  Widget build(BuildContext context) {
    final s = style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    // pt-BR "R$ 1.234,56" → grey out ",56"; otherwise grey out ".9k" style decimals
    final i = RegExp(r',\d{2}$').hasMatch(text) ? text.lastIndexOf(',') : text.indexOf('.');
    if (i < 0) return Text(text, style: s);
    return Text.rich(TextSpan(text: text.substring(0, i), style: s, children: [
      TextSpan(text: text.substring(i), style: s.copyWith(color: C.faint)),
    ]));
  }
}

/// Counts up from 0 on first build and tweens between values afterwards.
class AnimatedAmount extends StatelessWidget {
  final double value;
  final String Function(double) format;
  final TextStyle style;
  const AnimatedAmount(this.value, {super.key, required this.format, this.style = T.big});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value),
        duration: const Duration(milliseconds: 900),
        curve: Motion.curve,
        builder: (_, v, _) => SplitText(format(v), style: style),
      );
}

/// Scales down slightly while pressed.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const Pressable({super.key, required this.child, this.onTap});
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
            scale: _down ? 0.95 : 1, duration: const Duration(milliseconds: 120), child: widget.child),
      );
}

/// Fade + rise entrance, staggered by [index].
class Reveal extends StatefulWidget {
  final Widget child;
  final int index;
  const Reveal({super.key, required this.child, this.index = 0});
  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Motion.curve);
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer(Duration(milliseconds: 55 * widget.index), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _a,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(_a),
          child: widget.child,
        ),
      );
}

class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const SoftCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: C.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 18, offset: Offset(0, 6))],
        ),
        child: child,
      );
}

/// Thin animated progress bar (value 0..1).
class ProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  final double height;
  const ProgressBar(this.value, this.color, {super.key, this.height = 5});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Container(
          height: height,
          color: C.track,
          alignment: Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => FractionallySizedBox(
                widthFactor: v,
                child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)))),
          ),
        ),
      );
}

class Pill extends StatelessWidget {
  final String text;
  final Color fg, bg;
  const Pill(this.text, {super.key, required this.fg, required this.bg});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: fg)),
      );
}

class Avatar extends StatelessWidget {
  final String initials;
  final Color color;
  final double size;
  const Avatar(this.initials, this.color, {super.key, this.size = 24});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
        child: Text(initials,
            style: TextStyle(
                fontSize: size * 0.36,
                fontWeight: FontWeight.w700,
                color: color.computeLuminance() > 0.6 ? C.ink : Colors.white)),
      );
}

class AvatarStack extends StatelessWidget {
  final List<(String, Color)> people;
  const AvatarStack(this.people, {super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 24,
        width: 24.0 + (people.length - 1) * 16,
        child: Stack(children: [
          for (var i = 0; i < people.length; i++)
            Positioned(left: i * 16.0, child: Avatar(people[i].$1, people[i].$2)),
        ]),
      );
}

/// Segmented control with a thumb that slides between options.
class SegmentedPill extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  const SegmentedPill({super.key, required this.labels, required this.index, required this.onChanged});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, b) {
        final seg = (b.maxWidth - 8) / labels.length;
        return Container(
          height: 38,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: C.track, borderRadius: BorderRadius.circular(13)),
          child: Stack(children: [
            AnimatedPositioned(
              duration: Motion.base,
              curve: Curves.easeOutQuart,
              left: seg * index,
              top: 0,
              bottom: 0,
              width: seg,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))],
                ),
              ),
            ),
            Row(children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(i),
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: Motion.fast,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                            color: i == index ? C.ink : C.muted),
                        child: Text(labels[i]),
                      ),
                    ),
                  ),
                ),
            ]),
          ]),
        );
      });
}

class RoundIcon extends StatelessWidget {
  final IconData icon;
  final bool dot;
  final VoidCallback? onTap;
  const RoundIcon(this.icon, {super.key, this.dot = false, this.onTap});
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(icon, size: 17, color: C.ink),
          ),
          if (dot)
            Positioned(
                right: 2,
                top: 2,
                child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: C.accent, shape: BoxShape.circle, border: Border.all(color: C.bg, width: 1.5)))),
        ]),
      );
}

class AppHeader extends StatelessWidget {
  final String title, subtitle;
  const AppHeader(this.title, this.subtitle, {super.key});
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: T.title),
            const SizedBox(height: 2),
            Text(subtitle, style: T.sub),
          ]),
        ),
        const RoundIcon(Icons.notifications_none_rounded, dot: true),
        const SizedBox(width: 8),
        const RoundIcon(Icons.add_rounded),
      ]);
}

/// Standard scrolling screen: header + children, with room for the nav bar.
class ScreenList extends StatelessWidget {
  final String title, subtitle;
  final List<Widget> children;
  const ScreenList({super.key, required this.title, required this.subtitle, required this.children});
  @override
  Widget build(BuildContext context) => ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [Reveal(child: AppHeader(title, subtitle)), const SizedBox(height: 16), ...children],
      );
}
