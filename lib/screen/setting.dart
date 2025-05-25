import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hangout/providers/setting_provider.dart';
import 'package:hangout/widget/dialog.dart';
import 'package:url_launcher/link.dart';

class SettingPage extends StatefulWidget {
  final SettingProvider settingProvider;
  const SettingPage({super.key, required this.settingProvider});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _geminiAPITextController =
      TextEditingController();
  String? _geminiModel;

  @override
  void initState() {
    super.initState();
    _geminiAPITextController.text = widget.settingProvider.geminiAPIKey;
    _geminiModel = (widget.settingProvider.geminiModel.isEmpty)
        ? widget.settingProvider.availableModels.first
        : widget.settingProvider.geminiModel;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1080),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const Text(
                  'To use the applciation, you\'ll need an Gemini API key. '
                  'If you don\'t already have one, '
                  'create a key in Google AI Studio.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Center(
                  child: Link(
                    uri: Uri.https('makersuite.google.com', '/app/apikey'),
                    target: LinkTarget.blank,
                    builder: (context, followLink) => TextButton(
                      onPressed: followLink,
                      child: const Text('Get an API Key'),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: const Text('Gemini API Key'),
                  subtitle: TextFormField(
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please input the gemini API key';
                      }
                      return null;
                    },
                    controller: _geminiAPITextController,
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: const Text('Gemini Model'),
                  subtitle: DropdownButtonFormField(
                    value: _geminiModel,
                    hint: const Text(
                      'Please Select',
                    ),
                    isExpanded: true,
                    onChanged: (value) {
                      setState(() {
                        _geminiModel = value;
                      });
                    },
                    validator: (String? value) {
                      if (value == null || value.isEmpty) {
                        return "Need to choose gemini model";
                      }
                      return null;
                    },
                    items: widget.settingProvider.availableModels.map(
                      (String val) {
                        return DropdownMenuItem(
                          value: val,
                          child: Text(
                            val,
                          ),
                        );
                      },
                    ).toList(),
                  ),
                ),
                const GeminiDisclaimer(),
                const SizedBox(
                  height: 8,
                ),
                Center(
                  child: FilledButton(
                    onPressed: () {
                      if (!_formKey.currentState!.validate()) {
                        return;
                      }
                      widget.settingProvider
                          .geminiSetting(
                              _geminiAPITextController.text, _geminiModel!)
                          .then(
                        (_) {
                          Navigator.of(context).pop();

                          showDialog(
                            context: context,
                            builder: (context) => ConfirmationDialogBody(
                              text:
                                  'Gemini API Key saved.\nNote: It does not verify the key is correct or not. You may need to go back to SETTING for modification if the API key does not work.',
                              actionButtons: [
                                TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text('Done'))
                              ],
                            ),
                          );
                        },
                      );
                    },
                    child: const Text('Submit'),
                  ),
                ),
                if (widget.settingProvider.geminiAPIKey.isNotEmpty &&
                    widget.settingProvider.geminiModel.isNotEmpty)
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Back'),
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

class GeminiDisclaimer extends StatelessWidget {
  const GeminiDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        '''Gemini may display inaccurate information, including about people. Always verify its responses before relying on them. The app developer is not responsible for any incorrect information provided by Gemini.

Due to restrictions on AI in certain regions, this app is not intended for commercial use or profit. To access Gemini's API and begin your job search, please obtain an API key independently.
''',
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}
