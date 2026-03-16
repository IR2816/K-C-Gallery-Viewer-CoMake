import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/discord_server.dart';
import '../../domain/entities/discord_channel.dart';

/// Discord Cache Service untuk local storage
class DiscordCacheService {
  static const String _serversKey = 'discord_servers_cache';
  static const String _channelsKey = 'discord_channels_cache_';
  static const String _lastUpdateKey = 'discord_last_update_';

  /// Cache Discord servers
  static Future<void> cacheServers(List<DiscordServer> servers) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serversJson = servers.map((server) => server.toJson()).toList();
      await prefs.setString(_serversKey, json.encode(serversJson));
      await prefs.setInt(
        '${_lastUpdateKey}servers',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      print('Error caching Discord servers: $e');
    }
  }

  /// Get cached Discord servers
  static Future<List<DiscordServer>> getCachedServers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serversJson = prefs.getString(_serversKey);

      if (serversJson == null) return [];

      final List<dynamic> decoded = json.decode(serversJson);
      return decoded.map((json) => DiscordServer.fromJson(json)).toList();
    } catch (e) {
      print('Error getting cached Discord servers: $e');
      return [];
    }
  }

  /// Cache Discord channels for a server
  static Future<void> cacheChannels(
    String serverId,
    List<DiscordChannel> channels,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final channelsJson = channels.map((channel) => channel.toJson()).toList();
      await prefs.setString(
        '$_channelsKey$serverId',
        json.encode(channelsJson),
      );
      await prefs.setInt(
        '${_lastUpdateKey}channels_$serverId',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      print('Error caching Discord channels: $e');
    }
  }

  /// Get cached Discord channels for a server
  static Future<List<DiscordChannel>> getCachedChannels(String serverId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final channelsJson = prefs.getString('$_channelsKey$serverId');

      if (channelsJson == null) return [];

      final List<dynamic> decoded = json.decode(channelsJson);
      return decoded.map((json) => DiscordChannel.fromJson(json)).toList();
    } catch (e) {
      print('Error getting cached Discord channels: $e');
      return [];
    }
  }

  /// Check if cache is valid (not older than specified duration)
  static Future<bool> isCacheValid(String key, Duration maxAge) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdate = prefs.getInt('$_lastUpdateKey$key');

      if (lastUpdate == null) return false;

      final lastUpdateTime = DateTime.fromMillisecondsSinceEpoch(lastUpdate);
      final now = DateTime.now();

      return now.difference(lastUpdateTime) < maxAge;
    } catch (e) {
      print('Error checking cache validity: $e');
      return false;
    }
  }

  /// Clear all Discord cache
  static Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      for (final key in keys) {
        if (key.startsWith('discord_')) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      print('Error clearing Discord cache: $e');
    }
  }

  /// Get cache size info
  static Future<Map<String, dynamic>> getCacheInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs
          .getKeys()
          .where((key) => key.startsWith('discord_'))
          .toList();

      int totalSize = 0;
      final Map<String, int> itemSizes = {};

      for (final key in keys) {
        final value = prefs.getString(key);
        if (value != null) {
          final size = value.length;
          totalSize += size;
          itemSizes[key] = size;
        }
      }

      return {
        'totalKeys': keys.length,
        'totalSize': totalSize,
        'itemSizes': itemSizes,
        'formattedSize': '${(totalSize / 1024).toStringAsFixed(2)} KB',
      };
    } catch (e) {
      print('Error getting cache info: $e');
      return {
        'totalKeys': 0,
        'totalSize': 0,
        'itemSizes': {},
        'formattedSize': '0 KB',
      };
    }
  }
}
