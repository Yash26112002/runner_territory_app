import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_notifier.dart';
import '../../providers/settings_notifier.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseService _db = DatabaseService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = Provider.of<AuthNotifier>(context, listen: false).userToken;
      if (uid != null) {
        Provider.of<SettingsNotifier>(context, listen: false).initialize(uid);
      }
    });
  }

  void _editName(BuildContext context, String currentName) {
    final TextEditingController controller =
        TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter your name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != currentName) {
                final uid =
                    Provider.of<AuthNotifier>(context, listen: false).userToken;
                if (uid != null) {
                  await _db.updateUserProfileName(uid, newName);
                }
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsNotifier = Provider.of<SettingsNotifier>(context);
    final authNotifier = Provider.of<AuthNotifier>(context, listen: false);

    if (settingsNotifier.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final settings = settingsNotifier.settings;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: StreamBuilder(
        stream: _db.streamUser(authNotifier.userToken ?? ''),
        builder: (context, snapshot) {
          final user = snapshot.data;
          
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              _buildSectionHeader('Account'),
              Container(
                color: Colors.white,
                child: Column(
                  children: [
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppTheme.secondaryBlue,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      title: const Text('Display Name'),
                      subtitle: Text(user?.displayName ?? 'Runner'),
                      trailing: const Icon(Icons.edit, size: 20),
                      onTap: () => _editName(context, user?.displayName ?? ''),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionHeader('Privacy & Controls'),
              Container(
                color: Colors.white,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.visibility),
                      title: const Text('Territory Visibility'),
                      subtitle: const Text('Who can see your zones on the global map'),
                      trailing: DropdownButton<String>(
                        value: settings.territoryVisibility,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'public', child: Text('Public')),
                          DropdownMenuItem(value: 'private', child: Text('Private')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            settingsNotifier.updateSettings(
                              settingsNotifier.settings.copyWith(territoryVisibility: val),
                            );
                          }
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.gps_fixed),
                      title: const Text('High Accuracy GPS'),
                      subtitle: const Text('More precise polygons, uses more battery'),
                      activeTrackColor: AppTheme.primaryOrange.withValues(alpha: 0.5),
                      activeThumbColor: AppTheme.primaryOrange,
                      value: settings.highAccuracyGps,
                      onChanged: (val) {
                        settingsNotifier.updateSettings(
                          settingsNotifier.settings.copyWith(highAccuracyGps: val),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.volume_up),
                      title: const Text('Audio Cues'),
                      subtitle: const Text('Play cheers and whistles during runs'),
                      activeTrackColor: AppTheme.primaryOrange.withValues(alpha: 0.5),
                      activeThumbColor: AppTheme.primaryOrange,
                      value: settings.audioCuesEnabled,
                      onChanged: (val) {
                        settingsNotifier.updateSettings(
                          settingsNotifier.settings.copyWith(audioCuesEnabled: val),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
