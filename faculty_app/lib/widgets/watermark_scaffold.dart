import 'dart:math' as math;
import 'package:flutter/material.dart';

class WatermarkScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? drawer;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Color backgroundColor;
  final double watermarkOpacity;
  final double scaleFactor;

  const WatermarkScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.drawer,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.backgroundColor = const Color(0xFFEEF2F8),
    this.watermarkOpacity = 0.09,
    this.scaleFactor = 1, // Fills 75% of the shortest screen edge
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final double dynamicWatermarkSize =
        math.min(screenSize.width, screenSize.height) * scaleFactor;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: appBar,
      drawer: drawer,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: watermarkOpacity,
                    child: Image.asset(
                      'assets/mitet.png',
                      width: dynamicWatermarkSize,
                      height: dynamicWatermarkSize,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
            body,
          ],
        ),
      ),
    );
  }
}