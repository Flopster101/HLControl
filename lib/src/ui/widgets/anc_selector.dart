import 'package:flutter/material.dart';

class AncSelector extends StatelessWidget {
  const AncSelector({
    super.key,
    required this.selectedMode,
    required this.onChanged,
    this.enabled = true,
  });

  final String selectedMode;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        showSelectedIcon: false,
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
        ),
        segments: const [
          ButtonSegment<String>(
            value: 'Normal',
            label: Text('Off'),
          ),
          ButtonSegment<String>(
            value: 'ANC On',
            label: Text('ANC'),
          ),
          ButtonSegment<String>(
            value: 'Transparency',
            label: Text('Aware'),
          ),
          ButtonSegment<String>(
            value: 'Adaptive',
            label: Text('Adaptive'),
          ),
        ],
        selected: {selectedMode},
        onSelectionChanged: enabled
            ? (newSelection) => onChanged(newSelection.first)
            : null,
      ),
    );
  }
}
