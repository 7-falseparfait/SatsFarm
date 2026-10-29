import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';

class LanguageToggleButton extends StatelessWidget {
  const LanguageToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>();
    return TextButton.icon(
      onPressed: language.toggle,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF153C2B),
        minimumSize: const Size(48, 44),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      icon: const Icon(LucideIcons.languages, size: 17),
      label: Text(language.locale.languageCode == 'en' ? 'Hausa' : 'English'),
    );
  }
}
