import 'package:flutter/material.dart';

class PersonalInfoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300 // Changed color to grey
      ..style = PaintingStyle.fill;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final radius = Radius.circular(40);
    final rrect = RRect.fromRectAndCorners(
      rect,
      topLeft: radius,
      topRight: radius,
    );

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
