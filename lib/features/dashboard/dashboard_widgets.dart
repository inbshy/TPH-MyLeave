  import 'package:flutter/material.dart';

  class DashboardStatTile extends StatelessWidget {
    const DashboardStatTile({
      super.key,
      required this.label,
      required this.value,
      required this.icon,
      this.color,
    });

    final String label;
    final String value;
    final IconData icon;
    final Color? color;

    @override
    Widget build(BuildContext context) {
      final scheme = Theme.of(context).colorScheme;
      return Card(
        elevation: 0,
        color: scheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: scheme.primary),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }
  }
