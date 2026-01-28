import 'package:api_craft/shared/filter_conditions/models/filter_enums.dart';
import 'package:flutter/material.dart';

class ConditionConnector extends StatelessWidget {
  static const double x = 6;
  static const gap = 4.0;
  static const borderClr = Color.fromARGB(255, 138, 138, 138);
  static const lineWidth = 1.2;

  const ConditionConnector({
    required this.operator,
    required this.onToggle,
    super.key,
  });
  final LogicalOperator operator;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final isAnd = operator == LogicalOperator.and;
    final color = isAnd ? Colors.red : Colors.blue;
    final bgColor = color.withValues(alpha: 0.1);
    return Transform.translate(
      offset: const Offset(0, -10),
      child: SizedBox(
        width: 40,
        height: 33,
        child: Column(
          children: [
            Container(
              margin: const .only(left: 20),
              width: 20,
              height: x,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(topLeft: Radius.circular(4)),
                border: Border(
                  top: .new(color: borderClr, width: lineWidth),
                  left: .new(color: borderClr, width: lineWidth),
                ),
              ),
            ),
            InkWell(
              onTap: () {
                debugPrint('Connector tapped to toggle operator');
                onToggle?.call();
              },
              child: Container(
                width: 35,
                padding: const .symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderClr, width: 1),
                ),
                child: Text(
                  isAnd ? 'AND' : 'OR',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            // Bottom Horizontal line with curve
            Container(
              width: 20,
              height: x,
              margin: const .only(left: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(4)),
                border: Border(
                  bottom: .new(color: borderClr, width: lineWidth),
                  left: .new(color: borderClr, width: lineWidth),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
