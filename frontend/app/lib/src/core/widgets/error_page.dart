import 'package:flutter/material.dart';

import 'package:shortplay_app/generated/l10n.dart';
import 'package:shortplay_app/src/core/widgets/empty_state.dart';

class CustomErrorWidget extends StatelessWidget {
  final String errorMessage;

  const CustomErrorWidget({super.key, required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline,
      title: S.of(context).errorOccurred,
      subtitle: errorMessage,
    );
  }
}
