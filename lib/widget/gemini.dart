import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:hangout/providers/setting_provider.dart';
import 'package:hangout/widget/dialog.dart';
import 'package:hangout/widget/loading_hint.dart';
import 'package:provider/provider.dart';

class GeminiDescriptionHelperInput extends StatefulWidget {
  final String aspect;
  final TextEditingController controller;
  final FormFieldValidator<String?>? validator;
  final String? Function() generatePromote;
  final String? enrichPromote;
  final String? optimizePromote;
  const GeminiDescriptionHelperInput(
      {super.key,
      required this.aspect,
      required this.controller,
      this.validator,
      required this.generatePromote,
      this.enrichPromote,
      this.optimizePromote});

  @override
  State<GeminiDescriptionHelperInput> createState() =>
      _GeminiDescriptionHelperState();
}

class _GeminiDescriptionHelperState
    extends State<GeminiDescriptionHelperInput> {
  late final GenerativeModel _model;
  late final ChatSession _chat;
  final geminiResultKey = GlobalKey();
  Future<GenerateContentResponse>? response;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(
      model: Provider.of<SettingProvider>(context, listen: false).geminiModel,
      apiKey: Provider.of<SettingProvider>(context, listen: false).geminiAPIKey,
    );
    _chat = _model.startChat();
  }

  bool promoptParagraphCheck(BuildContext context) {
    if (widget.controller.text.isEmpty) {
      showDialog(
        context: context,
        builder: (BuildContext context) => ConfirmationDialogBody(
          text: 'Some text must be input before using AI prompt',
          actionButtons: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      return false;
    }
    return true;
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(
            milliseconds: 750,
          ),
          curve: Curves.easeOutCirc,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SingleChildScrollView(
          controller: _scrollController,
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.3),
            child: TextFormField(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.multiline,
              maxLines: null,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please input the description';
                }
                return null;
              },
              controller: widget.controller,
            ),
          ),
        ),
        const SizedBox(
          height: 8,
        ),
        SizedBox(
          width: double.infinity,
          child: Wrap(
            children: [
              GeminiActionChip(
                name: 'Generate (Step 0)',
                tooltip:
                    'If you have no idea what to write, it will generate the description base on the information given.',
                onPressed: () async {
                  if (widget.controller.text.isNotEmpty) {
                    final res = await showDialog(
                      context: context,
                      builder: (BuildContext context) => ConfirmationDialogBody(
                        text:
                            'There are already information filled.  Are you tried to continue with AI generation? ',
                        actionButtons: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () {
                              Navigator.of(context).pop(true);
                            },
                            child: const Text('Continue'),
                          ),
                        ],
                      ),
                    );
                    if (res != true) {
                      return;
                    }
                  }
                  String? prompt = widget.generatePromote();
                  if (prompt == null) {
                    return;
                  }
                  setState(() {
                    response = _chat.sendMessage(
                      Content.text(prompt),
                    );

                    _scrollDown();
                  });
                },
              ),
              GeminiActionChip(
                name: 'Enrich (Step 1)',
                tooltip:
                    'It will add more content based on your current input.',
                onPressed: () {
                  if (promoptParagraphCheck(context) == false) {
                    return;
                  }
                  setState(() {
                    response = _chat.sendMessage(
                      Content.text(widget.enrichPromote ??
                          '''You are the one having ${widget.aspect} background from the following text.
                          '${widget.controller.text}'
                        1. Review all the information into point form, 
                        2. Write the elaboration for ${widget.aspect} 
                        3. No response with introduction and closure phrase.
                        4. No limit on the number of bullet points
                        5. Use only the information from the text
                        '''),
                    );
                    _scrollDown();
                  });
                },
              ),
              GeminiActionChip(
                name: 'Optimize (Final)',
                tooltip:
                    'It will optimize for storage and resume generation later',
                onPressed: () {
                  if (promoptParagraphCheck(context) == false) {
                    return;
                  }
                  setState(() {
                    response = _chat.sendMessage(
                      Content.text(widget.optimizePromote ??
                          '''You are the one having ${widget.aspect} background from the following text.
                          '${widget.controller.text}'
                        1. Conclude all the information
                        2. No limit on the number of bullet points
                        3. No response with introduction and closure phrase.
                        4. Rewrite in first person aspect
                        5. Rewrite start with action verb
                        6. Use past tense

                        Strictly return the text as follows
                        - Point 1
                        - Point 2
                        - Point 3
                        ... And more if there exist
                        '''),
                    );

                    _scrollDown();
                  });
                },
              ),
              GeminiActionChip(
                name: 'Custom',
                tooltip: 'Write your own prompt to Gemini',
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return GeminiChatRoomDialog(
                          chat: _chat,
                        );
                      });
                },
              ),
            ],
          ),
        ),
        SizedBox(
            key: geminiResultKey,
            child: (response != null)
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Card(
                      child: Container(
                        width: double.infinity,
                        constraints: BoxConstraints(
                            minHeight: 200,
                            maxHeight:
                                MediaQuery.of(context).size.height * 0.3),
                        child: FutureBuilder(
                          future: response,
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Center(
                                child:
                                    Text("Error: ${snapshot.error.toString()}"),
                              );
                            } else if (snapshot.connectionState ==
                                ConnectionState.done) {
                              if (snapshot.data?.text == null ||
                                  snapshot.hasData == false) {
                                return const Center(
                                  child: Text('Empty response'),
                                );
                              }
                              return Stack(
                                children: [
                                  SingleChildScrollView(
                                    controller: ScrollController(),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 30),
                                        child: SelectableText(
                                            snapshot.data?.text ?? 'No data'),
                                      ),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                          bottom: 2, right: 2),
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          widget.controller.text =
                                              snapshot.data?.text ?? 'No data';
                                          showDialog(
                                            context: context,
                                            builder: (BuildContext context) =>
                                                ConfirmationDialogBody(
                                              text:
                                                  'Remember to do amendment to the response',
                                              actionButtons: [
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.of(context).pop();
                                                  },
                                                  child: const Text('Got it'),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.copy),
                                        label: const Text('Use result'),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            } else {
                              return const LoadingHint(
                                  text: 'Loading from gemini...');
                            }
                          },
                        ),
                      ),
                    ),
                  )
                : null),
      ],
    );
  }
}

