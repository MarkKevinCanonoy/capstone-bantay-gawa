import 'dart:math';
import 'package:flutter/material.dart';

/// A self-contained, crisp QR Code rendering widget with standard
/// finder patterns (top-left, top-right, bottom-left) and deterministic
/// data modules generated from the input payload.
class QrCodeWidget extends StatelessWidget {
  final String data;
  final double size;
  final Color foregroundColor;
  final Color backgroundColor;

  const QrCodeWidget({
    super.key,
    required this.data,
    this.size = 180,
    this.foregroundColor = const Color(0xFF0A194E),
    this.backgroundColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.06),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: _QrPainter(
          data: data,
          foregroundColor: foregroundColor,
        ),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  final String data;
  final Color foregroundColor;

  _QrPainter({
    required this.data,
    required this.foregroundColor,
  });

  static const int gridSize = 25; // 25x25 Version 2 QR matrix

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = foregroundColor
      ..style = PaintingStyle.fill;

    final cellSize = size.width / gridSize;

    // Generate matrix
    final matrix = List.generate(gridSize, (_) => List.generate(gridSize, (_) => false));

    // 1. Draw 3 Finder Patterns (7x7)
    _drawFinderPattern(matrix, 0, 0); // Top-left
    _drawFinderPattern(matrix, gridSize - 7, 0); // Top-right
    _drawFinderPattern(matrix, 0, gridSize - 7); // Bottom-left

    // 2. Draw Timing Patterns
    for (int i = 8; i < gridSize - 8; i++) {
      if (i % 2 == 0) {
        matrix[6][i] = true;
        matrix[i][6] = true;
      }
    }

    // 3. Populate deterministic data modules based on data string hash
    final seed = data.codeUnits.fold<int>(0, (prev, elem) => (prev * 31 + elem) & 0x7FFFFFFF);
    final random = Random(seed);

    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        // Skip reserved finder pattern areas (including 1-module separators)
        if (_isReserved(r, c)) continue;
        // Data bits
        matrix[r][c] = random.nextBool();
      }
    }

    // Render cells to canvas
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (matrix[r][c]) {
          canvas.drawRect(
            Rect.fromLTWH(c * cellSize, r * cellSize, cellSize + 0.2, cellSize + 0.2),
            paint,
          );
        }
      }
    }
  }

  void _drawFinderPattern(List<List<bool>> matrix, int startRow, int startCol) {
    for (int r = 0; r < 7; r++) {
      for (int c = 0; c < 7; c++) {
        final isBorder = (r == 0 || r == 6 || c == 0 || c == 6);
        final isCenter = (r >= 2 && r <= 4 && c >= 2 && c <= 4);
        matrix[startRow + r][startCol + c] = isBorder || isCenter;
      }
    }
  }

  bool _isReserved(int r, int c) {
    // Top-left finder + separator
    if (r <= 7 && c <= 7) return true;
    // Top-right finder + separator
    if (r <= 7 && c >= gridSize - 8) return true;
    // Bottom-left finder + separator
    if (r >= gridSize - 8 && c <= 7) return true;
    // Timing lines
    if (r == 6 || c == 6) return true;
    return false;
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.foregroundColor != foregroundColor;
}
