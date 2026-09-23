import 'package:flutter/material.dart';

import '../theme/decor.dart';

/// LOOK-7: Saffron's one press ledge, wrapped around exactly three primary
/// actions ("أضف وصفة", "ابدأ الطبخ", cook mode's "التالي"). A solid strip
/// in [Decor.ledgeColor] sits [Decor.ledgeDepth] below the child, in the
/// child's own shape ([Decor.buttonShape]); pressing collapses it over 90ms
/// by sliding the child down onto it, so the button behaves like a key.
/// `Duration.zero` when [MediaQuery.disableAnimationsOf] is true. With
/// [Decor.ledgeDepth] 0 (Ink, and Saffron's own non-primary controls) this
/// renders [child] untouched — no ledge, no wrapper, no reserved space.
///
/// Wraps, never replaces, the child's semantics: everything here (a
/// [Listener], [Padding], [Stack], [AnimatedContainer]) sits outside the
/// child's own render/semantics subtree, so the button underneath is still
/// exactly one semantics node with its own label and action.
class PressableSlab extends StatefulWidget {
  const PressableSlab({super.key, required this.child});
  final Widget child;

  @override
  State<PressableSlab> createState() => _PressableSlabState();
}

class _PressableSlabState extends State<PressableSlab> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final decor = Decor.of(context);
    final depth = decor.ledgeDepth;
    if (depth <= 0) return widget.child; // Ink: flat, untouched (LOOK-7)

    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 90);

    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: Padding(
        // Reserves the ledge's own depth below the button, so the slab's
        // footprint never jumps as it collapses and un-collapses.
        padding: EdgeInsetsDirectional.only(bottom: depth),
        child: Stack(
          // A caller that stretches its child full-width (a ListView's
          // direct child, "ابدأ الطبخ"/"أضف وصفة") must still stretch the
          // button inside here: `passthrough` forwards the incoming
          // constraints straight to the button instead of loosening them
          // the way the default `loose` fit would.
          fit: StackFit.passthrough,
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(0, depth),
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: decor.ledgeColor,
                    shape: decor.buttonShape,
                  ),
                ),
              ),
            ),
            AnimatedContainer(
              duration: duration,
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(0, _pressed ? depth : 0, 0),
              child: widget.child,
            ),
          ],
        ),
      ),
    );
  }
}
