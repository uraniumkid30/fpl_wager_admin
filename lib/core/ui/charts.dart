import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fplboardman_admin/app/theme/app_theme.dart';

/// One line on a [SeriesChart].
class ChartSeries {
  const ChartSeries({
    required this.name,
    required this.color,
    required this.values,
  });

  final String name;
  final Color color;
  final List<double> values;
}

/// A line chart of one or more series over the same points, with a legend
/// that shows the values under the pointer.
///
/// Drawn by hand so the admin app needs no charting package.
class SeriesChart extends StatefulWidget {
  const SeriesChart({
    required this.series,
    required this.labels,
    required this.formatValue,
    super.key,
    this.height = 240,
  });

  final List<ChartSeries> series;

  /// The label under each point, e.g. "6 Oct". Same length as each series.
  final List<String> labels;

  /// Turns a value into text for the axis and the legend.
  final String Function(double value) formatValue;

  /// The height of the plot. Null fills whatever height the parent gives,
  /// which must then be bounded (inside an [Expanded], say).
  final double? height;

  @override
  State<SeriesChart> createState() => _SeriesChartState();
}

class _SeriesChartState extends State<SeriesChart> {
  /// The point under the pointer, or null.
  int? _hover;

  static const _left = 52.0;
  static const _right = 12.0;

  void _track(Offset position, double width) {
    final count = widget.labels.length;
    if (count == 0) return;
    final plot = width - _left - _right;
    if (plot <= 0) return;
    final step = count == 1 ? plot : plot / (count - 1);
    final index =
        ((position.dx - _left) / step).round().clamp(0, count - 1).toInt();
    if (index != _hover) setState(() => _hover = index);
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final hover = _hover;
    final height = widget.height;
    final plot = LayoutBuilder(
      builder: (context, constraints) => MouseRegion(
        onHover: (event) => _track(event.localPosition, constraints.maxWidth),
        onExit: (_) => setState(() => _hover = null),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) =>
              _track(details.localPosition, constraints.maxWidth),
          onHorizontalDragUpdate: (details) =>
              _track(details.localPosition, constraints.maxWidth),
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            tween: Tween(begin: 0, end: 1),
            builder: (context, progress, _) => CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _SeriesPainter(
                series: widget.series,
                labels: widget.labels,
                formatValue: widget.formatValue,
                progress: progress,
                hover: hover,
                grid: palette.border,
                text: palette.muted,
                surface: palette.card,
                left: _left,
                right: _right,
              ),
            ),
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 18,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final item in widget.series)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: item.color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    item.name,
                    style: TextStyle(color: palette.muted, fontSize: 12.5),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.formatValue(
                      hover != null && hover < item.values.length
                          ? item.values[hover]
                          : item.values.fold<double>(0, (a, b) => a + b),
                    ),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            Text(
              hover != null && hover < widget.labels.length
                  ? widget.labels[hover]
                  : 'Total for the period',
              style: TextStyle(color: palette.muted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (height == null)
          Expanded(child: plot)
        else
          SizedBox(height: height, child: plot),
      ],
    );
  }
}

/// Rounds a maximum up to a tidy axis top: 1, 2, 2.5, 5 or 10 times a power
/// of ten.
double niceCeiling(double value) {
  if (value <= 0) return 1;
  final exponent = (math.log(value) / math.ln10).floor();
  final base = math.pow(10, exponent).toDouble();
  final fraction = value / base;
  final nice = fraction <= 1
      ? 1.0
      : fraction <= 2
          ? 2.0
          : fraction <= 2.5
              ? 2.5
              : fraction <= 5
                  ? 5.0
                  : 10.0;
  return nice * base;
}

class _SeriesPainter extends CustomPainter {
  _SeriesPainter({
    required this.series,
    required this.labels,
    required this.formatValue,
    required this.progress,
    required this.hover,
    required this.grid,
    required this.text,
    required this.surface,
    required this.left,
    required this.right,
  });

  final List<ChartSeries> series;
  final List<String> labels;
  final String Function(double value) formatValue;
  final double progress;
  final int? hover;
  final Color grid;
  final Color text;
  final Color surface;
  final double left;
  final double right;

  static const _top = 8.0;
  static const _bottom = 26.0;

