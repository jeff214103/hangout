import 'package:flutter/material.dart';
import 'package:hangout/providers/setting_provider.dart';
import 'package:hangout/screen/setting.dart';
import 'package:hangout/screen/query_form.dart';
import 'package:hangout/widget/dialog.dart';
import 'package:hangout/widget/loading_hint.dart';
import 'package:provider/provider.dart';

void _redirectTo(BuildContext context, Widget widget,
    {void Function(dynamic)? callback}) {
  Navigator.of(context)
      .push(
    MaterialPageRoute(
      builder: (context) => widget,
    ),
  )
      .then((value) {
    if (callback != null) {
      callback(value);
    }
  });
}

Future<dynamic> confirmDeleteDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (BuildContext context) => ConfirmationDialogBody(
      text: 'Are you sure to remove the record?',
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
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
}

void notImplemented(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) => ConfirmationDialogBody(
      text: 'Not Implemented',
      actionButtons: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Ok'),
        ),
      ],
    ),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future applicationLoaded;

  Future<void> configureApplication(BuildContext context) {
    SettingProvider settingProvider =
        Provider.of<SettingProvider>(context, listen: false);
    return settingProvider.init().then((_) {
      if (settingProvider.geminiAPIKey.isEmpty) {
        _redirectTo(
          context,
          SettingPage(
            settingProvider: settingProvider,
          ),
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    applicationLoaded = configureApplication(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('Hangout'.toUpperCase()),
        actions: [
          IconButton(
            tooltip: 'Setting',
            onPressed: () {
              _redirectTo(
                context,
                SettingPage(
                  settingProvider:
                      Provider.of<SettingProvider>(context, listen: false),
                ),
              );
            },
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: FutureBuilder(
        future: applicationLoaded,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(snapshot.error.toString()),
            );
          } else if (snapshot.connectionState == ConnectionState.done) {
            return const MainLayout();
          } else {
            return const LoadingHint(text: 'Loading data...');
          }
        },
      ),
    );
  }
}

class MainLayout extends StatelessWidget {
  const MainLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Hero image at the top
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/heros.png'),
                fit: BoxFit.contain,
              ),
            ),
          ),
          // Query form
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: QueryForm(),
          ),
        ],
      ),
    );
  }
}
