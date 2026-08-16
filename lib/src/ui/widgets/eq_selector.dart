import 'package:flutter/material.dart';

class EqSelector extends StatelessWidget {
  const EqSelector({
    super.key,
    required this.selectedPreset,
    required this.onChanged,
    this.presets,
    this.enabled = true,
  });

  final String selectedPreset;
  final ValueChanged<String> onChanged;
  final List<String>? presets;
  final bool enabled;

  static const List<String> defaultS40Presets = [
    'Default',
    'Subwoofer',
    'Rock',
    'Soft',
    'Classical',
  ];

  static const List<String> standardPresets = [
    'Default',
    'Vocal',
    'Rock',
    'Classical',
    'Popularity',
    'Bass',
    'Subwoofer',
    'Soft',
    'Outdoor',
  ];

  @override
  Widget build(BuildContext context) {
    final list = presets ?? defaultS40Presets;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: list.map((id) {
          final isSelected = selectedPreset == id;

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(id),
              selected: isSelected,
              onSelected: enabled ? (_) => onChanged(id) : null,
            ),
          );
        }).toList(),
      ),
    );
  }
}