  void _label(Canvas canvas, String value, Offset at, {bool alignRight = false, bool center = false}) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(color: text, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    var dx = at.dx;
    if (alignRight) dx -= painter.width;
    if (center) dx -= painter.width / 2;
    painter.paint(canvas, Offset(dx, at.dy - painter.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final count = labels.length;
    final plot = Rect.fromLTRB(left, _top, size.width - right, size.height - _bottom);
    if (plot.width <= 0 || plot.height <= 0) return;

    var peak = 0.0;
    for (final item in series) {
      for (final value in item.values) {
        if (value > peak) peak = value;
      }
    }
    final top = niceCeiling(peak);

    // Horizontal grid lines and their values.
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    const lines = 4;
    for (var i = 0; i <= lines; i++) {
      final y = plot.bottom - plot.height * i / lines;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      _label(canvas, formatValue(top * i / lines), Offset(plot.left - 8, y), alignRight: true);
    }
    if (count == 0) return;

    double xAt(int index) => count == 1
        ? plot.center.dx
        : plot.left + plot.width * index / (count - 1);
    double yAt(double value) =>
        plot.bottom - plot.height * (value / top) * progress;

    // A handful of date labels, evenly spread, always including the last.
    final every = math.max(1, (count / 6).ceil());
    for (var i = count - 1; i >= 0; i -= every) {
      _label(canvas, labels[i], Offset(xAt(i), plot.bottom + 14), center: true);
    }

    final guide = hover;
    if (guide != null && guide < count) {
      canvas.drawLine(
        Offset(xAt(guide), plot.top),
        Offset(xAt(guide), plot.bottom),
        Paint()
          ..color = text.withValues(alpha: 0.35)
          ..strokeWidth = 1,
      );
    }

    for (final item in series) {
      final points = <Offset>[
        for (var i = 0; i < math.min(count, item.values.length); i++)
          Offset(xAt(i), yAt(item.values[i])),
      ];
      if (points.isEmpty) continue;

      final line = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        // A gentle curve between neighbours that never overshoots them.
        final previous = points[i - 1];
        final current = points[i];
        final middle = (previous.dx + current.dx) / 2;
        line.cubicTo(middle, previous.dy, middle, current.dy, current.dx, current.dy);
      }

      final area = Path.from(line)
        ..lineTo(points.last.dx, plot.bottom)
        ..lineTo(points.first.dx, plot.bottom)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              item.color.withValues(alpha: 0.22),
              item.color.withValues(alpha: 0),
            ],
          ).createShader(plot),
      );
      canvas.drawPath(
        line,
        Paint()
          ..color = item.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );

      if (points.length == 1 || (guide != null && guide < points.length)) {
        final at = points[points.length == 1 ? 0 : guide!];
        canvas.drawCircle(at, 5, Paint()..color = surface);
        canvas.drawCircle(at, 3.5, Paint()..color = item.color);
      }
    }
  }

  @override
  bool shouldRepaint(_SeriesPainter old) =>
      old.progress != progress ||
      old.hover != hover ||
      old.series != series ||
      old.labels != labels ||
      old.grid != grid ||
      old.text != text ||
      old.surface != surface;
}

/// A tiny trend line for a stat card.
class Sparkline extends StatelessWidget {
  const Sparkline({
    required this.values,
    required this.color,
    super.key,
    this.width = 84,
    this.height = 34,
  });

  final List<double> values;
  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        tween: Tween(begin: 0, end: 1),
        builder: (context, progress, _) => CustomPaint(
          size: Size(width, height),
          painter: _SparklinePainter(
            values: values,
            color: color,
            progress: progress,
          ),
        ),
      );
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.color,
    required this.progress,
  });

  final List<double> values;
  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final low = values.reduce(math.min);
    final high = values.reduce(math.max);
    final range = high - low;
    const inset = 3.0;
    final usable = size.height - inset * 2;
    final points = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(
          size.width * i / (values.length - 1),
          // A flat series sits in the middle rather than on the floor.
          range == 0
              ? size.height / 2
              : inset + usable * (1 - (values[i] - low) / range * progress),
        ),
    ];
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final middle = (previous.dx + current.dx) / 2;
      line.cubicTo(middle, previous.dy, middle, current.dy, current.dx, current.dy);
    }
    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.progress != progress || old.values != values || old.color != color;
}

/// One slice of a [DonutChart].
class DonutSegment {
  const DonutSegment({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;
}

/// A ring chart with its total in the middle and a legend beside it.
class DonutChart extends StatelessWidget {
  const DonutChart({
    required this.segments,
    required this.centerLabel,
    super.key,
    this.size = 150,
  });

  final List<DonutSegment> segments;

  /// The word under the total in the middle, e.g. "pools".
  final String centerLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final total = segments.fold<double>(0, (sum, item) => sum + item.value);
    final ring = SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        tween: Tween(begin: 0, end: 1),
        builder: (context, progress, child) => CustomPaint(
          painter: _DonutPainter(
            segments: segments,
            total: total,
            progress: progress,
            track: palette.subtle,
          ),
          child: child,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                total.round().toString(),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                centerLabel,
                style: TextStyle(color: palette.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
    final legend = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in segments)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: item.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.muted, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  item.value.round().toString(),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ],
            ),
          ),
      ],
    );
    return Wrap(
      spacing: 24,
      runSpacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.center,
      children: [ring, legend],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.segments,
    required this.total,
    required this.progress,
    required this.track,
  });

  final List<DonutSegment> segments;
  final double total;
  final double progress;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);
    if (total <= 0) return;
    // A small gap between slices, when there is more than one.
    final shown = segments.where((item) => item.value > 0).length;
    final gap = shown > 1 ? 0.04 : 0.0;
    var start = -math.pi / 2;
    for (final item in segments) {
      if (item.value <= 0) continue;
      final sweep = math.pi * 2 * (item.value / total) * progress;
      if (sweep > gap) {
        canvas.drawArc(
          rect,
          start + gap / 2,
          sweep - gap,
          false,
          paint..color = item.color,
        );
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress ||
      old.segments != segments ||
      old.total != total ||
      old.track != track;
}
