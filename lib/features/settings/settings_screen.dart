import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_strings.dart';
import '../../core/analytics/analytics_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppTheme _appTheme;
  late AppStrings _appStrings;
  late AnalyticsService _analytics;

  @override
  void initState() {
    super.initState();
    _appTheme = AppTheme();
    _appStrings = AppStrings();
    _analytics = AnalyticsService();
    _analytics.trackScreenView('SettingsScreen');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appStrings.get('settings')),
      ),
      body: ListView(
        children: [
          _buildThemeSection(),
          const Divider(),
          _buildLanguageSection(),
        ],
      ),
    );
  }

  Widget _buildThemeSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _appStrings.get('theme'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: Text(_appStrings.get('dark_mode')),
            value: _appTheme.isDarkMode,
            onChanged: (value) async {
              await _appTheme.setDarkMode(value);
              _analytics.trackButtonClick('DarkModeToggle', screenName: 'SettingsScreen');
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _appStrings.get('language'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final locale in _appStrings.availableLocales)
                FilterChip(
                  label: Text(locale.name),
                  selected: _appStrings.currentLocale == locale,
                  onSelected: (selected) async {
                    if (selected) {
                      await _appStrings.setLocale(locale);
                      _analytics.trackButtonClick(
                        'LanguageChange',
                        screenName: 'SettingsScreen',
                      );
                      setState(() {});
                    }
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
