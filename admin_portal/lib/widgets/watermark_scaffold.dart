import 'dart:math' as math;
import 'package:flutter/material.dart';

class WatermarkScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Color backgroundColor;
  final double watermarkOpacity;

  /// Percentage of the shortest screen dimension (0.1 to 1.0)
  /// 0.75 means the logo will occupy 75% of screen width or height
  final double scaleFactor;

  const WatermarkScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.backgroundColor = const Color(0xFFEEF2F8),
    this.watermarkOpacity = 0.08, // Clean watermark visibility
    this.scaleFactor = 1,      // Dynamically fills 75% of available viewport
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    // Determine the ideal size based on whether device is in portrait or landscape
    final double dynamicWatermarkSize =
        math.min(screenSize.width, screenSize.height) * scaleFactor;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: SafeArea(
        child: Stack(
          children: [
            // ==========================================
            // Dynamically Scaled Background Watermark
            // ==========================================
            Positioned.fill(
              child: Center(
                child: IgnorePointer(
                  // Ensures clicks/touches pass through to fields underneath
                  child: Opacity(
                    opacity: watermarkOpacity,
                    child: Image.asset(
                      'assets/mitet_logo.png',
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

            // Foreground Interactive Screens
            body,
          ],
        ),
      ),
    );
  }
}
