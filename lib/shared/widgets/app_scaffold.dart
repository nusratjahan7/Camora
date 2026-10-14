import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.leading,
    this.padded = true,
    this.bottomBar,
  });

  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool padded;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    final hasAppBar = title != null || actions != null || leading != null;

    return Scaffold(
      appBar: hasAppBar
          ? AppBar(
              title: title == null ? null : Text(title!),
              leading: leading,
              actions: actions,
            )
          : null,
      body: padded
          ? Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: body)
          : body,
      bottomNavigationBar: bottomBar,
    );
  }
}
