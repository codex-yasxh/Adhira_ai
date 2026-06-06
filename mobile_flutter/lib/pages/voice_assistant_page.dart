import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/health_assistant_api_service.dart';

enum _VoiceState { idle, listening, thinking, speaking }

class VoiceAssistantPage extends StatefulWidget {
  const VoiceAssistantPage({super.key});

  @override
  State<VoiceAssistantPage> createState() => _VoiceAssistantPageState();
}

class _VoiceAssistantPageState extends State<VoiceAssistantPage>
    with TickerProviderStateMixin {
  late final stt.SpeechToText _stt;
  late final FlutterTts _tts;

  // Orb color tween
  late final AnimationController _orbController;
  // Waveform bars — one controller, staggered intervals per bar
  late final AnimationController _waveController;
  // Thinking ring rotation
  late final AnimationController _rotateController;

  _VoiceState _state = _VoiceState.idle;
  String _transcript = '';
  String _response = '';
  bool _sttReady = false;
  Timer? _debounce;

  final List<Map<String, String>> _history = [];

  // 5 bars, each gets a phase offset so they ripple
  static const int _barCount = 5;
  static const List<double> _barPhases = [0.0, 0.15, 0.3, 0.15, 0.0];

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _stt = stt.SpeechToText();
    _tts = FlutterTts();
    _init();
  }

  Future<void> _init() async {
    final ok = await _stt.initialize(
      onError: (_) {
        if (mounted && _state == _VoiceState.listening) {
          _debounce?.cancel();
          _setVoiceState(_VoiceState.idle);
        }
      },
      onStatus: (s) => debugPrint('STT Status: $s | transcript="$_transcript"'),
    );
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _tts.setCompletionHandler(_onTtsDone);
    _tts.setErrorHandler((_) => _onTtsDone());
    if (mounted) setState(() => _sttReady = ok);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _orbController.dispose();
    _waveController.dispose();
    _rotateController.dispose();
    _stt.stop();
    _tts.stop();
    super.dispose();
  }

  // ── State machine ────────────────────────────────────────────────────────

  void _setVoiceState(_VoiceState next) {
    if (!mounted) return;
    setState(() => _state = next);
    _orbController.stop();
    _waveController.stop();
    _rotateController.stop();
    switch (next) {
      case _VoiceState.listening:
        _waveController.repeat(reverse: true);
      case _VoiceState.thinking:
        _rotateController.repeat();
        _orbController.repeat(reverse: true);
      case _VoiceState.speaking:
        _waveController.repeat(reverse: true);
      case _VoiceState.idle:
        break;
    }
  }

  // ── Orb tap ──────────────────────────────────────────────────────────────

  Future<void> _onOrbTap() async {
    if (!_sttReady || _state == _VoiceState.thinking) return;
    if (_state == _VoiceState.listening) {
      _debounce?.cancel();
      await _stt.stop();
      _setVoiceState(_VoiceState.idle);
      return;
    }
    if (_state == _VoiceState.speaking) {
      await _tts.stop();
      _setVoiceState(_VoiceState.idle);
      return;
    }
    // idle → listening
    setState(() => _transcript = '');
    _setVoiceState(_VoiceState.listening);
    await _stt.listen(
      onResult: (r) {
        debugPrint('STT Result: "${r.recognizedWords}" final=${r.finalResult}');
        if (!mounted) return;
        setState(() => _transcript = r.recognizedWords);
        if (_transcript.trim().isEmpty) return;
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 2500), () {
          if (mounted && _state == _VoiceState.listening) {
            _sendToApi(_transcript.trim());
          }
        });
      },
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 8),
      partialResults: true,
    );
  }

  // ── API call ─────────────────────────────────────────────────────────────

  Future<void> _sendToApi(String text) async {
    if (_state == _VoiceState.thinking || _state == _VoiceState.speaking) return;
    debugPrint('SENDING TO API: "$text"');
    _setVoiceState(_VoiceState.thinking);
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final reply = await HealthAssistantApiService().sendMessage(
      query: text,
      userId: userId,
      history: List.unmodifiable(_history),
    );
    _history.add({'role': 'user', 'content': text});
    _history.add({'role': 'assistant', 'content': reply});
    if (_history.length > 12) _history.removeRange(0, 2);
    if (!mounted) return;
    setState(() => _response = reply);
    _setVoiceState(_VoiceState.speaking);
    await _tts.speak(reply);
  }

  void _onTtsDone() {
    if (mounted) _setVoiceState(_VoiceState.idle);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Color _orbColor() => switch (_state) {
        _VoiceState.idle => const Color(0xFF2A6BFF),
        _VoiceState.listening => const Color(0xFF34D399),
        _VoiceState.thinking => const Color(0xFFA78BFA),
        _VoiceState.speaking => const Color(0xFF60A5FA),
      };

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      body: SafeArea(
        child: Stack(
          children: [
            // Background glow
            Positioned(
              top: -80,
              right: -70,
              child: Container(
                width: 260,
                height: 260,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x332A6BFF), Color(0x00102440)],
                  ),
                ),
              ),
            ),
            Column(
              children: [
                _buildTopBar(),
                Expanded(child: _buildCenter()),
                _buildEndButton(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Color(0xFFB8BEC9), size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          const Text(
            'Voice Mode',
            style: TextStyle(
              color: Color(0xFFB8BEC9),
              fontSize: 15,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.4,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildCenter() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildOrb(),
        const SizedBox(height: 28),
        // Waveform — fixed height so nothing below it ever shifts
        SizedBox(height: 48, child: _buildWaveform()),
        const SizedBox(height: 24),
        _buildStatusText(),
        const SizedBox(height: 20),
        // Fixed-height text zone — card is always present, content fades
        _buildTextZone(),
      ],
    );
  }

  // ── Orb ──────────────────────────────────────────────────────────────────

  Widget _buildOrb() {
    return GestureDetector(
      onTap: _onOrbTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_orbController, _rotateController]),
        builder: (context, _) {
          final orbColor = _orbColor();
          // Thinking: orb breathes via _orbController
          final glowOpacity = _state == _VoiceState.thinking
              ? 0.25 + 0.20 * _orbController.value
              : _state == _VoiceState.idle
                  ? 0.15
                  : 0.35;

          return Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  orbColor.withOpacity(0.88),
                  orbColor.withOpacity(0.28),
                  const Color(0xFF050510),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: orbColor.withOpacity(glowOpacity),
                  blurRadius: 56,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: _buildOrbIcon(orbColor),
          );
        },
      ),
    );
  }

  Widget _buildOrbIcon(Color orbColor) {
    if (_state == _VoiceState.thinking) {
      return AnimatedBuilder(
        animation: _rotateController,
        builder: (_, __) => Transform.rotate(
          angle: _rotateController.value * 2 * math.pi,
          child: const Icon(Icons.autorenew_rounded, color: Colors.white, size: 38),
        ),
      );
    }
    final icon = switch (_state) {
      _VoiceState.idle => Icons.mic_none_rounded,
      _VoiceState.listening => Icons.mic_rounded,
      _VoiceState.thinking => Icons.autorenew_rounded,
      _VoiceState.speaking => Icons.volume_up_rounded,
    };
    return Icon(icon, color: Colors.white, size: 38);
  }

  // ── Waveform ─────────────────────────────────────────────────────────────

  Widget _buildWaveform() {
    final bool active =
        _state == _VoiceState.listening || _state == _VoiceState.speaking;
    final Color barColor = _orbColor();

    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(_barCount, (i) {
            double height;
            if (!active) {
              // Idle / thinking: all bars at minimum
              height = 4;
            } else {
              // Each bar uses a sine wave with a phase offset so they ripple
              final phase = _barPhases[i];
              final t = (_waveController.value + phase) % 1.0;
              height = 8 + 28 * math.sin(t * math.pi).clamp(0.0, 1.0);
            }
            return AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 4,
              height: height,
              decoration: BoxDecoration(
                color: active
                    ? barColor.withOpacity(0.85)
                    : const Color(0xFF2A2A3E),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }

  // ── Status text ───────────────────────────────────────────────────────────

  Widget _buildStatusText() {
    final label = switch (_state) {
      _VoiceState.idle => 'Tap to start talking',
      _VoiceState.listening => 'Listening\u2026',
      _VoiceState.thinking => 'Adhira is thinking\u2026',
      _VoiceState.speaking => 'Speaking\u2026',
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        label,
        key: ValueKey(_state),
        style: const TextStyle(
          color: Color(0xFFB8BEC9),
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // ── Text zone — fixed height, no layout shift ─────────────────────────────

  Widget _buildTextZone() {
    final text = switch (_state) {
      _VoiceState.listening => _transcript,
      _VoiceState.speaking => _response,
      _ => '',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, minHeight: 80, maxHeight: 120),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF131726),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF242B3F)),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            // Cross-fade only the text, not the container — no flicker
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: text.isEmpty
                ? const SizedBox.shrink()
                : Text(
                    text,
                    // Stable key based on state only, not transcript content.
                    // Partial updates reuse the same widget and update in place.
                    key: ValueKey(_state),
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFF9FAFB),
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // ── End button ────────────────────────────────────────────────────────────

  Widget _buildEndButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: TextButton(
        onPressed: () => Navigator.of(context).pop(),
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF8C93A0),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          side: const BorderSide(color: Color(0xFF2A2A3E)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        child: const Text('End Conversation',
            style: TextStyle(fontSize: 14, letterSpacing: 0.3)),
      ),
    );
  }
}
