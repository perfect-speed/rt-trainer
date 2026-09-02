import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'trainer_screen.dart';

class DemoWelcomeScreen extends StatelessWidget {
  const DemoWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: AppTheme.panel,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF263744)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.accent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.flight, color: AppTheme.background),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('RT TRAINER', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: .8)),
                              Text('Demo v0.5 · svensk radiotelefoni', style: TextStyle(color: AppTheme.textMuted)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.warning.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.warning.withValues(alpha: .35)),
                          ),
                          child: const Text('TESTVERSION', style: TextStyle(color: AppTheme.warning, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: .7)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Syftet med demon är att prova om radioträningen känns naturlig, om taligenkänningen uppfattar svensk fraseologi och om återkopplingen hjälper dig att upptäcka fel.',
                      style: TextStyle(fontSize: 16, height: 1.45),
                    ),
                    const SizedBox(height: 22),
                    const _DemoPoint(
                      icon: Icons.mic_none,
                      title: 'Använd PTT som i radion',
                      text: 'Håll knappen intryckt medan du talar och släpp när sändningen är klar.',
                    ),
                    const _DemoPoint(
                      icon: Icons.record_voice_over_outlined,
                      title: 'Tala tydligt men normalt',
                      text: 'Använd svensk radiotelefoni och svensk bokstavering. Du ska inte behöva tala onaturligt långsamt.',
                    ),
                    const _DemoPoint(
                      icon: Icons.rule_outlined,
                      title: 'Prova gärna att göra fel',
                      text: 'Fel QNH, bana, transponderkod eller anropssignal är värdefulla testfall. Fraseologifel kan visas som varning utan att sakuppgiften bedöms som fel.',
                    ),
                    const _DemoPoint(
                      icon: Icons.bug_report_outlined,
                      title: 'Detta är en prototyp',
                      text: 'Om taligenkänningen verkar ha hört något annat än det du sade, notera gärna exakt vad som hände. Systemet ska inte korrigera elevens svar i smyg.',
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const TrainerScreen()),
                        );
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text('STARTA DEMO'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Mikrofonbehörighet behöver tillåtas i webbläsaren. Ingen API-nyckel ska finnas i själva webbappen.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoPoint extends StatelessWidget {
  const _DemoPoint({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(text, style: const TextStyle(color: AppTheme.textMuted, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
