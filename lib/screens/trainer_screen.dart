import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/scenario_models.dart';
import '../services/readback_validator.dart';
import '../services/asr_quality_assessor.dart';
import '../services/spoken_rt_normalizer.dart';
import '../services/swedish_rt_speech_formatter.dart';
import '../services/trainer_api.dart';
import '../services/voice_recorder.dart';
import '../theme/app_theme.dart';
import '../widgets/radar_panel.dart';
import '../widgets/readback_card.dart';
import '../widgets/status_chip.dart';

enum PracticeMode { drillReadback, scenario }

enum SpeechEngine { realtime, ttsBaseline }

class TrainerScreen extends StatefulWidget {
  const TrainerScreen({super.key});

  @override
  State<TrainerScreen> createState() => _TrainerScreenState();
}

class _TrainerScreenState extends State<TrainerScreen> {
  final _controller = TextEditingController();
  final _validator = ReadbackValidator();
  final _asrQuality = AsrQualityAssessor();
  final _voiceRecorder = VoiceRecorder();
  final _api = TrainerApi();
  final _speechNormalizer = SpokenRtNormalizer();
  final _speechFormatter = SwedishRtSpeechFormatter();
  final _audioPlayer = AudioPlayer();
  final _events = <RadioEvent>[];

  static const _drillSteps = <TrainingStep>[
    TrainingStep(
      id: 'RB01',
      title: 'Grundläggande återläsning',
      instruction: 'Fristående övning: läs tillbaka bana, QNH, transponderkod och anropssignal.',
      atcTransmission: 'SE-KQX, bana 01, QNH 1016, transponder 4255.',
      expected: ExpectedReadback(callsign: 'SE-KQX', runway: '01', qnh: '1016', squawk: '4255'),
      coachNote: 'Detta är en mikroövning. Tidigare radiotrafik modelleras inte.',
    ),
    TrainingStep(
      id: 'RB02',
      title: 'Ny QNH och transponderkod',
      instruction: 'Värdena ändras. Läs tillbaka exakt de objekt som gavs.',
      atcTransmission: 'SE-GLA, QNH 1018, transponder 4261.',
      expected: ExpectedReadback(callsign: 'SE-GLA', qnh: '1018', squawk: '4261'),
    ),
    TrainingStep(
      id: 'RB03',
      title: 'Bana och QNH',
      instruction: 'Denna gång finns inget krav på transponderkod. Läs bara tillbaka det som faktiskt gavs.',
      atcTransmission: 'SE-VPT, bana 19, QNH 1009.',
      expected: ExpectedReadback(callsign: 'SE-VPT', runway: '19', qnh: '1009'),
    ),
    TrainingStep(
      id: 'RB04',
      title: 'Frekvensbyte',
      instruction: 'Läs tillbaka den nya frekvensen och anropssignalen.',
      atcTransmission: 'SE-MBN, kontakta Sweden Control 124.725.',
      frequency: '124.500',
      expected: ExpectedReadback(callsign: 'SE-MBN', frequency: '124.725'),
    ),
    TrainingStep(
      id: 'RB05',
      title: 'Kombinerad återläsning',
      instruction: 'Längre transmission. Prioritera korrekt innehåll framför hastighet.',
      atcTransmission: 'SE-RYD, bana 01, QNH 1013, transponder 4272.',
      expected: ExpectedReadback(callsign: 'SE-RYD', runway: '01', qnh: '1013', squawk: '4272'),
    ),
  ];

  // First stateful scenario slice. Unlike DRILL, the radio history is retained
  // and callsign abbreviation becomes valid only after ATC has introduced it.
  static const _scenarioSteps = <TrainingStep>[
    TrainingStep(
      id: 'SC01',
      title: 'Etablerad kontakt',
      instruction: 'Du är SE-KQX. Kontakten är etablerad och du taxar för avgång. Läs tillbaka ATC.',
      atcTransmission: 'SE-KQX, bana 19, QNH 1009.',
      expected: ExpectedReadback(callsign: 'SE-KQX', runway: '19', qnh: '1009'),
      coachNote: 'Scenario: tidigare tillstånd finns kvar när du går vidare.',
    ),
    TrainingStep(
      id: 'SC02',
      title: 'ATC förkortar anropssignalen',
      instruction: 'ATC har nu introducerat den förkortade anropssignalen. Full eller korrekt förkortad form accepteras.',
      atcTransmission: 'S-QX, transponder 4261.',
      expected: ExpectedReadback(callsign: 'SE-KQX', squawk: '4261', allowAbbreviatedCallsign: true),
    ),
    TrainingStep(
      id: 'SC03',
      title: 'Frekvensbyte',
      instruction: 'Kommunikationen fortsätter i samma scenario. Läs tillbaka frekvensen.',
      atcTransmission: 'S-QX, kontakta Sweden Control 124.725.',
      frequency: '124.500',
      expected: ExpectedReadback(callsign: 'SE-KQX', frequency: '124.725', allowAbbreviatedCallsign: true),
    ),
  ];

