import 'package:flutter/material.dart';
import '../services/trainer_api.dart';
import '../theme/app_theme.dart';
import 'trainer_screen.dart';

class DemoWelcomeScreen extends StatefulWidget {
  const DemoWelcomeScreen({super.key});

  @override
  State<DemoWelcomeScreen> createState() => _DemoWelcomeScreenState();
}

class _DemoWelcomeScreenState extends State<DemoWelcomeScreen> {
  final TrainerApi _api = TrainerApi();
  Future<void>? _warmupFuture;
  bool _starting = false;
  String? _warmupNote;

  @override
  void initState() {
    super.initState();
    // Start warming Render immediately while the learner reads the welcome
    // screen. The button later awaits the same Future rather than sending a
    // second wake-up request.
    if (_api.isConfigured) {
      _warmupFuture = _api.warmUp();
      _warmupFuture!.then((_) {
        if (mounted) setState(() => _warmupNote = 'Röstserver klar.');
      }).catchError((_) {
        // Do not block the demo permanently. STARTA DEMO will still proceed and
        // the normal speech request has its own transient-error retry handling.
        if (mounted) setState(() => _warmupNote = 'Röstservern svarade inte ännu.');
      });
    }
  }

  Future<void> _startDemo() async {
    if (_starting) return;
    setState(() {
      _starting = true;
      _warmupNote ??= 'Startar röstserver…';
    });

    try {
      final warmup = _warmupFuture;
      if (warmup != null) await warmup;
    } catch (_) {
      // Continue. A failed warm-up should not make the trainer unusable.
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const TrainerScreen()),
    );
  }

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
                                      const Text('Demo v0.9.0 · svensk radiotelefoni', style: TextStyle(color: AppTheme.textMuted)),
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
                      onPressed: _starting ? null : _startDemo,
                      icon: _starting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.play_arrow),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(_starting ? 'STARTAR RÖSTSERVER…' : 'STARTA DEMO'),
                      ),
                    ),
                    if (_warmupNote != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _warmupNote!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 10),
                    const Text(
                      'Röstservern värms i bakgrunden medan denna sida visas. Mikrofonbehörighet behöver tillåtas i webbläsaren. Ingen API-nyckel ska finnas i själva webbappen.',
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
