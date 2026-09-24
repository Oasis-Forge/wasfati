import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recipe_import.dart';
import '../screens/import_screen.dart';
import '../services/web_import.dart';

/// Routes shares from other apps (IMP-1): a link goes to import (IMP-2,
/// IMP-3); plain text goes to AI import (IMP-3), with the offline heuristic
/// (IMP-13) only as "أضفها بنفسك" if that fails. The same share arriving
/// twice within 10 seconds is ignored, and each share is reset once
/// handled (the plugin's duplicate and stale-share traps, S4).
class ShareRouter extends StatefulWidget {
  const ShareRouter({super.key, required this.navigator, required this.child});

  final GlobalKey<NavigatorState> navigator;
  final Widget child;

  @override
  State<ShareRouter> createState() => _ShareRouterState();
}

class _ShareRouterState extends State<ShareRouter> {
  StreamSubscription<String>? _sub;
  String? _last;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    final inbox = context.read<ShareInbox>();
    _sub = inbox.incoming.listen(_handle);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final first = await inbox.initial();
      if (first != null) await _handle(first);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _handle(String text) async {
    final inbox = context.read<ShareInbox>();
    final now = DateTime.now();
    if (text == _last &&
        now.difference(_lastAt) < const Duration(seconds: 10)) {
      return;
    }
    _last = text;
    _lastAt = now;
    await inbox.reset();

    final nav = widget.navigator.currentState;
    if (nav == null) return;
    final url = findUrl(text);
    await nav.push(
      MaterialPageRoute<void>(
        builder: (_) => url != null
            ? ImportScreen(initialUrl: url)
            : ImportScreen(initialText: text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
