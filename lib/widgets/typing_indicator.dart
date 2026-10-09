import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Lightweight animated status shown before Mochi receives response text.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 16,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          FadeTransition(
            opacity: Tween<double>(begin: 0.45, end: 1.0).animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
            ),
            child: Text(
              'Thinking…',
              style: TextStyle(
                color: context.textM,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
