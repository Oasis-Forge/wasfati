import 'package:flutter/material.dart';

import '../theme/decor.dart';

/// LOOK-6: a white card floating on the linen page — 22dp radius, the light
/// shadow (`Decor.liftShadow`) or, in dark, a 1dp hairline edge
/// (`Decor.cardHairline`) instead. Material's own elevation tint is never
/// used.
///
/// [onTap], when set, wraps the padded content in a transparent [Material]
/// and an [InkWell] (should-fix): a plain [Container] has no `Material`
/// underneath it, so an `InkWell` nested straight inside one paints its
/// splash and its keyboard/switch-access focus highlight on whatever
/// `Material` is further up the tree — typically the `Scaffold`'s, under
/// this card's own opaque fill, where neither is ever visible. This only
/// helps when [child] doesn't itself paint something opaque over the whole
/// card (a full-bleed photo): that caller still needs its own ink layer
/// stacked above the photo.
///
/// design-styles.md, Motion #1: a tappable card also scales to 0.97 over
/// 120ms while pressed, skipped when [MediaQuery.disableAnimationsOf] is set
/// (a reduced-motion preference).
class SufraCard extends StatefulWidget {
  const SufraCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.radius = 22,
    this.clip = true,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// Defaults to `surfaceContainerLowest` (`card`).
  final Color? color;
  final double radius;
  final bool clip;
  final VoidCallback? onTap;

  @override
  State<SufraCard> createState() => _SufraCardState();
}

class _SufraCardState extends State<SufraCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final decor = Decor.of(context);
    final cs = Theme.of(context).colorScheme;
    Widget content = widget.padding != null
        ? Padding(padding: widget.padding!, child: widget.child)
        : widget.child;
    if (widget.onTap != null) {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(widget.radius),
          ),
          child: content,
        ),
      );
    }
    final card = Container(
      decoration: BoxDecoration(
        color: widget.color ?? cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(widget.radius),
        boxShadow: decor.liftShadow,
        border: decor.cardHairline != null
            ? Border.all(color: decor.cardHairline!)
            : null,
      ),
      clipBehavior: widget.clip ? Clip.antiAlias : Clip.none,
      child: content,
    );
    if (widget.onTap == null) return card;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 120),
      child: card,
    );
  }
}
