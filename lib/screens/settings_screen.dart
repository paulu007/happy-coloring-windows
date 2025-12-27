import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/constants.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Appearance Section
              _buildSectionHeader('Appearance'),
              _buildThemeSetting(context, settings),
              
              const SizedBox(height: 24),
              
              // Coloring Settings
              _buildSectionHeader('Coloring'),
              _buildSwitchTile(
                title: 'Show Numbers',
                subtitle: 'Display numbers on unfilled regions',
                value: settings.showNumbers,
                onChanged: (_) => settings.toggleShowNumbers(),
              ),
              _buildSwitchTile(
                title: 'Highlight Regions',
                subtitle: 'Highlight regions matching selected color',
                value: settings.highlightRegions,
                onChanged: (_) => settings.toggleHighlightRegions(),
              ),
              _buildSwitchTile(
                title: 'Auto-Save',
                subtitle: 'Automatically save progress',
                value: settings.autoSave,
                onChanged: (_) => settings.toggleAutoSave(),
              ),

              const SizedBox(height: 24),

              // Feedback Settings
              _buildSectionHeader('Feedback'),
              _buildSwitchTile(
                title: 'Sound Effects',
                subtitle: 'Play sounds when coloring',
                value: settings.soundEnabled,
                onChanged: (_) => settings.toggleSound(),
              ),
              _buildSwitchTile(
                title: 'Vibration',
                subtitle: 'Vibrate when coloring',
                value: settings.vibrationEnabled,
                onChanged: (_) => settings.toggleVibration(),
              ),

              const SizedBox(height: 24),

              // About Section
              _buildSectionHeader('About'),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('App Version'),
                subtitle: const Text(AppConstants.appVersion),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // Open privacy policy
                },
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Terms of Service'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // Open terms of service
                },
              ),

              const SizedBox(height: 24),

              // Reset Button
              Center(
                child: OutlinedButton.icon(
                  onPressed: () => _showResetDialog(context, settings),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reset All Settings'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildThemeSetting(BuildContext context, SettingsProvider settings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Theme',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildThemeOption(
                  context: context,
                  settings: settings,
                  mode: ThemeMode.system,
                  icon: Icons.brightness_auto,
                  label: 'Auto',
                ),
                const SizedBox(width: 12),
                _buildThemeOption(
                  context: context,
                  settings: settings,
                  mode: ThemeMode.light,
                  icon: Icons.light_mode,
                  label: 'Light',
                ),
                const SizedBox(width: 12),
                _buildThemeOption(
                  context: context,
                  settings: settings,
                  mode: ThemeMode.dark,
                  icon: Icons.dark_mode,
                  label: 'Dark',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required SettingsProvider settings,
    required ThemeMode mode,
    required IconData icon,
    required String label,
  }) {
    final isSelected = settings.themeMode == mode;

    return Expanded(
      child: GestureDetector(
        onTap: () => settings.setThemeMode(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withOpacity(0.1)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primary : Colors.grey,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? AppColors.primary : Colors.grey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      child: SwitchListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  void _showResetDialog(BuildContext context, SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text(
          'Are you sure you want to reset all settings to defaults?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              settings.resetToDefaults();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings reset to defaults')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}