import 'package:flutter/material.dart';
import '../../data/services/kemono_api.dart';

/// Simple Discord API Test Screen
class DiscordApiTestScreen extends StatefulWidget {
  const DiscordApiTestScreen({super.key});

  @override
  State<DiscordApiTestScreen> createState() => _DiscordApiTestScreenState();
}

class _DiscordApiTestScreenState extends State<DiscordApiTestScreen> {
  String _testResult = 'Press button to test Discord API';
  bool _isLoading = false;

  void _setStateSafe({bool? isLoading, String? testResult}) {
    if (!mounted) return;
    setState(() {
      if (isLoading != null) {
        _isLoading = isLoading;
      }
      if (testResult != null) {
        _testResult = testResult;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Discord API Test')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : _testDiscordServers,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Test Discord Servers API'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _testDiscordChannels,
              child: Text('Test Discord Channels API'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _testDiscordPosts,
              child: Text('Test Discord Posts API'),
            ),
            const SizedBox(height: 20),
            Expanded(child: SingleChildScrollView(child: Text(_testResult))),
          ],
        ),
      ),
    );
  }

  Future<void> _testDiscordServers() async {
    _setStateSafe(isLoading: true, testResult: 'Testing Discord Servers API...');

    try {
      final response = await KemonoApi.getDiscordServers();
      _setStateSafe(testResult: '''OK Discord Servers API Test Results:
Status Code: ${response.statusCode}
Headers: ${response.headers}
Body Length: ${response.body.length}
Response Body (first 500 chars):
${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}
''');
    } catch (e) {
      _setStateSafe(testResult: 'ERROR Discord Servers API: $e');
    } finally {
      _setStateSafe(isLoading: false);
    }
  }

  Future<void> _testDiscordChannels() async {
    _setStateSafe(isLoading: true, testResult: 'Testing Discord Channels API...');

    try {
      // Test with a sample server ID (you'll need to replace with actual server ID)
      const serverId = '123'; // Replace with actual server ID
      final response = await KemonoApi.getDiscordServerChannels(serverId);
      _setStateSafe(testResult: '''OK Discord Channels API Test Results:
Server ID: $serverId
Status Code: ${response.statusCode}
Headers: ${response.headers}
Body Length: ${response.body.length}
Response Body (first 500 chars):
${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}
''');
    } catch (e) {
      _setStateSafe(testResult: 'ERROR Discord Channels API: $e');
    } finally {
      _setStateSafe(isLoading: false);
    }
  }

  Future<void> _testDiscordPosts() async {
    _setStateSafe(isLoading: true, testResult: 'Testing Discord Posts API...');

    try {
      // Test with a sample channel ID (you'll need to replace with actual channel ID)
      const channelId = '123'; // Replace with actual channel ID
      final response = await KemonoApi.getDiscordChannelPosts(channelId);
      _setStateSafe(testResult: '''OK Discord Posts API Test Results:
Channel ID: $channelId
Status Code: ${response.statusCode}
Headers: ${response.headers}
Body Length: ${response.body.length}
Response Body (first 500 chars):
${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}
''');
    } catch (e) {
      _setStateSafe(testResult: 'ERROR Discord Posts API: $e');
    } finally {
      _setStateSafe(isLoading: false);
    }
  }
}
