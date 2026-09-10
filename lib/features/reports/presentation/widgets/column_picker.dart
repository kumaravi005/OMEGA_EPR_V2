import 'package:flutter/material.dart';
import '../../../../core/theme/app_spacing.dart';

/// One selectable export column: a stable [key] (used in saved template
/// config and dataset building) and its display [label].
class ColumnOption {
  const ColumnOption(this.key, this.label);

  final String key;
  final String label;
}

/// Lets the admin pick which columns appear in the export, in whatever
/// order [options] lists them - shared by every export screen so "admin
/// decides which columns appear" is implemented once.
class ColumnPicker extends StatelessWidget {
  const ColumnPicker({
    super.key,
    required this.options,
    required this.selectedKeys,
    required this.onChanged,
  });

  final List<ColumnOption> options;
  final Set<String> selectedKeys;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Columns', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final option in options)
              FilterChip(
                label: Text(option.label),
                selected: selectedKeys.contains(option.key),
                onSelected: (selected) {
                  final next = Set<String>.from(selectedKeys);
                  if (selected) {
                    next.add(option.key);
                  } else {
                    next.remove(option.key);
                  }
                  onChanged(next);
                },
              ),
          ],
        ),
      ],
    );
  }
}
