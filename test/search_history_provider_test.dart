import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kc_gallery_viewer/presentation/providers/search_history_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  group('SearchHistoryEntry', () {
    test('fromJson uses defaults for missing or invalid fields', () {
      final entry = SearchHistoryEntry.fromJson(<String, dynamic>{
        'query': 'abc',
        'timestamp': 'invalid',
      });

      expect(entry.query, 'abc');
      expect(entry.type, 'creator');
      expect(entry.frequency, 1);
    });

    test('copyWith overrides only provided fields', () {
      final now = DateTime(2024, 1, 1);
      final entry = SearchHistoryEntry(
        query: 'hello',
        type: 'post',
        timestamp: now,
        frequency: 2,
      );

      final copied = entry.copyWith(frequency: 3);
      expect(copied.query, 'hello');
      expect(copied.type, 'post');
      expect(copied.timestamp, now);
      expect(copied.frequency, 3);
    });
  });

  group('SearchHistoryProvider', () {
    late SearchHistoryProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      provider = SearchHistoryProvider();
      await provider.initialize();
    });

    test('starts enabled and with empty history', () {
      expect(provider.enabled, isTrue);
      expect(provider.history, isEmpty);
    });

    test('trackSearch adds trimmed entry at top', () async {
      await provider.trackSearch('  query  ');

      expect(provider.history.length, 1);
      expect(provider.history.first.query, 'query');
      expect(provider.history.first.type, 'creator');
      expect(provider.history.first.frequency, 1);
    });

    test('trackSearch ignores empty or whitespace query', () async {
      await provider.trackSearch('');
      await provider.trackSearch('   ');

      expect(provider.history, isEmpty);
    });

    test('trackSearch increments frequency and moves existing match to top',
        () async {
      await provider.trackSearch('first');
      await provider.trackSearch('second');
      await provider.trackSearch('First');

      expect(provider.history.length, 2);
      expect(provider.history.first.query, 'first');
      expect(provider.history.first.frequency, 2);
    });

    test('trackSearch treats same query in different types as separate entries',
        () async {
      await provider.trackSearch('same', type: 'creator');
      await provider.trackSearch('same', type: 'post');

      expect(provider.history.length, 2);
      expect(
        provider.history.where((e) => e.query == 'same').map((e) => e.type),
        containsAll(<String>['creator', 'post']),
      );
    });

    test('setEnabled(false) disables tracking', () async {
      await provider.setEnabled(false);
      await provider.trackSearch('blocked');

      expect(provider.enabled, isFalse);
      expect(provider.history, isEmpty);
    });

    test('initialize restores enabled flag from shared preferences', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'search_history_enabled': false,
      });
      final fresh = SearchHistoryProvider();
      await fresh.initialize();

      expect(fresh.enabled, isFalse);
    });

    test('getSearchHistory filters by type and respects limit', () async {
      await provider.trackSearch('c1', type: 'creator');
      await provider.trackSearch('p1', type: 'post');
      await provider.trackSearch('c2', type: 'creator');

      final creatorOnly = provider.getSearchHistory(type: 'creator', limit: 1);
      expect(creatorOnly.length, 1);
      expect(creatorOnly.first.type, 'creator');
      expect(creatorOnly.first.query, 'c2');
    });

    test('getSuggestions matches prefix case-insensitively', () async {
      await provider.trackSearch('HelloWorld', type: 'creator');
      await provider.trackSearch('helloPost', type: 'post');
      await provider.trackSearch('other', type: 'creator');

      final results = provider.getSuggestions('he');
      expect(results.length, 2);
      expect(results.every((e) => e.query.toLowerCase().startsWith('he')), isTrue);
    });

    test('getSuggestions returns empty for blank query', () async {
      await provider.trackSearch('hello');
      expect(provider.getSuggestions('   '), isEmpty);
    });

    test('getMostFrequent sorts descending and supports type filter', () async {
      await provider.trackSearch('alpha', type: 'creator');
      await provider.trackSearch('alpha', type: 'creator');
      await provider.trackSearch('beta', type: 'creator');
      await provider.trackSearch('post-query', type: 'post');
      await provider.trackSearch('post-query', type: 'post');
      await provider.trackSearch('post-query', type: 'post');

      final creatorTop = provider.getMostFrequent(type: 'creator', limit: 1);
      expect(creatorTop.length, 1);
      expect(creatorTop.first.query, 'alpha');
      expect(creatorTop.first.frequency, 2);
    });

    test('removeFromHistory removes by query case-insensitively across types',
        () async {
      await provider.trackSearch('same', type: 'creator');
      await provider.trackSearch('same', type: 'post');
      await provider.removeFromHistory('SAME');

      expect(provider.history, isEmpty);
    });

    test('removeFromHistory with type removes only matching type', () async {
      await provider.trackSearch('same', type: 'creator');
      await provider.trackSearch('same', type: 'post');
      await provider.removeFromHistory('same', type: 'post');

      expect(provider.history.length, 1);
      expect(provider.history.first.type, 'creator');
    });

    test('clearByType removes only entries of given type', () async {
      await provider.trackSearch('c', type: 'creator');
      await provider.trackSearch('p', type: 'post');
      await provider.clearByType('creator');

      expect(provider.history.length, 1);
      expect(provider.history.first.type, 'post');
    });

    test('clearSearchHistory removes all entries', () async {
      await provider.trackSearch('a');
      await provider.trackSearch('b');
      await provider.clearSearchHistory();

      expect(provider.history, isEmpty);
    });

    test('history is limited to max 50 entries', () async {
      for (var i = 0; i < 55; i++) {
        await provider.trackSearch('q$i');
      }

      expect(provider.history.length, 50);
      expect(provider.history.first.query, 'q54');
      expect(provider.history.last.query, 'q5');
    });

    test('initialize skips corrupt persisted entries and keeps valid ones',
        () async {
      final validEntry = jsonEncode(<String, dynamic>{
        'query': 'valid',
        'type': 'creator',
        'timestamp': DateTime(2024, 1, 1).toIso8601String(),
        'frequency': 2,
      });

      SharedPreferences.setMockInitialValues(<String, Object>{
        'search_history_v2': <String>[
          validEntry,
          '{bad-json',
          jsonEncode(<String, dynamic>{'query': 'still-valid'}),
        ],
      });

      final fresh = SearchHistoryProvider();
      await fresh.initialize();

      expect(fresh.history.length, 2);
      expect(fresh.history.first.query, 'valid');
      expect(fresh.history.last.query, 'still-valid');
    });
  });
}