  PracticeMode _mode = PracticeMode.drillReadback;
  int _stepIndex = 0;
  ValidationResult? _result;
  bool _sessionComplete = false;
  int _attempts = 0;
  final Set<int> _stepsWithRetry = <int>{};
  int _mobileView = 0;
  bool _isRecording = false;
  bool _pttHeld = false;
  bool _isTranscribing = false;
  String? _lastRawTranscript;
  String? _lastInterpretedTranscript;
  String? _voiceError;
  String? _asrWarning;
  bool _showAtcPromptText = false;
  bool _isSpeakingAtc = false;
  String? _speechError;
  SpeechEngine _speechEngine = SpeechEngine.realtime;

  List<TrainingStep> get _steps => _mode == PracticeMode.drillReadback ? _drillSteps : _scenarioSteps;
  TrainingStep get _step => _steps[_stepIndex];
  bool get _isScenario => _mode == PracticeMode.scenario;

  @override
  void initState() {
    super.initState();
    _startCurrentStep(resetHistory: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _voiceRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _startCurrentStep({required bool resetHistory}) {
    if (resetHistory) _events.clear();
    _events.add(RadioEvent(time: DateTime.now(), speaker: 'ATC', text: _step.atcTransmission, isPrompt: true));
    _result = null;
    _controller.clear();
    _lastRawTranscript = null;
    _lastInterpretedTranscript = null;
    _voiceError = null;
    _asrWarning = null;
    _showAtcPromptText = false;
    _speechError = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _speakCurrentAtc();
    });
  }

