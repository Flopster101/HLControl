import 'package:flutter/material.dart';

class EqSelector extends StatelessWidget {
  const EqSelector({
    super.key,
    required this.selectedPreset,
    required this.onChanged,
    this.enabled = true,
  });

  final String selectedPreset;
  final ValueChanged<String> onChanged;
  final bool enabled;

  static const List<Map<String, String>> _presets = [
    {'id': 'Default', 'label': 'Default'},
    {'id': 'Subwoofer', 'label': 'Subwoofer'},
    {'id': 'Rock', 'label': 'Rock'},
    {'id': 'Soft', 'label': 'Soft'},
    {'id': 'Classical', 'label': 'Classical'},
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _presets.map((preset) {
          final id = preset['id']!;
          final label = preset['label']!;
          final isSelected = selectedPreset == id;

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: enabled ? (_) => onChanged(id) : null,
            ),
          );
        }).toList(),
      ),
    );
  }
}
