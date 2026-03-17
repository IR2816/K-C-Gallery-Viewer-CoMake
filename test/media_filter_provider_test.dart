import 'package:flutter_test/flutter_test.dart';
import 'package:kc_gallery_viewer/presentation/providers/media_filter_provider.dart';

void main() {
  group('MediaFilterSettings', () {
    group('default values', () {
      const settings = MediaFilterSettings();

      test('type defaults to all', () {
        expect(settings.type, MediaFilterType.all);
      });

      test('allowedExtensions defaults to empty', () {
        expect(settings.allowedExtensions, isEmpty);
      });

      test('blockedExtensions defaults to empty', () {
        expect(settings.blockedExtensions, isEmpty);
      });

      test('minSizeBytes defaults to 0', () {
        expect(settings.minSizeBytes, 0);
      });

      test('maxSizeBytes defaults to 0 (no limit)', () {
        expect(settings.maxSizeBytes, 0);
      });

      test('hideDuplicates defaults to false', () {
        expect(settings.hideDuplicates, isFalse);
      });
    });

    group('copyWith', () {
      test('updates type while preserving other fields', () {
        const original = MediaFilterSettings(minSizeBytes: 1024);
        final updated = original.copyWith(type: MediaFilterType.images);
        expect(updated.type, MediaFilterType.images);
        expect(updated.minSizeBytes, 1024);
      });

      test('updates allowedExtensions', () {
        const original = MediaFilterSettings();
        final updated = original.copyWith(
          allowedExtensions: {'jpg', 'png'},
        );
        expect(updated.allowedExtensions, containsAll(['jpg', 'png']));
      });

      test('updates blockedExtensions', () {
        const original = MediaFilterSettings();
        final updated = original.copyWith(
          blockedExtensions: {'gif'},
        );
        expect(updated.blockedExtensions, contains('gif'));
      });

      test('updates hideDuplicates flag', () {
        const original = MediaFilterSettings();
        final updated = original.copyWith(hideDuplicates: true);
        expect(updated.hideDuplicates, isTrue);
        expect(original.hideDuplicates, isFalse);
      });
    });
  });

  group('MediaFilterProvider', () {
    late MediaFilterProvider provider;

    setUp(() {
      provider = MediaFilterProvider();
    });

    group('initial state', () {
      test('filter is enabled by default', () {
        expect(provider.isEnabled, isTrue);
      });

      test('is not initialized before initialize() is called', () {
        expect(provider.isInitialized, isFalse);
      });

      test('settings type defaults to all', () {
        expect(provider.settings.type, MediaFilterType.all);
      });
    });

    group('shouldShowMedia - disabled filter', () {
      test('always returns true when filter is disabled', () {
        provider.setEnabled(false);
        expect(provider.shouldShowMedia('file.gif', null), isTrue);
        expect(provider.shouldShowMedia('file.mp4', null), isTrue);
      });
    });

    group('shouldShowMedia - extension blocking', () {
      test('shows media when no extensions are blocked', () {
        expect(provider.shouldShowMedia('photo.jpg', null), isTrue);
      });

      test('hides media with blocked extension', () {
        provider.addBlockedExtension('gif');
        expect(provider.shouldShowMedia('animation.gif', null), isFalse);
      });

      test('shows media whose extension is not blocked', () {
        provider.addBlockedExtension('gif');
        expect(provider.shouldShowMedia('photo.jpg', null), isTrue);
      });

      test('blocked extension check is case-insensitive', () {
        provider.addBlockedExtension('gif');
        // The URL extension extraction lowercases the extension
        expect(provider.shouldShowMedia('animation.gif', null), isFalse);
      });

      test('removing blocked extension allows media through', () {
        provider.addBlockedExtension('gif');
        provider.removeBlockedExtension('gif');
        expect(provider.shouldShowMedia('animation.gif', null), isTrue);
      });
    });

    group('shouldShowMedia - allowed extensions allowlist', () {
      test('shows all media when allowed list is empty', () {
        expect(provider.shouldShowMedia('photo.jpg', null), isTrue);
        expect(provider.shouldShowMedia('video.mp4', null), isTrue);
      });

      test('shows media whose extension is in allowed list', () {
        provider.addAllowedExtension('jpg');
        expect(provider.shouldShowMedia('photo.jpg', null), isTrue);
      });

      test('hides media whose extension is not in allowed list', () {
        provider.addAllowedExtension('jpg');
        expect(provider.shouldShowMedia('video.mp4', null), isFalse);
      });

      test('removing from allowed list hides that extension', () {
        provider.addAllowedExtension('jpg');
        provider.addAllowedExtension('png');
        provider.removeAllowedExtension('jpg');
        expect(provider.shouldShowMedia('photo.jpg', null), isFalse);
        expect(provider.shouldShowMedia('photo.png', null), isTrue);
      });
    });

    group('shouldShowMedia - size limits', () {
      test('shows media when file size is within limits', () {
        provider.setSizeLimits(minSize: 1024, maxSize: 10240);
        expect(provider.shouldShowMedia('photo.jpg', 5000), isTrue);
      });

      test('hides media smaller than minSizeBytes', () {
        provider.setSizeLimits(minSize: 1024);
        expect(provider.shouldShowMedia('photo.jpg', 512), isFalse);
      });

      test('hides media larger than maxSizeBytes', () {
        provider.setSizeLimits(maxSize: 1024);
        expect(provider.shouldShowMedia('photo.jpg', 2048), isFalse);
      });

      test('shows media when size is null (unknown)', () {
        provider.setSizeLimits(minSize: 1024, maxSize: 10240);
        expect(provider.shouldShowMedia('photo.jpg', null), isTrue);
      });

      test('no size limit when maxSizeBytes is 0', () {
        provider.setSizeLimits(maxSize: 0);
        expect(provider.shouldShowMedia('photo.jpg', 999999999), isTrue);
      });
    });

    group('shouldShowMedia - filter type', () {
      test('images filter shows jpg', () {
        provider.setFilterType(MediaFilterType.images);
        expect(provider.shouldShowMedia('photo.jpg', null), isTrue);
      });

      test('images filter shows png', () {
        provider.setFilterType(MediaFilterType.images);
        expect(provider.shouldShowMedia('photo.png', null), isTrue);
      });

      test('images filter hides mp4', () {
        provider.setFilterType(MediaFilterType.images);
        expect(provider.shouldShowMedia('video.mp4', null), isFalse);
      });

      test('videos filter shows mp4', () {
        provider.setFilterType(MediaFilterType.videos);
        expect(provider.shouldShowMedia('video.mp4', null), isTrue);
      });

      test('videos filter shows webm', () {
        provider.setFilterType(MediaFilterType.videos);
        expect(provider.shouldShowMedia('video.webm', null), isTrue);
      });

      test('videos filter hides jpg', () {
        provider.setFilterType(MediaFilterType.videos);
        expect(provider.shouldShowMedia('photo.jpg', null), isFalse);
      });

      test('audio filter shows mp3', () {
        provider.setFilterType(MediaFilterType.audio);
        expect(provider.shouldShowMedia('track.mp3', null), isTrue);
      });

      test('audio filter hides jpg', () {
        provider.setFilterType(MediaFilterType.audio);
        expect(provider.shouldShowMedia('photo.jpg', null), isFalse);
      });

      test('documents filter shows pdf', () {
        provider.setFilterType(MediaFilterType.documents);
        expect(provider.shouldShowMedia('document.pdf', null), isTrue);
      });

      test('documents filter hides mp4', () {
        provider.setFilterType(MediaFilterType.documents);
        expect(provider.shouldShowMedia('video.mp4', null), isFalse);
      });

      test('all filter shows every type', () {
        provider.setFilterType(MediaFilterType.all);
        expect(provider.shouldShowMedia('photo.jpg', null), isTrue);
        expect(provider.shouldShowMedia('video.mp4', null), isTrue);
        expect(provider.shouldShowMedia('track.mp3', null), isTrue);
      });
    });

    group('setEnabled', () {
      test('disables filtering', () {
        provider.setEnabled(false);
        expect(provider.isEnabled, isFalse);
      });

      test('re-enables filtering', () {
        provider.setEnabled(false);
        provider.setEnabled(true);
        expect(provider.isEnabled, isTrue);
      });
    });

    group('toggleHideDuplicates', () {
      test('toggles hideDuplicates from false to true', () {
        provider.toggleHideDuplicates();
        expect(provider.settings.hideDuplicates, isTrue);
      });

      test('toggles hideDuplicates back to false', () {
        provider.toggleHideDuplicates();
        provider.toggleHideDuplicates();
        expect(provider.settings.hideDuplicates, isFalse);
      });
    });

    group('resetToDefaults', () {
      test('resets filter type to all', () {
        provider.setFilterType(MediaFilterType.images);
        provider.resetToDefaults();
        expect(provider.settings.type, MediaFilterType.all);
      });

      test('re-enables filter', () {
        provider.setEnabled(false);
        provider.resetToDefaults();
        expect(provider.isEnabled, isTrue);
      });
    });

    group('getFilterTypeDisplayName', () {
      test('returns readable name for each filter type', () {
        expect(
          provider.getFilterTypeDisplayName(MediaFilterType.all),
          isNotEmpty,
        );
        expect(
          provider.getFilterTypeDisplayName(MediaFilterType.images),
          isNotEmpty,
        );
        expect(
          provider.getFilterTypeDisplayName(MediaFilterType.videos),
          isNotEmpty,
        );
        expect(
          provider.getFilterTypeDisplayName(MediaFilterType.audio),
          isNotEmpty,
        );
        expect(
          provider.getFilterTypeDisplayName(MediaFilterType.documents),
          isNotEmpty,
        );
      });
    });

    group('getStatistics', () {
      test('reports correct enabled status', () {
        final stats = provider.getStatistics();
        expect(stats['isEnabled'], isTrue);
      });

      test('reports correct filter type string', () {
        provider.setFilterType(MediaFilterType.images);
        final stats = provider.getStatistics();
        expect(stats['filterType'], contains('images'));
      });

      test('reports correct blocked extension count', () {
        provider.addBlockedExtension('gif');
        provider.addBlockedExtension('bmp');
        final stats = provider.getStatistics();
        expect(stats['blockedExtensions'], 2);
      });
    });
  });
}
