import 'package:flutter/material.dart';
import 'package:permission_handler_auto_back/permission_handler_auto_back.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Permission Auto-Back Demo',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const _DemoPage(),
    );
  }
}

class _DemoEntry {
  const _DemoEntry(this.label, this.permission, {this.note});

  final String label;
  final Permission permission;
  final String? note;
}

class _DemoPage extends StatefulWidget {
  const _DemoPage();

  @override
  State<_DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<_DemoPage> {
  final Map<Permission, PermissionStatus> _statuses = {};

  static const List<_DemoEntry> _entries = [
    _DemoEntry('Camera', Permission.camera),
    _DemoEntry('Microphone', Permission.microphone),
    _DemoEntry('Location (when in use)', Permission.locationWhenInUse),
    _DemoEntry(
      'Location (always)',
      Permission.locationAlways,
      note: 'Special — opens app details on Android, auto-returns on grant.',
    ),
    _DemoEntry('Notification', Permission.notification),
    _DemoEntry(
      'All files access',
      Permission.manageExternalStorage,
      note: 'Special — opens "All files access" page, auto-returns on toggle.',
    ),
    _DemoEntry(
      'Display over other apps',
      Permission.systemAlertWindow,
      note: 'Special — opens overlay settings, auto-returns on toggle.',
    ),
    _DemoEntry(
      'Schedule exact alarm',
      Permission.scheduleExactAlarm,
      note: 'Special on Android 12+.',
    ),
    _DemoEntry('Contacts', Permission.contacts),
    _DemoEntry('Photos', Permission.photos),
  ];

  Future<void> _request(_DemoEntry entry) async {
    final status = await entry.permission.requestWithAutoBack();
    if (!mounted) return;
    setState(() => _statuses[entry.permission] = status);

    // After a permanent denial the OS will not show the runtime dialog
    // again — the user has to flip the toggle in the app's Settings page.
    // On iOS this state is reached after the very first "Don't Allow"; on
    // Android it is reached when the auto-return Settings trip ended
    // without a grant. Either way the recovery is the same: open app
    // settings and refresh the status when the user returns.
    if (status.isPermanentlyDenied) {
      final wantsSettings = await _confirmOpenSettings(entry);
      if (!mounted || !wantsSettings) return;
      await openAppSettings();
      if (!mounted) return;
      final refreshed = await entry.permission.status;
      if (!mounted) return;
      setState(() => _statuses[entry.permission] = refreshed);
    }
  }

  Future<bool> _confirmOpenSettings(_DemoEntry entry) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${entry.label} permission denied'),
        content: Text(
          'You previously denied ${entry.label.toLowerCase()} access, '
          'so the system will not show the request dialog again. Open '
          'app settings to enable it manually.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _refresh(_DemoEntry entry) async {
    final status = await entry.permission.status;
    if (!mounted) return;
    setState(() => _statuses[entry.permission] = status);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Permission Auto-Back')),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final e = _entries[i];
          final status = _statuses[e.permission];
          return Card(
            child: ListTile(
              title: Text(e.label),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status: ${status?.name ?? "unknown"}'),
                  if (e.note != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        e.note!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh status',
                    onPressed: () => _refresh(e),
                  ),
                  FilledButton(
                    onPressed: () => _request(e),
                    child: const Text('Request'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