class GeminiActionChip extends StatelessWidget {
  const GeminiActionChip(
      {super.key,
      required this.name,
      this.tooltip,
      required this.onPressed,
      this.filled = false});
  final bool filled;
  final String name;
  final String? tooltip;
  final void Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2.0),
      child: Tooltip(
        message: tooltip,
        child: (filled)
            ? FilledButton(
                onPressed: onPressed,
                child: Text(
                  name,
                ),
              )
            : ElevatedButton(
                onPressed: onPressed,
                child: Text(
                  name,
                ),
              ),
      ),
    );
  }
}

class GeminiRawResponse extends StatelessWidget {
  final String response;
  const GeminiRawResponse({super.key, required this.response});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Gemini Response'),
      content: SizedBox(
        width: 700,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: SelectableText(response),
              ),
            ),
            Text(
              'Note: As sometimes gemini may not return with right format for some operation. It is used as debug',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Noted'),
        ),
      ],
    );
  }
}

class GeminiChatRoomDialog extends StatelessWidget {
  final ChatSession chat;
  const GeminiChatRoomDialog({super.key, required this.chat});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Stack(
            children: [
              GeminiChatWidget(
                chat: chat,
              ),
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class GeminiChatWidget extends StatefulWidget {
  const GeminiChatWidget({required this.chat, super.key, this.shortcuts});

  final List<Widget> Function(TextEditingController)? shortcuts;
  final ChatSession chat;

  @override
  State<GeminiChatWidget> createState() => _GeminiChatWidgetState();
}

class _GeminiChatWidgetState extends State<GeminiChatWidget> {
  late final ChatSession _chat;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFieldFocus = FocusNode(debugLabel: 'TextField');
  bool _loading = false;

  @override
  void initState() {
    super.initState();

    _chat = widget.chat;
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (_scrollController.hasClients && mounted) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(
              milliseconds: 750,
            ),
            curve: Curves.easeOutCirc,
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = _chat.history.toList();
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chat History'.toUpperCase(),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemBuilder: (context, idx) {
                final content = history[idx];
                final text = content.parts
                    .whereType<TextPart>()
                    .map<String>((e) => e.text)
                    .join('');
                return MessageWidget(
                  text: text,
                  isFromUser: content.role == 'user',
                );
              },
              itemCount: history.length,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 25,
              horizontal: 15,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        keyboardType: TextInputType.multiline,
                        minLines: 1,
                        maxLines: 5,
                        autofocus: true,
                        focusNode: _textFieldFocus,
                        decoration: const InputDecoration(
                          label: Text('Enter a prompt...'),
                          border: OutlineInputBorder(),
                        ),
                        controller: _textController,
                        onSubmitted: (String value) {
                          _sendChatMessage(value);
                        },
                      ),
                    ),
                    const SizedBox.square(dimension: 15),
                    if (!_loading)
                      IconButton(
                        onPressed: () async {
                          _sendChatMessage(_textController.text);
                        },
                        icon: Icon(
                          Icons.send,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                    else
                      const CircularProgressIndicator(),
                  ],
                ),
                if (widget.shortcuts != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      children: widget.shortcuts!(_textController),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendChatMessage(String message) async {
    setState(() {
      _loading = true;
    });

    try {
      final response = await _chat.sendMessage(
        Content.text(message),
      );
      final text = response.text;

      if (text == null) {
        _showError('Empty response.');
        return;
      } else {
        setState(() {
          _loading = false;
          _scrollDown();
        });
      }
    } catch (e) {
      _showError(e.toString());
      setState(() {
        _loading = false;
      });
    } finally {
      _textController.clear();
      setState(() {
        _loading = false;
      });
      _textFieldFocus.requestFocus();
    }
  }

  void _showError(String message) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Something went wrong'),
          content: SingleChildScrollView(
            child: Text(message),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            )
          ],
        );
      },
    );
  }
}

