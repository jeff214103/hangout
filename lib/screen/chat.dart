import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:hangout/providers/setting_provider.dart';
import 'package:hangout/widget/gemini.dart';
import 'package:hangout/widget/loading_hint.dart';
import 'package:provider/provider.dart';

class ChatPage extends StatefulWidget {
  final String initialPrompt;

  const ChatPage({
    super.key,
    required this.initialPrompt,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final GenerativeModel _model;
  late final ChatSession _chat;
  bool _isInitializing = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(
      model: Provider.of<SettingProvider>(context, listen: false).geminiModel,
      apiKey: Provider.of<SettingProvider>(context, listen: false).geminiAPIKey,
    );
    _chat = _model.startChat();

    // Send initial prompt when the chat page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendInitialPrompt();
    });
  }

  Future<void> _sendInitialPrompt() async {
    try {
      setState(() {
        _isInitializing = true;
        _error = null;
      });

      await _chat.sendMessage(Content.text(widget.initialPrompt));

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _error = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hangout Suggestions'),
      ),
      body: _isInitializing
          ? const Center(
              child: LoadingHint(
                text: 'Generating your hangout...',
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Error: $_error',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _sendInitialPrompt,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : GeminiChatWidget(
                  chat: _chat,
                  shortcuts: (controller) => [
                    GeminiActionChip(
                      name: 'Regenerate',
                      tooltip:
                          'Suggest another schedule with the same preferences',
                      onPressed: ()  {
                        controller.text = "Suggest another schedule with the same preferences";
                      },
                    ),
                  ],
                ),
    );
  }
}
