import 'package:flutter_test/flutter_test.dart';
import 'package:kc_gallery_viewer/presentation/providers/download_provider.dart';

void main() {
  group('DownloadItem', () {
    group('progress getter', () {
      test('returns 0.0 when totalBytes is zero', () {
        final item = DownloadItem(
          id: '1',
          name: 'test.jpg',
          url: 'https://example.com/test.jpg',
          totalBytes: 0,
          startTime: DateTime.now(),
        );
        expect(item.progress, 0.0);
      });

      test('returns 0.5 when half downloaded', () {
        final item = DownloadItem(
          id: '1',
          name: 'test.jpg',
          url: 'https://example.com/test.jpg',
          totalBytes: 100,
          downloadedBytes: 50,
          startTime: DateTime.now(),
        );
        expect(item.progress, 0.5);
      });

      test('returns 1.0 when fully downloaded', () {
        final item = DownloadItem(
          id: '1',
          name: 'test.jpg',
          url: 'https://example.com/test.jpg',
          totalBytes: 200,
          downloadedBytes: 200,
          startTime: DateTime.now(),
        );
        expect(item.progress, 1.0);
      });

      test('returns 0.0 when downloadedBytes is default (zero)', () {
        final item = DownloadItem(
          id: '1',
          name: 'test.jpg',
          url: 'https://example.com/test.jpg',
          totalBytes: 1024,
          startTime: DateTime.now(),
        );
        expect(item.progress, 0.0);
      });
    });

    group('copyWith', () {
      test('returns new item with updated downloadedBytes', () {
        final original = DownloadItem(
          id: '1',
          name: 'test.jpg',
          url: 'https://example.com/test.jpg',
          totalBytes: 100,
          startTime: DateTime.now(),
        );
        final updated = original.copyWith(downloadedBytes: 60);
        expect(updated.downloadedBytes, 60);
        expect(updated.id, original.id);
        expect(updated.url, original.url);
        expect(updated.totalBytes, original.totalBytes);
      });

      test('returns new item with updated status', () {
        final original = DownloadItem(
          id: '1',
          name: 'test.jpg',
          url: 'https://example.com/test.jpg',
          totalBytes: 100,
          startTime: DateTime.now(),
        );
        final updated = original.copyWith(status: DownloadStatus.completed);
        expect(updated.status, DownloadStatus.completed);
        expect(updated.id, original.id);
      });

      test('preserves unchanged fields', () {
        final start = DateTime(2024, 1, 1);
        final original = DownloadItem(
          id: 'abc',
          name: 'file.mp4',
          url: 'https://example.com/file.mp4',
          totalBytes: 5000,
          downloadedBytes: 1000,
          status: DownloadStatus.downloading,
          startTime: start,
          savePath: '/downloads/file.mp4',
          referer: 'https://kemono.cr/',
        );
        final updated = original.copyWith(downloadedBytes: 2000);
        expect(updated.id, 'abc');
        expect(updated.name, 'file.mp4');
        expect(updated.url, 'https://example.com/file.mp4');
        expect(updated.totalBytes, 5000);
        expect(updated.status, DownloadStatus.downloading);
        expect(updated.savePath, '/downloads/file.mp4');
        expect(updated.referer, 'https://kemono.cr/');
      });

      test('updates error message', () {
        final original = DownloadItem(
          id: '1',
          name: 'test.jpg',
          url: 'https://example.com/test.jpg',
          totalBytes: 100,
          startTime: DateTime.now(),
        );
        final updated = original.copyWith(
          status: DownloadStatus.failed,
          errorMessage: 'Network error',
        );
        expect(updated.errorMessage, 'Network error');
        expect(updated.status, DownloadStatus.failed);
      });
    });

    group('default values', () {
      test('downloadedBytes defaults to 0', () {
        final item = DownloadItem(
          id: '1',
          name: 'test.jpg',
          url: 'https://example.com/test.jpg',
          totalBytes: 100,
          startTime: DateTime.now(),
        );
        expect(item.downloadedBytes, 0);
      });

      test('status defaults to pending', () {
        final item = DownloadItem(
          id: '1',
          name: 'test.jpg',
          url: 'https://example.com/test.jpg',
          totalBytes: 100,
          startTime: DateTime.now(),
        );
        expect(item.status, DownloadStatus.pending);
      });

      test('errorMessage defaults to null', () {
        final item = DownloadItem(
          id: '1',
          name: 'test.jpg',
          url: 'https://example.com/test.jpg',
          totalBytes: 100,
          startTime: DateTime.now(),
        );
        expect(item.errorMessage, isNull);
      });
    });
  });

  group('DownloadProvider', () {
    late DownloadProvider provider;

    setUp(() {
      provider = DownloadProvider();
    });

    tearDown(() {
      provider.dispose();
    });

    test('downloads list is empty on creation', () {
      expect(provider.downloads, isEmpty);
    });

    test('activeDownloads is empty on creation', () {
      expect(provider.activeDownloads, isEmpty);
    });

    test('completedDownloads is empty on creation', () {
      expect(provider.completedDownloads, isEmpty);
    });

    group('addDownload', () {
      test('returns a non-empty ID string', () {
        final id = provider.addDownload(
          name: 'test.jpg',
          url: 'https://example.com/test.jpg',
          savePath: '/tmp/test.jpg',
        );
        expect(id, isNotEmpty);
      });

      test('adds one item to the downloads list', () {
        provider.addDownload(
          name: 'test.jpg',
          url: 'https://example.com/test.jpg',
          savePath: '/tmp/test.jpg',
        );
        expect(provider.downloads.length, 1);
      });

      test('returned ID matches the item in downloads list', () {
        final id = provider.addDownload(
          name: 'test.jpg',
          url: 'https://example.com/test.jpg',
          savePath: '/tmp/test.jpg',
        );
        expect(provider.downloads.first.id, id);
      });

      test('stores correct name', () {
        provider.addDownload(
          name: 'my-file.jpg',
          url: 'https://example.com/my-file.jpg',
          savePath: '/tmp/my-file.jpg',
        );
        expect(provider.downloads.first.name, 'my-file.jpg');
      });

      test('stores correct URL', () {
        const url = 'https://example.com/my-file.jpg';
        provider.addDownload(
          name: 'my-file.jpg',
          url: url,
          savePath: '/tmp/my-file.jpg',
        );
        expect(provider.downloads.first.url, url);
      });

      test('stores optional referer', () {
        provider.addDownload(
          name: 'test.jpg',
          url: 'https://example.com/test.jpg',
          savePath: '/tmp/test.jpg',
          referer: 'https://coomer.st/',
        );
        expect(provider.downloads.first.referer, 'https://coomer.st/');
      });

      test('adds multiple downloads independently', () {
        provider.addDownload(
          name: 'a.jpg',
          url: 'https://example.com/a.jpg',
          savePath: '/tmp/a.jpg',
        );
        provider.addDownload(
          name: 'b.jpg',
          url: 'https://example.com/b.jpg',
          savePath: '/tmp/b.jpg',
        );
        expect(provider.downloads.length, 2);
      });
    });

    group('getDownloadById', () {
      test('returns null for unknown ID', () {
        expect(provider.getDownloadById('nonexistent'), isNull);
      });

      test('returns the matching download', () {
        final id = provider.addDownload(
          name: 'test.jpg',
          url: 'https://example.com/test.jpg',
          savePath: '/tmp/test.jpg',
        );
        final item = provider.getDownloadById(id);
        expect(item, isNotNull);
        expect(item!.id, id);
      });
    });

    group('removeDownload', () {
      test('removes the item with matching ID', () {
        final id = provider.addDownload(
          name: 'test.jpg',
          url: 'https://example.com/test.jpg',
          savePath: '/tmp/test.jpg',
        );
        provider.removeDownload(id);
        expect(provider.downloads, isEmpty);
      });

      test('only removes the specified item', () {
        final id1 = provider.addDownload(
          name: 'a.jpg',
          url: 'https://example.com/a.jpg',
          savePath: '/tmp/a.jpg',
        );
        provider.addDownload(
          name: 'b.jpg',
          url: 'https://example.com/b.jpg',
          savePath: '/tmp/b.jpg',
        );
        provider.removeDownload(id1);
        expect(provider.downloads.length, 1);
        expect(provider.downloads.first.name, 'b.jpg');
      });

      test('does nothing for unknown ID', () {
        provider.addDownload(
          name: 'test.jpg',
          url: 'https://example.com/test.jpg',
          savePath: '/tmp/test.jpg',
        );
        provider.removeDownload('nonexistent');
        expect(provider.downloads.length, 1);
      });
    });

    group('retryDownload', () {
      test('does nothing for unknown ID', () {
        // Should not throw
        expect(() => provider.retryDownload('nonexistent'), returnsNormally);
      });

      test('does nothing for a download that is actively downloading', () {
        final id = provider.addDownload(
          name: 'test.jpg',
          url: 'https://example.com/test.jpg',
          savePath: '/tmp/test.jpg',
        );
        final before = provider.downloads.length;
        provider.retryDownload(id);
        // Should not add a duplicate
        expect(provider.downloads.length, before);
      });
    });

    group('cancelDownload', () {
      test('does not throw for unknown download ID', () {
        expect(
          () => provider.cancelDownload('nonexistent'),
          returnsNormally,
        );
      });

      test('does not throw for active download', () {
        final id = provider.addDownload(
          name: 'test.jpg',
          url: 'https://example.com/test.jpg',
          savePath: '/tmp/test.jpg',
        );
        expect(() => provider.cancelDownload(id), returnsNormally);
      });
    });

    group('clearCompleted', () {
      test('does nothing when there are no completed downloads', () {
        provider.addDownload(
          name: 'test.jpg',
          url: 'https://example.com/test.jpg',
          savePath: '/tmp/test.jpg',
        );
        provider.clearCompleted();
        // Active download should remain
        expect(provider.downloads.length, 1);
      });
    });
  });
}
