import 'package:flutter/widgets.dart';

enum WindowClass { compact, medium, expanded }

WindowClass windowClassOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 1000) return WindowClass.expanded;
  if (width >= 650) return WindowClass.medium;
  return WindowClass.compact;
}

double contentMaxWidth(WindowClass value) => switch (value) {
      WindowClass.compact => 720,
      WindowClass.medium => 960,
      WindowClass.expanded => 1240,
    };
