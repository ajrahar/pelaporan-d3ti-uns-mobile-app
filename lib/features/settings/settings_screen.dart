// File: lib/settings/settings_screen.dart
import 'package:flutter/material.dart';
import "package:pelaporan_d3ti/shared/services/api_service.dart";
import 'package:pelaporan_d3ti/shared/services/token_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _apiUrlController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _apiUrlController.text = _apiService.baseUrl;
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveApiSettings() async {
    setState(() {
      _isSaving = true;
    });

    try {
      _apiService.updateBaseUrl(_apiUrlController.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('API URL updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating API URL: $e')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _clearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm'),
        content: Text('Are you sure you want to clear all app data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Clear Data'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await TokenManager.clearToken();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('All data cleared')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Application Settings',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 24),

            // API Settings
            Text(
              'API Configuration',
              style: Theme.of(context).textTheme.subtitle1,
            ),
            SizedBox(height: 8),
            TextField(
              controller: _apiUrlController,
              decoration: InputDecoration(
                labelText: 'API URL',
                border: OutlineInputBorder(),
                helperText: 'Example: https://example.com/api',
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveApiSettings,
              child: _isSaving
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('Save API Settings'),
            ),
            SizedBox(height: 32),

            // Data Management
            Text(
              'Data Management',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _clearData,
              icon: Icon(Icons.delete_forever, color: Colors.red),
              label: Text('Clear All App Data'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
            SizedBox(height: 32),

            // App Information
            Text(
              'About',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('D3TI Reporting App'),
                    SizedBox(height: 4),
                    Text('Version: 1.0.0'),
                    SizedBox(height: 4),
                    Text('© 2023 D3TI UNS'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on TextTheme {
  get subtitle1 => null;
}
