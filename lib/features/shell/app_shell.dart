import 'package:flutter/material.dart';

import '../../app/app_breakpoints.dart';
import '../doctors/doctors_screen.dart';
import '../documents/documents_screen.dart';
import '../medications/medications_screen.dart';
import '../profile/profile_screen.dart';
import '../today/today_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;
  late final PageController pageController = PageController();
  static const destinations = [
    NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Heute'),
    NavigationDestination(icon: Icon(Icons.medication_outlined), selectedIcon: Icon(Icons.medication_rounded), label: 'Medikamente'),
    NavigationDestination(icon: Icon(Icons.local_hospital_outlined), selectedIcon: Icon(Icons.local_hospital), label: 'Ärzte'),
    NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder), label: 'Dokumente'),
    NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
  ];
  static const pages = [TodayScreen(), MedicationsScreen(), DoctorsScreen(), DocumentsScreen(), ProfileScreen()];

  void select(int value) {
    setState(() => index = value);
    pageController.animateToPage(value, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final wide = windowClassOf(context) != WindowClass.compact;
    final content = PageView(
      controller: pageController,
      onPageChanged: (value) => setState(() => index = value),
      children: pages,
    );
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: .93),
      body: SafeArea(
        child: Row(children: [
          if (wide)
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: select,
              extended: windowClassOf(context) == WindowClass.expanded,
              labelType: windowClassOf(context) == WindowClass.expanded ? NavigationRailLabelType.none : NavigationRailLabelType.all,
              destinations: destinations.map((d) => NavigationRailDestination(icon: d.icon, selectedIcon: d.selectedIcon, label: Text(d.label))).toList(),
            ),
          Expanded(child: content),
        ]),
      ),
      bottomNavigationBar: wide ? null : NavigationBar(selectedIndex: index, onDestinationSelected: select, destinations: destinations),
    );
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }
}
