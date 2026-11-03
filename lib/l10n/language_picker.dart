import 'package:flutter/material.dart';
import '../play_preferences.dart';

class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: PlayPreferences.instance,
      builder: (context, _) => DropdownButton<String>(
            key: const ValueKey('language-picker'),
            isExpanded: true,
            value: PlayPreferences.instance.language,
            items: const [
              DropdownMenuItem(value: 'es', child: Text('Español')),
              DropdownMenuItem(value: 'en', child: Text('English')),
            ],
            onChanged: (language) {
              if (language != null) {
                PlayPreferences.instance.update(language: language);
              }
            },
          ));
}
