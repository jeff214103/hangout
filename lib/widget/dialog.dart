import 'package:flutter/material.dart';

class LoadingDialogBody extends StatelessWidget {
  const LoadingDialogBody({super.key, required this.text, this.actionButtons});
  final String text;
  final List<Widget>? actionButtons;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(
              height: 15,
            ),
            Text(text),
            Row(
              mainAxisSize: MainAxisSize.min,
              children:
                  (actionButtons == null) ? [const SizedBox()] : actionButtons!,
            )
          ],
        ),
      ),
    );
  }
}

class ConfirmationDialogBody extends StatelessWidget {
  const ConfirmationDialogBody(
      {super.key, required this.text, this.actionButtons});
  final String text;
  final List<Widget>? actionButtons;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text),
              const SizedBox(
                height: 15,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: (actionButtons == null)
                    ? [const SizedBox()]
                    : actionButtons!,
              )
            ],
          ),
        ),
      ),
    );
  }
}
