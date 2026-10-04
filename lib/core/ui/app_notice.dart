import 'dart:async';

import 'package:flutter/material.dart';

enum AppNoticeType { success, error, info }

/// Shows success, error and information messages in the centre of the screen.
///
/// The message appears in a small card over a dimmed background and goes away
/// on its own after a few seconds, when the user taps anywhere outside the
/// card, or when they press its close button — whichever comes first.
///
/// A [SnackBar] belongs to a [ScaffoldMessenger], so it sits at the bottom and
/// can be hidden behind a dialog. This notice is inserted into the root
/// overlay instead, so it is always on top and survives a page change.
abstract final class AppNotice {
  static OverlayEntry? _current;
  static Timer? _timer;

  static void success(BuildContext context, String message) => show(
        context,
        message: message,
        type: AppNoticeType.success,
      );

  static void error(BuildContext context, Object error) => show(
        context,
        message: _message(error),
        type: AppNoticeType.error,
        duration: const Duration(seconds: 6),
      );

  static void info(BuildContext context, String message) => show(
        context,
        message: message,
        type: AppNoticeType.info,
      );

  static void show(
    BuildContext context, {
    required String message,
    required AppNoticeType type,
    Duration duration = const Duration(seconds: 4),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    dismiss();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _Notice(
        message: message,
        type: type,
        onDismiss: () => _remove(entry),
      ),
    );
    _current = entry;
    overlay.insert(entry);
    _timer = Timer(duration, () => _remove(entry));
  }

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    final entry = _current;
    _current = null;
    if (entry?.mounted ?? false) entry!.remove();
  }

  static void _remove(OverlayEntry entry) {
    if (!identical(_current, entry)) return;
    dismiss();
  }

  static String _message(Object error) {
    final value = error.toString().trim();
    return value
        .replaceFirst(RegExp(r'^(Exception|Error):\s*'), '')
        .replaceFirst(RegExp(r'^[A-Za-z]+Exception:\s*'), '');
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  final String message;
  final AppNoticeType type;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (accent, icon, title) = switch (type) {
      AppNoticeType.success => (
          const Color(0xFF119D58),
          Icons.check_circle_rounded,
          'Done',
        ),
      AppNoticeType.error => (
          scheme.error,
          Icons.error_rounded,
          'Something went wrong',
        ),
      AppNoticeType.info => (
          scheme.primary,
          Icons.info_rounded,
          'Heads up',
        ),
    };

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) => Stack(
        children: [
          // Tapping anywhere outside the card closes the notice.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onDismiss,
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.38 * progress),
              ),
            ),
          ),
          Positioned.fill(
            child: SafeArea(
              minimum: const EdgeInsets.all(24),
              child: Center(
                child: Opacity(
                  opacity: progress,
                  child: Transform.scale(
                    scale: 0.92 + 0.08 * progress,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      child: Semantics(
        liveRegion: true,
        container: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          // Taps on the card itself must not fall through to the background.
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: Material(
              color: scheme.surface,
              elevation: 24,
              shadowColor: Colors.black54,
              borderRadius: BorderRadius.circular(24),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Container(
                    // Full width of the card, so every notice is the same
                    // size whether the message is short or long.
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: accent, size: 34),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: scheme.onSurface,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: IconButton(
                      tooltip: 'Close',
                      onPressed: onDismiss,
                      color: scheme.onSurfaceVariant,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
