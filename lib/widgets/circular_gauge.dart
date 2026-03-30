import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CircularGauge — Custom painter with gradient arc + animated sweep
// ════════════════════════════════════════════════════════════════════════════

class CircularGauge extends StatefulWidget {
  final double value;       // normalised 0-1
  final double displayValue;
  final String unit;
  final String label;
  final double size;

  const CircularGauge({
    super.key,
    required this.value,
    required this.displayValue,
    required this.unit,
    required this.label,
    this.size = 110,
  });

  @override
  State<CircularGauge> createState() => _CircularGaugeState();
}

class _CircularGaugeState extends State<CircularGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _sweep;
  double _prev = 0;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _sweep = Tween<double>(begin: 0, end: widget.value).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _prev = widget.value;
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(CircularGauge old) {
    super.didUpdateWidget(old);
    if ((widget.value - _prev).abs() > 0.005) {
      _sweep = Tween<double>(begin: _prev, end: widget.value).animate(
          CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _prev = widget.value;
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.size,
    child: AnimatedBuilder(
      animation: _sweep,
      builder: (_, __) => CustomPaint(
        painter: _GaugePainter(_sweep.value, AuraTheme.gaugeColor(widget.value)),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                child: Text(
                  _fmt(widget.displayValue),
                  style: AuraTheme.orbitron(widget.size * 0.18,
                      weight: FontWeight.w700,
                      color: AuraTheme.gaugeColor(widget.value)),
                ),
              ),
              Text(widget.unit,
                  style: AuraTheme.inter(widget.size * 0.11,
                      color: AuraTheme.textSec)),
            ],
          ),
        ),
      ),
    ),
  );

  static String _fmt(double v) {
    if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(1)}G';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
    return v < 10 ? v.toStringAsFixed(1) : v.toStringAsFixed(0);
  }
}

class _GaugePainter extends CustomPainter {
  final double   sweep;   // 0-1
  final Color    color;

  _GaugePainter(this.sweep, this.color);

  static const _startAngle = math.pi * 0.75;
  static const _totalAngle = math.pi * 1.50;

  @override
  void paint(Canvas canvas, Size size) {
    final cx  = size.width / 2;
    final cy  = size.height / 2;
    final r   = (size.shortestSide / 2) * 0.82;
    final sw  = size.shortestSide * 0.09;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // ── Track (dim arc) ──────────────────────────────────────────────────────
    canvas.drawArc(
      rect,
      _startAngle,
      _totalAngle,
      false,
      Paint()
        ..style       = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap   = StrokeCap.round
        ..color       = color.withAlpha(30),
    );

    if (sweep <= 0) return;

    // ── Active gradient arc ──────────────────────────────────────────────────
    final sweepAngle = _totalAngle * sweep;
    final gradPaint  = Paint()
      ..style        = PaintingStyle.stroke
      ..strokeWidth  = sw
      ..strokeCap    = StrokeCap.round
      ..shader       = SweepGradient(
          startAngle: _startAngle,
          endAngle:   _startAngle + sweepAngle,
          colors:     [color.withAlpha(120), color],
        ).createShader(rect);

    canvas.drawArc(rect, _startAngle, sweepAngle, false, gradPaint);

    // ── Tip glow dot ─────────────────────────────────────────────────────────
    final tipAngle = _startAngle + sweepAngle;
    final tipX     = cx + r * math.cos(tipAngle);
    final tipY     = cy + r * math.sin(tipAngle);
    canvas.drawCircle(Offset(tipX, tipY), sw * 0.6,
        Paint()
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawCircle(Offset(tipX, tipY), sw * 0.35,
        Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.sweep != sweep || old.color != color;
}