class MessageWidget extends StatelessWidget {
  const MessageWidget({
    super.key,
    required this.text,
    required this.isFromUser,
  });

  final String text;
  final bool isFromUser;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: (isFromUser)
          ? const EdgeInsets.only(left: 50)
          : const EdgeInsets.only(right: 50),
      child: Row(
        mainAxisAlignment:
            isFromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
                constraints: const BoxConstraints(maxWidth: 700),
                decoration: BoxDecoration(
                  color: isFromUser
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 15,
                  horizontal: 20,
                ),
                margin: const EdgeInsets.only(bottom: 8),
                child: MessageUtil(
                  text: text,
                  needBtn: false,
                )),
          ),
        ],
      ),
    );
  }
}

class MessageUtil extends StatefulWidget {
  final String text;
  final bool needBtn;
  const MessageUtil({super.key, required this.text, required this.needBtn});

  @override
  State<MessageUtil> createState() => _MessageUtilState();
}

class _MessageUtilState extends State<MessageUtil> {
  bool _viewRaw = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        (_viewRaw == false)
            ? SelectionArea(
                // new
                child: MarkdownBody(
                  data: widget.text,
                  styleSheet: MarkdownStyleSheet(
                    h1: TextStyle(
                        fontSize: 24,
                        color: Theme.of(context).colorScheme.primary),
                    code: TextStyle(
                        fontFamily: 'monospace',
                        color: Theme.of(context).colorScheme.onSurface),
                    codeblockDecoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4)),
                    // Add more styles as needed
                  ),
                ),
              )
            : SelectableText(widget.text),
        if (widget.needBtn)
          SizedBox(
            width: double.infinity,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _viewRaw = !_viewRaw;
                    });
                  },
                  icon: Icon((_viewRaw) ? Icons.palette : Icons.raw_off),
                  label: Text((_viewRaw) ? 'Style' : 'Raw'),
                ),
                const SizedBox(
                  width: 2,
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.text))
                        .then((_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied!')),
                      );
                    });
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