  void _switchMode(PracticeMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _stepIndex = 0;
      _attempts = 0;
      _stepsWithRetry.clear();
      _sessionComplete = false;
      _startCurrentStep(resetHistory: true);
    });
  }

  void _transmit({String? textOverride}) {
    if (_sessionComplete || _result?.isComplete == true || _isTranscribing) return;
    final text = (textOverride ?? _controller.text).trim();
    if (text.isEmpty) return;

    final result = _validator.validate(transmission: text, expected: _step.expected);
    setState(() {
      _attempts++;
      if (!result.isComplete) _stepsWithRetry.add(_stepIndex);
      _events.add(RadioEvent(time: DateTime.now(), speaker: _step.expected.callsign, text: text, isError: !result.isComplete));
      _events.add(RadioEvent(time: DateTime.now(), speaker: 'ATC', text: result.atcResponse));
      _result = result;
      _controller.clear();
    });
  }


  Future<void> _speakCurrentAtc() async {
    if (_isSpeakingAtc || !_api.isConfigured) return;
    // v0.6.1 keeps the Realtime model for natural prosody, but no longer
    // lets it choose the words. The scenario remains normative truth and the
    // deterministic formatter supplies the exact spoken RT script.
    final spokenScript = _speechFormatter.format(_step.atcTransmission);
    final speechText = _speechEngine == SpeechEngine.realtime
        ? _step.atcTransmission
        : spokenScript;
    setState(() {
      _isSpeakingAtc = true;
      _speechError = null;
    });
    try {
      final bytes = await _api.synthesizeSpeech(
        text: speechText,
        spokenText: _speechEngine == SpeechEngine.realtime ? spokenScript : null,
        engine: _speechEngine == SpeechEngine.realtime ? 'realtime' : 'tts',
      );
      await _audioPlayer.stop();
      await _audioPlayer.play(BytesSource(bytes));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _speechError = 'Ljudfel: ${error.toString().replaceFirst('Bad state: ', '')}';
      });
    } finally {
      if (mounted) setState(() => _isSpeakingAtc = false);
    }
  }


  Future<void> _startVoice() async {
    _pttHeld = true;
    if (_sessionComplete || _result?.isComplete == true || _isTranscribing || _isRecording) return;
    if (!_api.isConfigured) {
      setState(() {
        _voiceError = 'Röstbackend är inte ansluten. Starta appen med --dart-define=RT_API_URL=http://localhost:8080.';
      });
      return;
    }

    try {
      await _voiceRecorder.start();
      if (!mounted) return;
      if (!_pttHeld) {
        await _voiceRecorder.cancel();
        return;
      }
      setState(() {
        _isRecording = true;
        _voiceError = null;
        _asrWarning = null;
        _lastRawTranscript = null;
        _lastInterpretedTranscript = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _voiceError = 'Mikrofonen kunde inte startas: $error');
    }
  }

  Future<void> _stopVoice() async {
    _pttHeld = false;
    if (!_isRecording) return;
    setState(() {
      _isRecording = false;
      _isTranscribing = true;
    });

    try {
      final recording = await _voiceRecorder.stop();
      if (recording == null || recording.duration < const Duration(milliseconds: 300)) {
        if (!mounted) return;
        setState(() {
          _isTranscribing = false;
          _voiceError = 'Sändningen var för kort. Håll PTT intryckt medan du talar.';
        });
        return;
      }

      final raw = await _api.transcribe(
        wavBytes: recording.wavBytes,
        scenarioContext: _transcriptionContext(),
      );
      final interpreted = _speechNormalizer.normalize(raw, _step.expected);
      final asrAssessment = _asrQuality.assess(
        rawTranscript: raw,
        normalizedTranscript: interpreted,
        expected: _step.expected,
      );
      if (!mounted) return;
      setState(() {
        _lastRawTranscript = raw;
        _lastInterpretedTranscript = interpreted;
        _controller.text = interpreted;
        _isTranscribing = false;
        _asrWarning = asrAssessment.message;
      });

      // Möjligt ASR-fel registreras inte som ett elevfel. Användaren får
      // repetera anropssignalen i stället för att validatorn säger SAKNAS.
      if (!asrAssessment.callsignUncertain) {
        _transmit(textOverride: interpreted);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isTranscribing = false;
        _voiceError = 'Taligenkänningen misslyckades: $error';
      });
    }
  }

  String _shortCallsign(String callsign) {
    final compact = callsign.toUpperCase().replaceAll('-', '');
    if (compact.length < 3) return callsign;
    return '${compact[0]}-${compact.substring(compact.length - 2)}';
  }

  String _transcriptionContext() {
    final e = _step.expected;
    return [
      'Flygplanets anropssignal: ${e.callsign}.',
      if (e.allowAbbreviatedCallsign) 'Förkortad anropssignal ${_shortCallsign(e.callsign)} kan förekomma.',
      'ATC-meddelande: ${_step.atcTransmission}',
      if (e.runway != null) 'Bana kan vara ${e.runway}.',
      if (e.qnh != null) 'QNH kan vara ${e.qnh}.',
      if (e.squawk != null) 'Transponderkod kan vara ${e.squawk}.',
      if (e.frequency != null) 'Frekvens kan vara ${e.frequency}.',
      'Svenskt bokstaveringsalfabet har prioritet framför NATO/ICAO. Kontexten är inte facit; transkribera exakt vad piloten faktiskt säger.',
    ].join(' ');
  }

  Widget _voiceStatus() {
    if (_voiceError != null) {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.danger.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.danger.withValues(alpha: .35)),
        ),
        child: Text(_voiceError!, style: const TextStyle(color: AppTheme.danger, fontSize: 12)),
      );
    }
    if (_asrWarning != null) {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.warning.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.warning.withValues(alpha: .45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_lastRawTranscript != null)
              Text('Taligenkänningen hörde: ${_lastRawTranscript!}',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            const SizedBox(height: 4),
            Text(_asrWarning!,
                style: const TextStyle(color: AppTheme.warning, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }
    if (_lastRawTranscript == null) return const SizedBox.shrink();
    final interpreted = _lastInterpretedTranscript ?? _lastRawTranscript!;
    final differs = interpreted.trim().toLowerCase() != _lastRawTranscript!.trim().toLowerCase();
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.panelElevated,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Taligenkänningen hörde: ${_lastRawTranscript!}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          if (differs) ...[
            const SizedBox(height: 4),
            Text('Tolkad för bedömning: $interpreted', style: const TextStyle(color: AppTheme.accent, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _pttButton() {
    final blocked = _result?.isComplete == true || _sessionComplete || _isTranscribing;
    final label = _isTranscribing
        ? 'TOLKAR SÄNDNING…'
        : _isRecording
            ? 'SÄNDER · SLÄPP PTT'
            : 'HÅLL IN PTT';
    final color = _isRecording ? AppTheme.danger : AppTheme.accent;

    return Listener(
      onPointerDown: blocked ? null : (_) => _startVoice(),
      onPointerUp: blocked ? null : (_) => _stopVoice(),
      onPointerCancel: blocked ? null : (_) => _stopVoice(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 52,
        decoration: BoxDecoration(
          color: blocked ? AppTheme.panelElevated : color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: _isRecording
              ? [BoxShadow(color: AppTheme.danger.withValues(alpha: .25), blurRadius: 18, spreadRadius: 1)]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isTranscribing)
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            else
              Icon(_isRecording ? Icons.mic : Icons.mic_none, color: AppTheme.background),
            const SizedBox(width: 9),
            Text(label, style: TextStyle(color: blocked ? AppTheme.textMuted : AppTheme.background, fontWeight: FontWeight.w800, letterSpacing: .4)),
          ],
        ),
      ),
    );
  }

  void _nextStep() {
    if (_stepIndex == _steps.length - 1) {
      setState(() => _sessionComplete = true);
      return;
    }
    setState(() {
      _stepIndex++;
      _startCurrentStep(resetHistory: !_isScenario);
    });
  }

  void _restart() {
    setState(() {
      _stepIndex = 0;
      _attempts = 0;
      _stepsWithRetry.clear();
      _sessionComplete = false;
      _startCurrentStep(resetHistory: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 1100 || constraints.maxHeight < 760;
            final veryCompact = constraints.maxWidth < 720 || constraints.maxHeight < 620;
            final wide = !compact;
            return Column(
              children: [
                _Header(mode: _mode, onModeChanged: _switchMode, compact: compact, veryCompact: veryCompact),
                if (!_sessionComplete)
                  _ProgressHeader(
                    mode: _mode,
                    stepIndex: _stepIndex,
                    count: _steps.length,
                    step: _step,
                    compact: compact,
                    veryCompact: veryCompact,
                  ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(wide ? 20 : 8, veryCompact ? 3 : 8, wide ? 20 : 8, veryCompact ? 6 : 14),
                    child: _sessionComplete ? _completionView() : (wide ? _wideLayout() : _narrowLayout(compact: compact, veryCompact: veryCompact)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _wideLayout() => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: _isScenario ? 5 : 4, child: _flightPanel()),
          const SizedBox(width: 16),
          Expanded(flex: _isScenario ? 5 : 6, child: _radioPanel()),
        ],
      );

  Widget _narrowLayout({required bool compact, required bool veryCompact}) => Column(
        children: [
          SizedBox(
            height: veryCompact ? 38 : 44,
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, icon: Icon(Icons.radio, size: 18), label: Text('RADIO')),
                ButtonSegment(value: 1, icon: Icon(Icons.map_outlined, size: 18), label: Text('SITUATION')),
              ],
              selected: {_mobileView},
              onSelectionChanged: (v) => setState(() => _mobileView = v.first),
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
          ),
          SizedBox(height: veryCompact ? 5 : 8),
          Expanded(child: _mobileView == 0 ? _radioPanel(compact: compact, veryCompact: veryCompact) : _flightPanel()),
        ],
      );

  Widget _flightPanel() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isScenario)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.panel,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF263744)),
              ),
              child: const Text(
                'SCENARIOLÄGE  •  Kontrollerad miljö  •  Kontakt etablerad  •  Tidigare radiohändelser behålls',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          Expanded(child: RadarPanel()),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusChip(label: 'ANROPSSIGNAL', value: _step.expected.callsign),
              const StatusChip(label: 'TJÄNST', value: 'ATC'),
              if (_step.expected.runway != null) StatusChip(label: 'BANA', value: _step.expected.runway!),
              if (_step.expected.qnh != null) StatusChip(label: 'QNH', value: _step.expected.qnh!),
              if (_step.expected.squawk != null) StatusChip(label: 'TRANSPONDER', value: _step.expected.squawk!),
            ],
          ),
        ],
      );

  Widget _radioPanel({bool compact = false, bool veryCompact = false}) => Container(
        padding: EdgeInsets.all(veryCompact ? 9 : compact ? 12 : 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0D161F),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF22313E)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.radio, color: AppTheme.accent, size: veryCompact ? 20 : 24),
                const SizedBox(width: 8),
                Expanded(child: Text(_isScenario ? 'Radio · Scenario' : 'Radio · Övning', style: TextStyle(fontSize: veryCompact ? 15 : 18, fontWeight: FontWeight.w700))),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: veryCompact ? 8 : 10, vertical: veryCompact ? 4 : 6),
                  decoration: BoxDecoration(color: AppTheme.panelElevated, borderRadius: BorderRadius.circular(10)),
                  child: Text(_step.frequency, style: TextStyle(fontWeight: FontWeight.w700, fontSize: veryCompact ? 12 : 14)),
                ),
              ],
            ),
            SizedBox(height: veryCompact ? 6 : 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _isSpeakingAtc ? null : _speakCurrentAtc,
                  icon: _isSpeakingAtc
                      ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.volume_up_outlined, size: 18),
                  label: Text(_isSpeakingAtc ? 'LADDAR LJUD…' : 'LYSSNA IGEN'),
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _showAtcPromptText = !_showAtcPromptText),
                  icon: Icon(_showAtcPromptText ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                  label: Text(_showAtcPromptText ? 'DÖLJ TEXT' : 'VISA TEXT'),
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                ),
                ChoiceChip(
                  label: Text(_speechEngine == SpeechEngine.realtime ? 'RÖST · REALTIME' : 'RÖST · TTS BAS'),
                  selected: _speechEngine == SpeechEngine.realtime,
                  onSelected: _isSpeakingAtc
                      ? null
                      : (_) => setState(() {
                            _speechEngine = _speechEngine == SpeechEngine.realtime
                                ? SpeechEngine.ttsBaseline
                                : SpeechEngine.realtime;
                            _speechError = null;
                          }),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (_speechError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_speechError!, style: const TextStyle(color: AppTheme.warning, fontSize: 11)),
              ),
            SizedBox(height: veryCompact ? 5 : 9),
            if (_step.coachNote != null && !veryCompact)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accent.withValues(alpha: .18)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 18, color: AppTheme.accent),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_step.coachNote!, style: const TextStyle(color: AppTheme.textMuted))),
                  ],
                ),
              ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(15)),
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _events.length,
                  itemBuilder: (context, index) {
                    final e = _events[index];
                    final pilot = e.speaker != 'ATC';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 62,
                            child: Text(e.speaker, style: TextStyle(fontWeight: FontWeight.w700, color: e.isError ? AppTheme.danger : (pilot ? AppTheme.accent : AppTheme.warning))),
                          ),
                          Expanded(
                            child: Text(
                              e.isPrompt && !_showAtcPromptText
                                  ? 'ATC-meddelande dolt · lyssna på radion.'
                                  : e.text,
                              style: TextStyle(
                                color: e.isError
                                    ? AppTheme.danger
                                    : e.isPrompt && !_showAtcPromptText
                                        ? AppTheme.textMuted
                                        : null,
                                fontStyle: e.isPrompt && !_showAtcPromptText ? FontStyle.italic : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            SizedBox(height: veryCompact ? 5 : 10),
            if (!veryCompact) ...[
              TextField(
                controller: _controller,
                enabled: _result?.isComplete != true,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _transmit(),
                decoration: InputDecoration(
                  hintText: _result?.isComplete == true ? 'Korrekt – gå vidare' : 'Skriv din återläsning här…',
                  prefixIcon: const Icon(Icons.keyboard),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _result?.isComplete == true || _isTranscribing ? null : () => _transmit(),
                      icon: const Icon(Icons.keyboard),
                      label: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('SKICKA TEXT')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            _pttButton(),
            _voiceStatus(),
            SizedBox(height: veryCompact ? 6 : 10),
            ReadbackCard(result: _result, onNext: _result?.isComplete == true ? _nextStep : null, isLastStep: _stepIndex == _steps.length - 1),
          ],
        ),
      );

  Widget _completionView() {
    final successfulFirstTry = _steps.length - _stepsWithRetry.length;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(color: AppTheme.panel, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFF263744))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.check_circle, size: 58, color: AppTheme.accent),
              const SizedBox(height: 14),
              Text(_isScenario ? 'Scenario klart' : 'Återläsningsövning klar', textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                _isScenario
                    ? 'Du har genomfört den första sammanhängande scenariosekvensen. Radiohistorik och anropssignalens status har följt med mellan stegen.'
                    : 'Du har genomfört ${_steps.length} fristående återläsningsövningar. Varje övning bedöms som en egen mikroövning.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textMuted),
              ),
              const SizedBox(height: 22),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  _Metric(label: _isScenario ? 'HÄNDELSER' : 'ÖVNINGAR', value: '${_steps.length}'),
                  _Metric(label: 'SÄNDNINGAR', value: '$_attempts'),
                  _Metric(label: 'UTAN OMFÖRSÖK', value: '$successfulFirstTry/${_steps.length}'),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.accent.withValues(alpha: .20)),
                ),
                child: const Text(
                  'Som testpilot: notera gärna om taligenkänningen misstolkade något, om återkopplingen kändes rimlig och om någon radioreplik kändes onaturlig.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMuted, height: 1.35),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(onPressed: _restart, icon: const Icon(Icons.replay), label: const Padding(padding: EdgeInsets.symmetric(vertical: 13), child: Text('KÖR IGEN'))),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.mode,
    required this.stepIndex,
    required this.count,
    required this.step,
    required this.compact,
    required this.veryCompact,
  });
  final PracticeMode mode;
  final int stepIndex;
  final int count;
  final TrainingStep step;
  final bool compact;
  final bool veryCompact;

  @override
  Widget build(BuildContext context) {
    final label = mode == PracticeMode.drillReadback ? 'ÖVNING · ÅTERLÄSNING' : 'SCENARIO';
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 10 : 20, 2, compact ? 10 : 20, veryCompact ? 3 : 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (!veryCompact) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(8)),
                  child: Text(label, style: const TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: .6)),
                ),
                const SizedBox(width: 10),
              ],
              Text('${stepIndex + 1}/$count', style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w700, fontSize: veryCompact ? 12 : 14)),
              const SizedBox(width: 9),
              Expanded(child: Text(step.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: veryCompact ? 13 : 14))),
            ],
          ),
          if (!veryCompact) ...[
            const SizedBox(height: 4),
            Text(step.instruction, maxLines: compact ? 1 : 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textMuted)),
          ],
          SizedBox(height: veryCompact ? 3 : 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(minHeight: veryCompact ? 3 : 5, value: (stepIndex + 1) / count, backgroundColor: AppTheme.panelElevated, color: AppTheme.accent),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
        width: 150,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(color: AppTheme.panelElevated, borderRadius: BorderRadius.circular(14)),
        child: Column(children: [Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)), const SizedBox(height: 2), Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted, letterSpacing: .8))]),
      );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.mode,
    required this.onModeChanged,
    required this.compact,
    required this.veryCompact,
  });
  final PracticeMode mode;
  final ValueChanged<PracticeMode> onModeChanged;
  final bool compact;
  final bool veryCompact;

  @override
  Widget build(BuildContext context) {
    final modeSelector = SegmentedButton<PracticeMode>(
      segments: [
        ButtonSegment(
          value: PracticeMode.drillReadback,
          label: Text(compact ? 'ÖVNING' : 'ÖVNING · ÅTERLÄSNING'),
          icon: const Icon(Icons.repeat, size: 18),
        ),
        const ButtonSegment(value: PracticeMode.scenario, label: Text('SCENARIO'), icon: Icon(Icons.route_outlined, size: 18)),
      ],
      selected: {mode},
      onSelectionChanged: (values) => onModeChanged(values.first),
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
    );

    if (compact) {
      return Padding(
        padding: EdgeInsets.fromLTRB(veryCompact ? 8 : 10, veryCompact ? 4 : 7, veryCompact ? 8 : 10, 3),
        child: Row(
          children: [
            Container(
              width: veryCompact ? 30 : 34,
              height: veryCompact ? 30 : 34,
              decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.flight, color: AppTheme.background, size: veryCompact ? 18 : 21),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                veryCompact ? 'RT TRAINER · v0.5.4' : 'RT TRAINER',
                style: TextStyle(fontSize: veryCompact ? 14 : 16, fontWeight: FontWeight.w800, letterSpacing: .6),
              ),
            ),
            Flexible(flex: 2, child: modeSelector),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
      child: Row(
        children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.flight, color: AppTheme.background)),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('RT TRAINER', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: .8)), Text('Demo v0.5.4 · Träning i radiotelefoni', style: TextStyle(fontSize: 11, color: AppTheme.textMuted))]),
          ),
          modeSelector,
        ],
      ),
    );
  }
}

