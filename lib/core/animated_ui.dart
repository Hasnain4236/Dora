/// Advanced UI Components for Dora AI
library animated_ui;

import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Main animated orb component
class DoraAnimatedOrb extends StatefulWidget {
  final bool isListening;
  final bool isProcessing;
  final bool isSpeaking;
  final String responseText;
  final List<double> audioLevels;
  final VoidCallback? onTap;

  const DoraAnimatedOrb({
    super.key,
    required this.isListening,
    required this.isProcessing,
    required this.isSpeaking,
    required this.responseText,
    required this.audioLevels,
    this.onTap,
  });

  @override
  State<DoraAnimatedOrb> createState() => _DoraAnimatedOrbState();
}

class _DoraAnimatedOrbState extends State<DoraAnimatedOrb>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _rotationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(_rotationController);
  }

  @override
  void didUpdateWidget(DoraAnimatedOrb oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isListening || widget.isProcessing || widget.isSpeaking) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseAnimation, _rotationAnimation]),
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Transform.rotate(
              angle: widget.isProcessing ? _rotationAnimation.value : 0,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _getOrbGradient(),
                  boxShadow: [
                    BoxShadow(
                      color: _getOrbColor().withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    _getOrbIcon(),
                    size: 60,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  LinearGradient _getOrbGradient() {
    if (widget.isListening) {
      return const LinearGradient(
        colors: [Colors.green, Colors.lightGreen],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (widget.isProcessing) {
      return const LinearGradient(
        colors: [Colors.orange, Colors.deepOrange],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (widget.isSpeaking) {
      return const LinearGradient(
        colors: [Colors.blue, Colors.lightBlue],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      return const LinearGradient(
        colors: [Colors.purple, Colors.deepPurple],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
  }

  Color _getOrbColor() {
    if (widget.isListening) return Colors.green;
    if (widget.isProcessing) return Colors.orange;
    if (widget.isSpeaking) return Colors.blue;
    return Colors.purple;
  }

  IconData _getOrbIcon() {
    if (widget.isListening) return Icons.mic;
    if (widget.isProcessing) return Icons.psychology;
    if (widget.isSpeaking) return Icons.volume_up;
    return Icons.assistant;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }
}

/// Floating action button component
class DoraFloatingButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback? onPressed;
  final Color? backgroundColor;

  const DoraFloatingButton({
    super.key,
    required this.icon,
    required this.isActive,
    this.onPressed,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: isActive
            ? [Colors.green, Colors.lightGreen]
            : [Colors.grey[800]!, Colors.grey[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: (isActive ? Colors.green : Colors.grey).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onPressed,
          child: Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}

/// Glass morphism card component
class DoraGlassCard extends StatelessWidget {
  final String title;
  final String content;
  final Color accentColor;

  const DoraGlassCard({
    super.key,
    required this.title,
    required this.content,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: accentColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
