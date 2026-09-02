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
            padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 520 ? 10 : 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Container(
                padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 520 ? 16 : 26),
                decoration: BoxDecoration(
                  color: AppTheme.panel,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF263744)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, c) {
                        final mobile = c.maxWidth < 520;
                        final badge = Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.warning.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.warning.withValues(alpha: .35)),
                          ),
                          child: const Text('TESTVERSION', style: TextStyle(color: AppTheme.warning, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: .7)),
                        );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: mobile ? 42 : 48,
                                  height: mobile ? 42 : 48,
                                  decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(14)),
                                  child: const Icon(Icons.flight, color: AppTheme.background),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('RT TRAINER', style: TextStyle(fontSize: mobile ? 20 : 24, fontWeight: FontWeight.w900, letterSpacing: .8)),
                                      const Text('Demo v0.5.2 · svensk radiotelefoni', style: TextStyle(color: AppTheme.textMuted)),
                                    ],
                                  ),
                                ),
                                if (!mobile) badge,
                              ],
                            ),
                            if (mobile) ...[const SizedBox(height: 10), badge],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Syftet med demon är att prova om radioträningen känns naturlig. ATC läses upp som ljud, du svarar med PTT och återkopplingen hjälper dig att upptäcka sak- och fraseologifel.',
                      style: TextStyle(fontSize: 16, height: 1.45),
                    ),
                    const SizedBox(height: 22),
                    const _DemoPoint(
                      icon: Icons.mic_none,
                      title: 'Lyssna först – svara sedan med PTT',
                      text: 'ATC-meddelandet läses upp. Håll PTT intryckt medan du svarar och släpp när sändningen är klar. Texten kan visas som stöd.',
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
