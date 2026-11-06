import 'package:flutter/material.dart';
import 'package:rumbo_mobile_application/shared/presentation/utils/ui/theme.dart';

class FoundationPage extends StatelessWidget {
  const FoundationPage({
    required this.title,
    required this.description,
    required this.icon,
    super.key,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rumbo',
              style: TextStyle(
                color: RumboColors.primaryDark,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 48),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: RumboColors.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: RumboColors.primaryDark),
            ),
            const SizedBox(height: 20),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(description, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
