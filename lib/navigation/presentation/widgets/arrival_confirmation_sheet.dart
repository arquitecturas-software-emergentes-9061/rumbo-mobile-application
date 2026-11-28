import 'package:flutter/material.dart';

import '../utils/mockup_palette.dart';

/// Answer of the visitor to the arrival question.
enum ArrivalAnswer { finish, notYet }

/// Asks the visitor to confirm the arrival at [destinationName] (PR-345).
///
/// "Terminar" ends the navigation; "Todavía no" keeps guiding. Closing the
/// sheet without answering counts as "Todavía no", so the session is never
/// ended by accident. The title is announced by screen readers.
class ArrivalConfirmationSheet extends StatelessWidget {
  const ArrivalConfirmationSheet({super.key, required this.destinationName});

  final String destinationName;

  /// Shows the sheet and returns the answer.
  static Future<ArrivalAnswer> show(
    BuildContext context, {
    required String destinationName,
  }) async {
    final answer = await showModalBottomSheet<ArrivalAnswer>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: MockupPalette.background,
      builder: (_) =>
          ArrivalConfirmationSheet(destinationName: destinationName),
    );
    return answer ?? ArrivalAnswer.notYet;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.where_to_vote_rounded,
              size: 48,
              color: MockupPalette.primary,
              semanticLabel: 'Destino',
            ),
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              header: true,
              child: Text(
                'Llegaste a $destinationName',
                textAlign: TextAlign.center,
                style: text.titleLarge?.copyWith(
                  color: MockupPalette.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '¿Estás en el lugar? Si es así, terminamos la navegación.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(
                color: MockupPalette.primarySoft,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: MockupPalette.primary,
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: () => Navigator.of(context).pop(ArrivalAnswer.finish),
              child: const Text('Sí, terminar'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: MockupPalette.primary,
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: () => Navigator.of(context).pop(ArrivalAnswer.notYet),
              child: const Text('Todavía no'),
            ),
          ],
        ),
      ),
    );
  }
}
