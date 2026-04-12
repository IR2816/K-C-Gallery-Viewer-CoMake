import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kc_gallery_viewer/presentation/providers/tag_filter_provider.dart';

void main() {
  // Ensure the binding is initialized so platform channels are stubbed.
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  group('TagFilterProvider', () {
    late TagFilterProvider provider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      provider = TagFilterProvider();
    });

    group('initial state', () {
      test('blacklist is empty on creation', () {
        expect(provider.blacklist, isEmpty);
      });

      test('isPostBlocked returns false when blacklist is empty', () {
        expect(provider.isPostBlocked(['tag1', 'tag2']), isFalse);
      });

      test('isPostBlocked returns false for empty post tags', () {
        expect(provider.isPostBlocked([]), isFalse);
      });
    });

    group('addToBlacklist', () {
      test('adds normalized tag to blacklist', () async {
        await provider.addToBlacklist('TestTag');
        expect(provider.isTagBlocked('testtag'), isTrue);
      });

      test('normalizes tag to lowercase before adding', () async {
        await provider.addToBlacklist('UPPERCASE');
        expect(provider.blacklist.contains('uppercase'), isTrue);
        expect(provider.blacklist.contains('UPPERCASE'), isFalse);
      });

      test('trims whitespace from tag', () async {
        await provider.addToBlacklist('  spaced  ');
        expect(provider.isTagBlocked('spaced'), isTrue);
      });

      test('does not add empty string', () async {
        await provider.addToBlacklist('');
        expect(provider.blacklist, isEmpty);
      });

      test('does not add whitespace-only string', () async {
        await provider.addToBlacklist('   ');
        expect(provider.blacklist, isEmpty);
      });

      test('does not add duplicate tag', () async {
        await provider.addToBlacklist('tag1');
        await provider.addToBlacklist('tag1');
        expect(provider.blacklist.length, 1);
      });

      test('duplicate check is case-insensitive', () async {
        await provider.addToBlacklist('Tag1');
        await provider.addToBlacklist('TAG1');
        expect(provider.blacklist.length, 1);
      });
    });

    group('removeFromBlacklist', () {
      setUp(() async {
        await provider.addToBlacklist('tag1');
        await provider.addToBlacklist('tag2');
      });

      test('removes tag from blacklist', () async {
        await provider.removeFromBlacklist('tag1');
        expect(provider.isTagBlocked('tag1'), isFalse);
      });

      test('leaves other tags intact', () async {
        await provider.removeFromBlacklist('tag1');
        expect(provider.isTagBlocked('tag2'), isTrue);
      });

      test('is case-insensitive for removal', () async {
        await provider.removeFromBlacklist('TAG1');
        expect(provider.isTagBlocked('tag1'), isFalse);
      });

      test('does nothing for non-existent tag', () async {
        await provider.removeFromBlacklist('nonexistent');
        expect(provider.blacklist.length, 2);
      });
    });

    group('clearBlacklist', () {
      test('removes all tags from blacklist', () async {
        await provider.addToBlacklist('tag1');
        await provider.addToBlacklist('tag2');
        await provider.clearBlacklist();
        expect(provider.blacklist, isEmpty);
      });

      test('does nothing when blacklist is already empty', () async {
        await provider.clearBlacklist();
        expect(provider.blacklist, isEmpty);
      });
    });

    group('isTagBlocked', () {
      test('returns true for blocked tag', () async {
        await provider.addToBlacklist('nsfw');
        expect(provider.isTagBlocked('nsfw'), isTrue);
      });

      test('returns false for non-blocked tag', () async {
        await provider.addToBlacklist('nsfw');
        expect(provider.isTagBlocked('safe'), isFalse);
      });

      test('is case-insensitive', () async {
        await provider.addToBlacklist('nsfw');
        expect(provider.isTagBlocked('NSFW'), isTrue);
        expect(provider.isTagBlocked('Nsfw'), isTrue);
      });
    });

    group('isPostBlocked', () {
      test('returns true when post has blocked tag', () async {
        await provider.addToBlacklist('nsfw');
        expect(provider.isPostBlocked(['art', 'nsfw', 'photo']), isTrue);
      });

      test('returns false when post has no blocked tags', () async {
        await provider.addToBlacklist('nsfw');
        expect(provider.isPostBlocked(['art', 'photo']), isFalse);
      });

      test('is case-insensitive for post tags', () async {
        await provider.addToBlacklist('nsfw');
        expect(provider.isPostBlocked(['NSFW']), isTrue);
      });

      test('returns false when blacklist is empty regardless of post tags', () {
        expect(provider.isPostBlocked(['nsfw', 'explicit']), isFalse);
      });

      test('returns false for empty post tags list', () async {
        await provider.addToBlacklist('nsfw');
        expect(provider.isPostBlocked([]), isFalse);
      });
    });

    group('filterPosts', () {
      test('returns all posts when blacklist is empty', () async {
        final posts = ['post1', 'post2', 'post3'];
        final result = provider.filterPosts(posts, (p) => [p]);
        expect(result, posts);
      });

      test('filters out posts with blocked tags', () async {
        await provider.addToBlacklist('nsfw');
        final posts = [
          {
            'title': 'safe post',
            'tags': ['art'],
          },
          {
            'title': 'blocked post',
            'tags': ['nsfw'],
          },
          {
            'title': 'another safe',
            'tags': ['photo'],
          },
        ];
        final result = provider.filterPosts(
          posts,
          (p) => List<String>.from(p['tags'] as List),
        );
        expect(result.length, 2);
        expect(
          result.every((p) => (p['tags'] as List).contains('nsfw')),
          isFalse,
        );
      });

      test('returns empty list when all posts are blocked', () async {
        await provider.addToBlacklist('nsfw');
        final posts = [
          {
            'tags': ['nsfw'],
          },
          {
            'tags': ['nsfw', 'explicit'],
          },
        ];
        final result = provider.filterPosts(
          posts,
          (p) => List<String>.from(p['tags'] as List),
        );
        expect(result, isEmpty);
      });
    });

    group('getBlockedCount', () {
      test('returns 0 when blacklist is empty', () {
        final posts = [
          {
            'tags': ['nsfw'],
          },
        ];
        expect(
          provider.getBlockedCount(
            posts,
            (p) => List<String>.from(p['tags'] as List),
          ),
          0,
        );
      });

      test('counts blocked posts correctly', () async {
        await provider.addToBlacklist('nsfw');
        final posts = [
          {
            'tags': ['art'],
          },
          {
            'tags': ['nsfw'],
          },
          {
            'tags': ['nsfw', 'photo'],
          },
        ];
        expect(
          provider.getBlockedCount(
            posts,
            (p) => List<String>.from(p['tags'] as List),
          ),
          2,
        );
      });
    });

    group('getSortedBlacklist', () {
      test('returns tags in alphabetical order', () async {
        await provider.addToBlacklist('zebra');
        await provider.addToBlacklist('apple');
        await provider.addToBlacklist('mango');
        final sorted = provider.getSortedBlacklist();
        expect(sorted, ['apple', 'mango', 'zebra']);
      });

      test('returns empty list when blacklist is empty', () {
        expect(provider.getSortedBlacklist(), isEmpty);
      });
    });

    group('getStatistics', () {
      test('reports correct count', () async {
        await provider.addToBlacklist('tag1');
        await provider.addToBlacklist('tag2');
        final stats = provider.getStatistics();
        expect(stats['totalBlocked'], 2);
      });

      test('includes sorted list of blocked tags', () async {
        await provider.addToBlacklist('b');
        await provider.addToBlacklist('a');
        final stats = provider.getStatistics();
        expect(stats['blockedTags'], ['a', 'b']);
      });
    });
  });
}
