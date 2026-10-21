import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Big number or amount on a summary card.
/// Fades smoothly when the value changes, and shrinks instead of overflowing.
class StatValue extends StatelessWidget {
  const StatValue({super.key, required this.value, this.fontSize = 24});

  final String value;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      layoutBuilder: (Widget? current, List<Widget> previous) {
        return Stack(
          alignment: Alignment.centerLeft,
          children: <Widget>[...previous, ?current],
        );
      },
      child: FittedBox(
        key: ValueKey<String>(value),
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          maxLines: 1,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: AppColors.darkBlack,
          ),
        ),
      ),
    );
  }
}
