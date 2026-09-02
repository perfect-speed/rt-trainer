import 'package:flutter/material.dart';
import '../models/scenario_models.dart';
import '../theme/app_theme.dart';

class ReadbackCard extends StatelessWidget {
  const ReadbackCard({
    super.key,
    required this.result,
    required this.onNext,
    required this.isLastStep,
  });

  final ValidationResult? result;
  final VoidCallback? onNext;
  final bool isLastStep;


  String _svLabel(String label) => switch (label) {
        'Callsign' => 'Anropssignal',
        'Runway' => 'Bana',
        'Squawk' => 'Transponderkod',
        'Frequency' => 'Frekvens',
        _ => label,
      };

  @override
  Widget build(BuildContext context) {
    if (result == null) return const _EmptyFeedback();

    final success = result!.isComplete;
    final hasWarning = result!.items.any((i) => i.status == ValidationStatus.warning);
    final stateColor = !success ? AppTheme.danger : hasWarning ? Colors.amber : AppTheme.accent;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: !success ? AppTheme.danger.withValues(alpha: .07) : hasWarning ? Colors.amber.withValues(alpha: .06) : AppTheme.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: stateColor.withValues(alpha: .75),
          width: success ? 1 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(success ? Icons.check_circle : Icons.error_outline,
                  color: stateColor),
              const SizedBox(width: 8),
              Text(
                !success ? 'Återläsningen behöver korrigeras' : hasWarning ? 'Korrekt innehåll · fraseologi' : 'Korrekt återläsning',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...result!.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    item.status == ValidationStatus.correct
                        ? Icons.check
                        : item.status == ValidationStatus.warning
                            ? Icons.warning_amber_rounded
                            : item.status == ValidationStatus.incorrect
                                ? Icons.close
                                : item.status == ValidationStatus.unexpected
                                    ? Icons.add_circle_outline
                                    : Icons.remove,
                    size: 18,
                    color: item.status == ValidationStatus.correct
                        ? AppTheme.accent
                        : item.status == ValidationStatus.warning
                            ? Colors.amber
                            : AppTheme.danger,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_svLabel(item.label))),
                  if (item.status == ValidationStatus.correct)
                    Text(item.expected, style: const TextStyle(fontWeight: FontWeight.w700))
                  else if (item.status == ValidationStatus.warning)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('RÄTT BANA', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w800)),
                        Text('säg ${item.expected}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          item.status == ValidationStatus.unexpected
                              ? 'EXTRA ${item.observed ?? ''}'
                              : item.observed == null
                                  ? 'SAKNAS'
                                  : 'ANGAV ${item.observed}',
                          style: const TextStyle(
                            color: AppTheme.danger,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          item.status == ValidationStatus.unexpected
                              ? item.expected
                              : 'väntat ${item.expected}',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 22),
          Text(
            result!.feedback,
            style: TextStyle(color: !success ? AppTheme.danger : hasWarning ? Colors.amber : AppTheme.textMuted),
          ),
          if (success && onNext != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onNext,
              icon: Icon(isLastStep ? Icons.flag_outlined : Icons.arrow_forward),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(isLastStep ? 'SLUTFÖR ÖVNINGEN' : 'NÄSTA'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyFeedback extends StatelessWidget {
  const _EmptyFeedback();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF22313E)),
      ),
      child: const Row(
        children: [
          Icon(Icons.headset_mic_outlined, color: AppTheme.textMuted),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Svara på ATC-meddelandet ovan med PTT eller text. Den här grundversionen tränar svensk radiotelefoni och svensk bokstavering.',
              style: TextStyle(color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
