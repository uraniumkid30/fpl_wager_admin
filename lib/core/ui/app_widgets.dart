import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager_admin/app/theme/app_theme.dart';
import 'package:intl/intl.dart';

/// "₦12,500" from an amount in cents (kobo), rounded to the naira.
String money(int cents) => NumberFormat.currency(
      locale: 'en_NG',
      symbol: '₦',
      decimalDigits: 0,
    ).format(cents / 100);

/// "₦1.2M", "₦45K" — for chart axes and other tight spaces.
String compactMoney(int cents) {
  final naira = cents / 100;
  final abs = naira.abs();
  String trim(double value) {
    final text = value.toStringAsFixed(1);
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }

  if (abs >= 1000000000) return '₦${trim(naira / 1000000000)}B';
  if (abs >= 1000000) return '₦${trim(naira / 1000000)}M';
  if (abs >= 1000) return '₦${trim(naira / 1000)}K';
  return '₦${naira.round()}';
}

/// The FPLboardman mark and name. [onDark] is for the sidebar, which is dark
/// in both themes.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.compact = false,
    this.onDark = false,
    this.showName = true,
  });

  final bool compact;
  final bool onDark;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final size = compact ? 30.0 : 36.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.lime, AppColors.emerald],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.emoji_events_rounded,
            size: compact ? 17 : 20,
            color: const Color(0xFF06231A),
          ),
        ),
        if (showName) ...[
          const SizedBox(width: 10),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'FPL'),
                TextSpan(
                  text: 'boardman',
                  style: TextStyle(
                    color: onDark ? AppColors.lime : palette.accent,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.clip,
            softWrap: false,
            style: TextStyle(
              fontSize: compact ? 17 : 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: onDark ? Colors.white : palette.text,
            ),
          ),
        ],
      ],
    );
  }
}

/// A plain bordered card. (The name is kept from the first admin app, whose
/// panels were gradients; pass [colors] to get a gradient one.)
class GradientPanel extends StatefulWidget {
  const GradientPanel({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(20),
    this.colors,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final List<Color>? colors;
  final VoidCallback? onTap;

  @override
  State<GradientPanel> createState() => _GradientPanelState();
}

class _GradientPanelState extends State<GradientPanel> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final colors = widget.colors;
    final lifted = _hovered && widget.onTap != null;
    final panel = AnimatedContainer(
      duration: AppMotion.quick,
      curve: AppMotion.curve,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: colors == null ? palette.card : null,
        gradient: colors == null
            ? null
            : LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: lifted ? palette.accent.withValues(alpha: 0.5) : palette.border,
        ),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: lifted ? 18 : 6,
            offset: Offset(0, lifted ? 8 : 2),
          ),
        ],
      ),
      child: widget.child,
    );
    final onTap = widget.onTap;
    if (onTap == null) return panel;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: panel,
      ),
    );
  }
}

/// The colour family a status belongs to.
enum Tone { success, warning, danger, info, neutral, accent }

/// The tone for a status word from the API: "open" is good news, "pending
/// approval" needs attention, "failed" is bad news.
Tone toneForStatus(String status) {
  final value = status.toLowerCase().replaceAll(' ', '_');
  const success = {
    'active', 'open', 'successful', 'succeeded', 'success', 'settled',
    'verified', 'signed_in', 'finished', 'won', 'paid', 'on', 'yes',
    'enabled', 'running', 'email_verified', 'linked',
  };
  const warning = {
    'pending', 'pending_approval', 'draft', 'processing', 'locked', 'scoring',
    'inactive', 'awaiting_approval', 'paused', 'email_not_verified',
    'otp_required', 'upcoming',
  };
  const danger = {
    'failed', 'rejected', 'banned', 'cancelled', 'canceled', 'reversed',
    'deactivated', 'declined', 'lost', 'closed', 'suspended', 'disqualified',
    'error', 'refused', 'off', 'stopped',
  };
  const info = {
    'approved', 'accepted', 'current', 'refunded', 'draw', 'admin',
    'superadmin', 'auto', 'test', 'live',
  };
  if (success.contains(value)) return Tone.success;
  if (warning.contains(value)) return Tone.warning;
  if (danger.contains(value)) return Tone.danger;
  if (info.contains(value)) return Tone.info;
  return Tone.neutral;
}

Color toneColor(BuildContext context, Tone tone) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (tone) {
    Tone.success => dark ? const Color(0xFF4ADE80) : const Color(0xFF0B8A5C),
    Tone.warning => dark ? const Color(0xFFFBBF24) : const Color(0xFFB26A00),
    Tone.danger => dark ? const Color(0xFFFF7B80) : const Color(0xFFD13438),
    Tone.info => dark ? const Color(0xFF7CB7FF) : const Color(0xFF2563EB),
    Tone.accent => Palette.of(context).accent,
    Tone.neutral => Palette.of(context).muted,
  };
}

/// A small rounded label for a status. Its colour follows the status unless
/// [color] or [tone] says otherwise.
class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.color, this.tone, this.dot = true});

  final String label;
  final Color? color;
  final Tone? tone;

  /// Whether to show the small coloured dot before the text.
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final resolved =
        color ?? toneColor(context, tone ?? toneForStatus(label));
    final text = label.replaceAll('_', ' ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: resolved.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: resolved, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              text.isEmpty ? text : text[0].toUpperCase() + text.substring(1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: resolved,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AsyncContent<T> extends StatelessWidget {
  const AsyncContent({
    required this.value,
    required this.data,
    super.key,
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T value) data;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => value.when(
        data: data,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 40,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 14),
                Text(error.toString(), textAlign: TextAlign.center),
                if (onRetry != null) ...[
                  const SizedBox(height: 14),
                  FilledButton.tonal(
                    onPressed: onRetry,
                    child: const Text('Try again'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.subtle,
                shape: BoxShape.circle,
                border: Border.all(color: palette.border),
              ),
              child: Icon(icon, size: 28, color: palette.muted),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: TextStyle(color: palette.muted),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Fades and slides its child in when it first appears. Give each item in a
/// list a slightly longer [delay] for a staggered entrance.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({
    required this.child,
    super.key,
    this.delay = Duration.zero,
    this.offset = 14,
  });

  final Widget child;
  final Duration delay;
  final double offset;

  @override
  Widget build(BuildContext context) {
    final total = AppMotion.entrance + delay;
    // The first part of the animation is the wait; the child moves in the
    // rest.
    final start = delay.inMilliseconds / total.inMilliseconds;
    return TweenAnimationBuilder<double>(
      duration: total,
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) {
        final progress = value <= start
            ? 0.0
            : AppMotion.curve.transform((value - start) / (1 - start));
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, offset * (1 - progress)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
