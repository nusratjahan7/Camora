import 'package:flutter/material.dart';

import '../extensions/build_context_extensions.dart';

class AppSlider extends StatelessWidget {
  const AppSlider({
    super.key,
    required this.label,
    required this.value,
    this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.valueLabel,
    this.semanticFormatterCallback,
  });

  final String label;
  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;
  final String? valueLabel;
  final String Function(double)? semanticFormatterCallback;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final text = context.textStyles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: text.titleSmall?.copyWith(color: scheme.onSurface),
              ),
            ),
            if (valueLabel != null)
              Text(
                valueLabel!,
                style: text.labelLarge?.copyWith(color: scheme.primary),
              ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
          semanticFormatterCallback: semanticFormatterCallback,
        ),
      ],
    );
  }
}
