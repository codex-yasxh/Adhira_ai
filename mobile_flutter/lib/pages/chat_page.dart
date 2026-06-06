import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

import '../core/medicine_store.dart';
import '../services/health_assistant_api_service.dart';
import 'profile_page.dart';
import 'voice_assistant_page.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _inputController = TextEditingController();
  final List<_ChatMessage> _messages = <_ChatMessage>[];
  bool _isRecording = false;
  bool _isLoading = false;

  // --- Attachment state ---
  File? _attachedFile;
  String? _attachedFileName;
  String? _attachedMimeType;
  // Stores the last analysed document text/context for follow-up questions
  String? _documentContext;

  late final stt.SpeechToText _stt;
  late final FlutterTts _tts;
  bool _sttInitialized = false;
  String? _speakingMessageIndex;

  static const List<String> _quickChips = <String>[
    'What should I eat today?',
    'Why do I feel tired lately?',
    'How much water should I drink?',
    'What are signs of high blood pressure?',
  ];

  @override
  void dispose() {
    _inputController.dispose();
    if (_isRecording) _stt.stop();
    _tts.stop();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _stt = stt.SpeechToText();
    _tts = FlutterTts();
    _initSpeech();
    _initTts();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _stt.initialize(
        onError: (error) {
          debugPrint('STT Error: $error');
          if (mounted) setState(() => _isRecording = false);
        },
        onStatus: (status) {
          debugPrint('STT Status: $status');
          if ((status == 'done' || status == 'notListening') && mounted) {
            setState(() => _isRecording = false);
          }
        },
      );
      if (mounted) setState(() => _sttInitialized = available);
    } catch (_) {}
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _tts.setCompletionHandler(() {
        if (mounted) setState(() => _speakingMessageIndex = null);
      });

      _tts.setErrorHandler((message) {
        if (mounted) setState(() => _speakingMessageIndex = null);
      });
    } catch (_) {}
  }

  Future<void> _toggleMic() async {
    if (!_sttInitialized) return;

    if (_isRecording) {
      await _stt.stop();
      if (mounted) setState(() => _isRecording = false);
      return;
    }

    if (mounted) setState(() => _isRecording = true);
    await _stt.listen(
      onResult: (result) {
        if (mounted) setState(() => _inputController.text = result.recognizedWords);
      },
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 8),
      partialResults: true,
    );
  }

  Future<void> _speakMessage(String text, String messageId) async {
    try {
      if (_speakingMessageIndex == messageId) {
        await _tts.stop();
        if (mounted) setState(() => _speakingMessageIndex = null);
      } else {
        if (_speakingMessageIndex != null) {
          await _tts.stop();
        }
        if (mounted) setState(() => _speakingMessageIndex = messageId);
        await _tts.speak(text);
      }
    } catch (_) {}
  }

  void _onChipTap(String label) {
    _inputController.text = label;
    _inputController.selection = TextSelection.fromPosition(
      TextPosition(offset: _inputController.text.length),
    );
    setState(() {});
  }

  void _newChat() {
    _tts.stop();
    if (_isRecording) _stt.stop();
    setState(() {
      _messages.clear();
      _inputController.clear();
      _isRecording = false;
      _isLoading = false;
      _speakingMessageIndex = null;
      _attachedFile = null;
      _attachedFileName = null;
      _attachedMimeType = null;
      _documentContext = null;
    });
  }

  void _handleSend() async {
    final String text = _inputController.text.trim();
    final File? file = _attachedFile;
    final String? mimeType = _attachedMimeType;
    final String? fileName = _attachedFileName;

    if (text.isEmpty && file == null) return;

    final String displayText = text.isNotEmpty ? text : 'Please explain this document.';

    setState(() {
      _messages.add(_ChatMessage(text: displayText, isUser: true, attachmentName: fileName));
      _inputController.clear();
      _attachedFile = null;
      _attachedFileName = null;
      _attachedMimeType = null;
      _isLoading = true;
    });

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      final api = HealthAssistantApiService();
      String reply;

      if (file != null && mimeType != null) {
        // First-time document send → analyse via Gemini Vision / PDF
        reply = await api.analyzeDocument(
          file: file,
          mimeType: mimeType,
          question: displayText,
        );
        // Store the reply as document context for follow-up questions
        if (mounted) setState(() => _documentContext = reply);
      } else if (_documentContext != null) {
        // Follow-up question: inject document context into conversation history
        final history = [
          {'role': 'assistant', 'content': 'Document analysis: $_documentContext'},
          ..._messages
              .skip(_messages.length > 5 ? _messages.length - 5 : 0)
              .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text}),
        ];
        reply = await api.sendMessage(
          query: displayText,
          userId: userId,
          history: history,
          medicineNames: MedicineStore.instance.names,
        );
      } else {
        // Normal chat
        final history = _messages
            .skip(_messages.length > 6 ? _messages.length - 6 : 0)
            .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text})
            .toList();
        reply = await api.sendMessage(
          query: displayText,
          userId: userId,
          history: history,
          medicineNames: MedicineStore.instance.names,
        );
      }

      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(text: reply, isUser: false));
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(text: 'Something went wrong, try again.', isUser: false));
          _isLoading = false;
        });
      }
    }
  }

  void _removeAttachment() {
    setState(() {
      _attachedFile = null;
      _attachedFileName = null;
      _attachedMimeType = null;
    });
  }

  Future<void> _showAttachmentPicker() async {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141420),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A3E),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            _AttachOption(
              icon: Icons.camera_alt_outlined,
              label: 'Camera',
              onTap: () async {
                Navigator.pop(context);
                final picked = await ImagePicker().pickImage(
                  source: ImageSource.camera,
                  imageQuality: 85,
                );
                if (picked != null) _setAttachment(File(picked.path), picked.name, 'image/jpeg');
              },
            ),
            _AttachOption(
              icon: Icons.photo_library_outlined,
              label: 'Gallery',
              onTap: () async {
                Navigator.pop(context);
                final picked = await ImagePicker().pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                );
                if (picked != null) {
                  final mime = picked.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
                  _setAttachment(File(picked.path), picked.name, mime);
                }
              },
            ),
            _AttachOption(
              icon: Icons.picture_as_pdf_outlined,
              label: 'PDF Document',
              onTap: () async {
                Navigator.pop(context);
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['pdf'],
                );
                if (result != null && result.files.single.path != null) {
                  _setAttachment(
                    File(result.files.single.path!),
                    result.files.single.name,
                    'application/pdf',
                  );
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _setAttachment(File file, String name, String mime) {
    setState(() {
      _attachedFile = file;
      _attachedFileName = name;
      _attachedMimeType = mime;
      // Clear previous document context when new file is attached
      _documentContext = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool hasMessages = _messages.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xFF050510),
                Color(0xFF040713),
                Color(0xFF050510),
              ],
              stops: <double>[0.0, 0.45, 1.0],
            ),
          ),
          child: Stack(
            children: <Widget>[
              Positioned(
                top: -80,
                right: -70,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[Color(0x332A6BFF), Color(0x00102440)],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: hasMessages ? _buildChatState() : _buildEmptyState(),
              ),
              if (!hasMessages)
                const Positioned(
                  top: 10,
                  right: 12,
                  child: _ProfileIcon(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatState() {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 8, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: _newChat,
                tooltip: 'New chat',
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  foregroundColor: const Color(0xFFB8BEC9),
                  backgroundColor: Colors.transparent,
                ),
                icon: const Icon(Icons.edit_outlined, size: 20),
              ),
              const Expanded(
                child: Text(
                  'ADHIRA',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const _ProfileIcon(),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: ListView.separated(
                  itemCount: _messages.length + (_isLoading ? 1 : 0),
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (BuildContext context, int index) {
                    if (_isLoading && index == _messages.length) {
                      return const _TypingIndicator();
                    }
                    final _ChatMessage msg = _messages[index];
                    final String msgId = 'msg_$index';
                    return _MessageBubble(
                      message: msg.text,
                      isUser: msg.isUser,
                      isSpeaking: _speakingMessageIndex == msgId,
                      onSpeak: msg.isUser ? null : () => _speakMessage(msg.text, msgId),
                      attachmentName: msg.attachmentName,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_attachedFile != null)
                    _AttachmentPreview(
                      fileName: _attachedFileName ?? 'Attached file',
                      mimeType: _attachedMimeType ?? '',
                      onRemove: _removeAttachment,
                    ),
                  _InputBox(
                    controller: _inputController,
                    isRecording: _isRecording,
                    hasAttachment: _attachedFile != null,
                    onMicTap: _toggleMic,
                    onSendTap: _isLoading ? () {} : _handleSend,
                    onChanged: (_) => setState(() {}),
                    onAttachTap: _showAttachmentPicker,
                    onVoiceModeTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const VoiceAssistantPage()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 14),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - 34),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const _TitleBlock(),
                const SizedBox(height: 32),
                _QuickChips(
                  chips: _quickChips,
                  onChipTap: _onChipTap,
                ),
                const SizedBox(height: 20),
                if (_attachedFile != null)
                  _AttachmentPreview(
                    fileName: _attachedFileName ?? 'Attached file',
                    mimeType: _attachedMimeType ?? '',
                    onRemove: _removeAttachment,
                  ),
                _InputBox(
                  controller: _inputController,
                  isRecording: _isRecording,
                  hasAttachment: _attachedFile != null,
                  onMicTap: _toggleMic,
                  onSendTap: _handleSend,
                  onChanged: (_) => setState(() {}),
                  onAttachTap: _showAttachmentPicker,
                  onVoiceModeTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const VoiceAssistantPage()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock();

  @override
  Widget build(BuildContext context) {
    final bool isCompact = MediaQuery.of(context).size.width < 380;
    return Column(
      children: <Widget>[
        Text(
          'ADHIRA',
          style: TextStyle(
            fontSize: isCompact ? 34 : 42,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'How can I help you today?',
          style: TextStyle(
            color: Color(0xFFB8BEC9),
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _QuickChips extends StatelessWidget {
  const _QuickChips({
    required this.chips,
    required this.onChipTap,
  });

  final List<String> chips;
  final ValueChanged<String> onChipTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: chips
            .map(
              (String chip) => ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 42),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x0A2B6CFF),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ActionChip(
                    label: Text(
                      chip,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFB8BEC9), fontSize: 12.5),
                    ),
                    backgroundColor: const Color(0xFF141420),
                    side: const BorderSide(color: Color(0xFF2A2A3E)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                    pressElevation: 0,
                    shadowColor: Colors.transparent,
                    onPressed: () => onChipTap(chip),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _InputBox extends StatelessWidget {
  const _InputBox({
    required this.controller,
    required this.isRecording,
    required this.hasAttachment,
    required this.onMicTap,
    required this.onSendTap,
    required this.onChanged,
    required this.onVoiceModeTap,
    required this.onAttachTap,
  });

  final TextEditingController controller;
  final bool isRecording;
  final bool hasAttachment;
  final VoidCallback onMicTap;
  final VoidCallback onSendTap;
  final ValueChanged<String> onChanged;
  final VoidCallback onVoiceModeTap;
  final VoidCallback onAttachTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isNarrow = constraints.maxWidth < 420;

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141420),
            border: Border.all(color: const Color(0xFF2A2A3E)),
            borderRadius: BorderRadius.circular(isNarrow ? 16 : 20),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isNarrow ? 8 : 12,
            vertical: isNarrow ? 8 : 10,
          ),
          child: Row(
            children: <Widget>[
              IconButton(
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                onPressed: onAttachTap,
                style: IconButton.styleFrom(
                  foregroundColor: hasAttachment
                      ? const Color(0xFF60A5FA)
                      : const Color(0xFFB8BEC9),
                  backgroundColor: hasAttachment
                      ? const Color(0x1A60A5FA)
                      : Colors.transparent,
                ),
                icon: Icon(Icons.attach_file, size: isNarrow ? 18 : 20),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  onSubmitted: (_) => onSendTap(),
                  style: TextStyle(color: Colors.white, fontSize: isNarrow ? 15 : 16),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'What do you want to know?',
                    hintStyle: TextStyle(
                      color: const Color(0xFF8C93A0),
                      fontSize: isNarrow ? 14 : 16,
                    ),
                    isCollapsed: true,
                  ),
                  minLines: 1,
                  maxLines: 3,
                ),
              ),
              SizedBox(width: isNarrow ? 4 : 8),
              if (!isNarrow)
                TextButton.icon(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFB8BEC9),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                    minimumSize: const Size(0, 36),
                  ),
                  icon: const Icon(Icons.radio_button_checked, size: 14),
                  label: const Text('Auto'),
                ),
              IconButton(
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                onPressed: onMicTap,
                style: IconButton.styleFrom(
                  backgroundColor: isRecording ? const Color(0x33EF4444) : const Color(0xFF1E2230),
                  foregroundColor: isRecording ? const Color(0xFFF87171) : const Color(0xFFB8BEC9),
                ),
                icon: Icon(isRecording ? Icons.stop_circle_outlined : Icons.mic, size: isNarrow ? 18 : 19),
              ),
              const SizedBox(width: 4),
              IconButton(
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                onPressed: onVoiceModeTap,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF1E2230),
                  foregroundColor: const Color(0xFFB8BEC9),
                ),
                icon: Icon(Icons.spatial_audio_off_rounded, size: isNarrow ? 17 : 18),
              ),
              const SizedBox(width: 4),
              IconButton(
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                onPressed: onSendTap,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF1E2230),
                  foregroundColor: Colors.white,
                ),
                icon: Icon(Icons.send_rounded, size: isNarrow ? 17 : 18),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isUser,
    this.isSpeaking = false,
    this.onSpeak,
    this.attachmentName,
  });

  final String message;
  final bool isUser;
  final bool isSpeaking;
  final VoidCallback? onSpeak;
  final String? attachmentName;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF131726),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUser ? const Color(0xFF2C3552) : const Color(0xFF242B3F),
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x0D2B6CFF),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: onSpeak != null
                  ? const EdgeInsets.only(bottom: 18)
                  : EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (attachmentName != null) ...[
                    _AttachmentChip(fileName: attachmentName!),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    message,
                    style: const TextStyle(
                      color: Color(0xFFF9FAFB),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (onSpeak != null)
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: onSpeak,
                  child: Icon(
                    isSpeaking ? Icons.volume_up : Icons.volume_up_outlined,
                    size: 14,
                    color: isSpeaking
                        ? const Color(0xFF60A5FA)
                        : const Color(0xFF4A5568),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF131726),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF242B3F),
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x0D2B6CFF),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _AnimatedDot(
              animation: Tween<double>(begin: 0, end: 1)
                  .animate(CurvedAnimation(
                    parent: _controller,
                    curve: const Interval(0.0, 0.33),
                  )),
            ),
            const SizedBox(width: 4),
            _AnimatedDot(
              animation: Tween<double>(begin: 0, end: 1)
                  .animate(CurvedAnimation(
                    parent: _controller,
                    curve: const Interval(0.33, 0.66),
                  )),
            ),
            const SizedBox(width: 4),
            _AnimatedDot(
              animation: Tween<double>(begin: 0, end: 1)
                  .animate(CurvedAnimation(
                    parent: _controller,
                    curve: const Interval(0.66, 1.0),
                  )),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedDot extends StatelessWidget {
  const _AnimatedDot({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -4 * animation.value),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Color(0xFF8C93A0).withOpacity(0.5 + 0.5 * animation.value),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

class _ProfileIcon extends StatefulWidget {
  const _ProfileIcon();

  @override
  State<_ProfileIcon> createState() => _ProfileIconState();
}

class _ProfileIconState extends State<_ProfileIcon> {
  String? _initial;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    // Set a quick initial from already-cached user before async fetch
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      _initial = (user.email?[0] ?? 'A').toUpperCase();
    }
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Check avatar_url from metadata first
      final meta = user.userMetadata;
      if (meta != null && meta['avatar_url'] != null) {
        if (mounted) setState(() => _avatarUrl = meta['avatar_url'] as String);
        return;
      }

      // Fallback: fetch name from public.users
      final res = await Supabase.instance.client
          .from('users')
          .select('name')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted) return;
      final String? name = res?['name'] as String?;
      if (name != null && name.isNotEmpty) {
        setState(() => _initial = name[0].toUpperCase());
      } else {
        setState(() => _initial = (user.email?[0] ?? 'A').toUpperCase());
      }
    } catch (_) {
      if (mounted) setState(() => _initial = 'A');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ProfilePage()),
      ),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF2A2A3E)),
          color: const Color(0xFF121725),
        ),
        child: ClipOval(
          child: _avatarUrl != null
              ? Image.network(_avatarUrl!, fit: BoxFit.cover)
              : Center(
                  child: Text(
                    _initial ?? '?',
                    style: const TextStyle(
                      color: Color(0xFF60A5FA),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

// --- Attachment preview strip shown above the input box ---
class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({
    required this.fileName,
    required this.mimeType,
    required this.onRemove,
  });

  final String fileName;
  final String mimeType;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final bool isPdf = mimeType == 'application/pdf';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A3550)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
            size: 16,
            color: isPdf ? const Color(0xFFFF6B6B) : const Color(0xFF60A5FA),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              fileName,
              style: const TextStyle(color: Color(0xFFB8BEC9), fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 14, color: Color(0xFF8C93A0)),
          ),
        ],
      ),
    );
  }
}

// --- Small chip shown inside a message bubble when a file was attached ---
class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({required this.fileName});

  final String fileName;

  @override
  Widget build(BuildContext context) {
    final bool isPdf = fileName.toLowerCase().endsWith('.pdf');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2640),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A3550)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
            size: 13,
            color: isPdf ? const Color(0xFFFF6B6B) : const Color(0xFF60A5FA),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              fileName,
              style: const TextStyle(color: Color(0xFF8C93A0), fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Row item in the attachment bottom sheet ---
class _AttachOption extends StatelessWidget {
  const _AttachOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF60A5FA)),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
    );
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.attachmentName,
  });

  final String text;
  final bool isUser;
  final String? attachmentName;
}

