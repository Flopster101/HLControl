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

  static const List<Map<String, dynamic>> _presets = [
    {'id': 'Default', 'label': 'Default', 'color': null},
    {'id': 'Subwoofer', 'label': 'Bass Booster', 'color': Color(0xFFE74C3C)},
    {'id': 'Rock', 'label': 'Rock', 'color': Color(0xFFF1C40F)},
    {'id': 'Soft', 'label': 'Soft', 'color': Color(0xFF2ECC71)},
    {'id': 'Classical', 'label': 'Classical', 'color': Color(0xFF3498DB)},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _presets.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final preset = _presets[index];
          final id = preset['id'] as String;
          final label = preset['label'] as String;
          final color = (preset['color'] as Color?) ?? theme.colorScheme.primary;
          final isSelected = selectedPreset == id;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: FilterChip(
              label: Text(label),
              selected: isSelected,
              onSelected: enabled ? (_) => onChanged(id) : null,
              selectedColor: color.withOpacity(0.15),
              checkmarkColor: color,
              side: BorderSide(
                color: isSelected ? color : theme.colorScheme.outlineVariant.withOpacity(0.3),
                width: isSelected ? 2 : 1,
              ),
              labelStyle: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : theme.colorScheme.onSurface,
              ),
              backgroundColor: theme.cardColor,
            ),
          );
        },
      ),
    );
  }
}
