import 'package:flutter/material.dart';
import 'package:localsend_app/gen/strings.g.dart';

/// 首次启动（或从设置重新打开）的快速上手说明。
Future<void> showOnboardingDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(t.onboarding.title),
      content: Text(
        [
          t.onboarding.discover,
          t.onboarding.privacy,
          t.onboarding.bluetooth,
        ].join('\n'),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.onboarding.confirm),
        ),
      ],
    ),
  );
}
