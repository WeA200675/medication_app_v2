import 'package:flutter/material.dart';
import '../app/app_breakpoints.dart';

class PageFrame extends StatelessWidget {
  const PageFrame({super.key, required this.title, required this.child, this.subtitle, this.action});
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final window = windowClassOf(context);
    return CustomScrollView(slivers: [
      SliverAppBar.large(
        pinned: true,
        backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: .88),
        title: Text(title),
        actions: action == null ? null : [action!, const SizedBox(width: 12)],
      ),
      SliverToBoxAdapter(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth(window)),
            child: Padding(
              padding: EdgeInsets.fromLTRB(window == WindowClass.compact ? 16 : 28, 8, window == WindowClass.compact ? 16 : 28, 40),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (subtitle != null) ...[Text(subtitle!, style: Theme.of(context).textTheme.bodyLarge), const SizedBox(height: 24)],
                child,
              ]),
            ),
          ),
        ),
      ),
    ]);
  }
}
