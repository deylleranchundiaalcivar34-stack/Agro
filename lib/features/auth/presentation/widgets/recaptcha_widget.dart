import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Widget de reCAPTCHA para Flutter (compatible con Web, Android, iOS y Desktop).
///
/// Proporciona la interfaz visual y la lógica del checkbox "No soy un robot",
/// bloqueando los botones de envío hasta que el usuario resuelva el captcha.
class RecaptchaWidget extends StatefulWidget {
  final ValueChanged<bool> onVerified;
  final Duration verificationDelay;

  const RecaptchaWidget({
    super.key,
    required this.onVerified,
    this.verificationDelay = const Duration(milliseconds: 900),
  });

  @override
  State<RecaptchaWidget> createState() => RecaptchaWidgetState();
}

class RecaptchaWidgetState extends State<RecaptchaWidget>
    with SingleTickerProviderStateMixin {
  bool _isChecking = false;
  bool _isVerified = false;
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Reinicia el estado del captcha a no verificado.
  void reset() {
    if (mounted) {
      setState(() {
        _isChecking = false;
        _isVerified = false;
      });
      _animController.reset();
      widget.onVerified(false);
    }
  }

  Future<void> _handleTap() async {
    if (_isChecking || _isVerified) return;

    setState(() {
      _isChecking = true;
    });

    // Simula la verificación del token de desafío
    await Future.delayed(widget.verificationDelay);

    if (!mounted) return;

    setState(() {
      _isChecking = false;
      _isVerified = true;
    });

    _animController.forward();
    widget.onVerified(true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 320),
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: _isVerified ? const Color(0xFF0F9D58) : const Color(0xFFD3D3D3),
          width: _isVerified ? 1.5 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Checkbox interactivo
          InkWell(
            onTap: _handleTap,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCheckbox(),
                  const SizedBox(width: 12),
                  const Text(
                    'No soy un robot',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF282828),
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Badge oficial de reCAPTCHA
          const _RecaptchaBadge(),
        ],
      ),
    );
  }

  Widget _buildCheckbox() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: _isVerified ? const Color(0xFF0F9D58) : Colors.white,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: _isVerified
              ? const Color(0xFF0F9D58)
              : const Color(0xFFC1C1C1),
          width: 2,
        ),
      ),
      child: Center(
        child: _isChecking
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A73E8)),
                ),
              )
            : _isVerified
                ? ScaleTransition(
                    scale: _scaleAnimation,
                    child: const Icon(
                      Icons.check_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  )
                : null,
      ),
    );
  }
}

/// Logo y marca de reCAPTCHA
class _RecaptchaBadge extends StatelessWidget {
  const _RecaptchaBadge();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: CustomPaint(
            painter: _RecaptchaLogoPainter(),
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'reCAPTCHA',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: Color(0xFF555555),
            letterSpacing: 0.2,
          ),
        ),
        const Text(
          'Privacidad · Términos',
          style: TextStyle(
            fontSize: 7,
            color: Color(0xFF888888),
          ),
        ),
      ],
    );
  }
}

/// Dibuja el isotipo triangular de tres flechas continuas de reCAPTCHA
class _RecaptchaLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.42;
    const strokeWidth = 2.4;

    final paintBlue = Paint()
      ..color = const Color(0xFF1A73E8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final paintGreen = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final paintGray = Paint()
      ..color = const Color(0xFF757575)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // 3 arcos con flechas en bucle
    const double gap = 0.45;
    const double arcLen = (2 * math.pi / 3) - gap;

    // Arco 1: Azul (superior)
    canvas.drawArc(rect, -math.pi / 2, arcLen, false, paintBlue);
    _drawArrow(canvas, center, radius, -math.pi / 2 + arcLen, const Color(0xFF1A73E8));

    // Arco 2: Verde (inferior derecho)
    canvas.drawArc(rect, -math.pi / 2 + (2 * math.pi / 3), arcLen, false, paintGreen);
    _drawArrow(canvas, center, radius, -math.pi / 2 + (2 * math.pi / 3) + arcLen, const Color(0xFF34A853));

    // Arco 3: Gris (inferior izquierdo)
    canvas.drawArc(rect, -math.pi / 2 + (4 * math.pi / 3), arcLen, false, paintGray);
    _drawArrow(canvas, center, radius, -math.pi / 2 + (4 * math.pi / 3) + arcLen, const Color(0xFF757575));
  }

  void _drawArrow(Canvas canvas, Offset center, double radius, double angle, Color color) {
    final x = center.dx + radius * math.cos(angle);
    final y = center.dy + radius * math.sin(angle);
    final tip = Offset(x, y);

    final path = Path();
    final tangent = angle + math.pi / 2;
    const arrowLen = 3.5;

    final p1 = Offset(
      tip.dx - arrowLen * math.cos(tangent - 0.7),
      tip.dy - arrowLen * math.sin(tangent - 0.7),
    );
    final p2 = Offset(
      tip.dx - arrowLen * math.cos(tangent + 0.7),
      tip.dy - arrowLen * math.sin(tangent + 0.7),
    );

    path.moveTo(tip.dx, tip.dy);
    path.lineTo(p1.dx, p1.dy);
    path.moveTo(tip.dx, tip.dy);
    path.lineTo(p2.dx, p2.dy);

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
