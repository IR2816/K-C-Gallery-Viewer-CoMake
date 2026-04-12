import 'package:flutter_test/flutter_test.dart';
import 'package:kc_gallery_viewer/config/domain_config.dart';
import 'package:kc_gallery_viewer/presentation/utils/media_preview_resolver.dart';

void main() {
  group('DomainConfig', () {
    group('getApiBaseUrl', () {
      test('returns kemono API URL for kemono domain', () {
        expect(
          DomainConfig.getApiBaseUrl('kemono.cr'),
          'https://kemono.cr/api',
        );
      });

      test('returns coomer API URL for coomer domain', () {
        expect(
          DomainConfig.getApiBaseUrl('coomer.st'),
          'https://coomer.st/api',
        );
      });

      test('always uses https scheme', () {
        final url = DomainConfig.getApiBaseUrl('kemono.cr');
        expect(url, startsWith('https://'));
      });
    });

    group('getMediaBaseUrl', () {
      test('returns n4 subdomain for kemono', () {
        expect(
          DomainConfig.getMediaBaseUrl('kemono.cr'),
          'https://n4.kemono.cr',
        );
      });

      test('returns n4 subdomain for coomer', () {
        expect(
          DomainConfig.getMediaBaseUrl('coomer.st'),
          'https://n4.coomer.st',
        );
      });
    });

    group('getThumbnailBaseUrl', () {
      test('returns img subdomain with /thumbnail/data for kemono', () {
        expect(
          DomainConfig.getThumbnailBaseUrl('kemono.cr'),
          'https://img.kemono.cr/thumbnail/data',
        );
      });

      test('returns img subdomain with /thumbnail/data for coomer', () {
        expect(
          DomainConfig.getThumbnailBaseUrl('coomer.st'),
          'https://img.coomer.st/thumbnail/data',
        );
      });
    });

    group('isValidDomain', () {
      test('returns true for valid kemono domain', () {
        expect(DomainConfig.isValidDomain('kemono.cr'), isTrue);
      });

      test('returns true for valid coomer domain', () {
        expect(DomainConfig.isValidDomain('coomer.st'), isTrue);
      });

      test('returns true for standard two-part domain', () {
        expect(DomainConfig.isValidDomain('example.com'), isTrue);
      });

      test('returns false for empty string', () {
        expect(DomainConfig.isValidDomain(''), isFalse);
      });

      test('returns false when domain contains protocol prefix', () {
        expect(DomainConfig.isValidDomain('https://kemono.cr'), isFalse);
      });

      test('returns false for string with no dot separator', () {
        expect(DomainConfig.isValidDomain('nodot'), isFalse);
      });
    });

    group('cleanDomain', () {
      test('strips https:// prefix', () {
        expect(DomainConfig.cleanDomain('https://kemono.cr'), 'kemono.cr');
      });

      test('strips http:// prefix', () {
        expect(DomainConfig.cleanDomain('http://kemono.cr'), 'kemono.cr');
      });

      test('removes trailing slash', () {
        expect(DomainConfig.cleanDomain('kemono.cr/'), 'kemono.cr');
      });

      test('leaves plain domain unchanged', () {
        expect(DomainConfig.cleanDomain('kemono.cr'), 'kemono.cr');
      });

      test('strips both protocol and trailing slash', () {
        expect(DomainConfig.cleanDomain('https://kemono.cr/'), 'kemono.cr');
      });

      test('trims surrounding whitespace', () {
        expect(DomainConfig.cleanDomain('  kemono.cr  '), 'kemono.cr');
      });
    });

    group('getApiDomains', () {
      test('returns kemono API domains for kemono domain', () {
        final domains = DomainConfig.getApiDomains('kemono.cr');
        expect(domains, isNotEmpty);
        expect(domains.every((d) => d.contains('kemono')), isTrue);
      });

      test('returns coomer API domains for coomer domain', () {
        final domains = DomainConfig.getApiDomains('coomer.st');
        expect(domains, isNotEmpty);
        expect(domains.every((d) => d.contains('coomer')), isTrue);
      });
    });
  });

  group('MediaPreviewResolver', () {
    group('getThumbnailUrlFromPath', () {
      test('builds kemono thumbnail URL from /data/ path', () {
        const path =
            '/data/a4/41/a441621b83f7bf93d7ff1972fb7848233ac5e253c93365e451c0f00022d502a0.jpg';
        final result = MediaPreviewResolver.getThumbnailUrlFromPath(
          path,
          'kemono',
        );
        expect(
          result,
          'https://img.kemono.cr/thumbnail/data/a4/41/a441621b83f7bf93d7ff1972fb7848233ac5e253c93365e451c0f00022d502a0.jpg',
        );
      });

      test('builds coomer thumbnail URL from /data/ path', () {
        const path =
            '/data/56/0b/560b7d65dc462caebf9a1530d95bd47374a0fdf2e40a585c83f3046b4ab1ba1e.jpg';
        final result = MediaPreviewResolver.getThumbnailUrlFromPath(
          path,
          'coomer',
        );
        expect(
          result,
          'https://img.coomer.st/thumbnail/data/56/0b/560b7d65dc462caebf9a1530d95bd47374a0fdf2e40a585c83f3046b4ab1ba1e.jpg',
        );
      });

      test('returns empty string for empty path', () {
        final result = MediaPreviewResolver.getThumbnailUrlFromPath(
          '',
          'kemono',
        );
        expect(result, isEmpty);
      });

      test('returns empty string when path has no /data/ segment', () {
        final result = MediaPreviewResolver.getThumbnailUrlFromPath(
          '/files/image.jpg',
          'kemono',
        );
        expect(result, isEmpty);
      });

      test('strips query parameters before building thumbnail URL', () {
        const path = '/data/ab/cd/image.jpg?f=some-query';
        final result = MediaPreviewResolver.getThumbnailUrlFromPath(
          path,
          'kemono',
        );
        expect(result, 'https://img.kemono.cr/thumbnail/data/ab/cd/image.jpg');
      });

      test('strips fragment before building thumbnail URL', () {
        const path = '/data/ab/cd/image.jpg#section';
        final result = MediaPreviewResolver.getThumbnailUrlFromPath(
          path,
          'kemono',
        );
        expect(result, 'https://img.kemono.cr/thumbnail/data/ab/cd/image.jpg');
      });
    });

    group('buildMediaItem', () {
      test('builds kemono CDN full URL for patreon service', () {
        const path = '/data/ab/cd/image.jpg';
        final item = MediaPreviewResolver.buildMediaItem(
          name: 'image.jpg',
          path: path,
          service: 'patreon',
        );
        expect(item['url'], contains('n2.kemono.cr'));
        expect(item['thumbnail_url'], contains('img.kemono.cr'));
      });

      test('builds coomer CDN full URL for onlyfans service', () {
        const path = '/data/ab/cd/image.jpg';
        final item = MediaPreviewResolver.buildMediaItem(
          name: 'image.jpg',
          path: path,
          service: 'onlyfans',
        );
        expect(item['url'], contains('n2.coomer.st'));
        expect(item['thumbnail_url'], contains('img.coomer.st'));
      });

      test('builds coomer CDN URL for fansly service', () {
        const path = '/data/ab/cd/image.jpg';
        final item = MediaPreviewResolver.buildMediaItem(
          name: 'image.jpg',
          path: path,
          service: 'fansly',
        );
        expect(item['url'], contains('coomer'));
      });

      test('identifies image type for jpg file', () {
        final item = MediaPreviewResolver.buildMediaItem(
          name: 'photo.jpg',
          path: '/data/ab/cd/photo.jpg',
          service: 'patreon',
        );
        expect(item['type'], 'image');
      });

      test('identifies image type for png file', () {
        final item = MediaPreviewResolver.buildMediaItem(
          name: 'photo.png',
          path: '/data/ab/cd/photo.png',
          service: 'patreon',
        );
        expect(item['type'], 'image');
      });

      test('identifies video type for mp4 file', () {
        final item = MediaPreviewResolver.buildMediaItem(
          name: 'clip.mp4',
          path: '/data/ab/cd/clip.mp4',
          service: 'patreon',
        );
        expect(item['type'], 'video');
      });

      test('identifies video type for webm file', () {
        final item = MediaPreviewResolver.buildMediaItem(
          name: 'clip.webm',
          path: '/data/ab/cd/clip.webm',
          service: 'patreon',
        );
        expect(item['type'], 'video');
      });

      test('preserves file name in result', () {
        final item = MediaPreviewResolver.buildMediaItem(
          name: 'my-image.jpg',
          path: '/data/ab/cd/my-image.jpg',
          service: 'patreon',
        );
        expect(item['name'], 'my-image.jpg');
      });

      test('respects explicit type parameter over inferred type', () {
        final item = MediaPreviewResolver.buildMediaItem(
          name: 'clip.mp4',
          path: '/data/ab/cd/clip.mp4',
          service: 'patreon',
          type: 'image',
        );
        expect(item['type'], 'image');
      });
    });

    group('selectThumbnailMedia', () {
      test('returns null for empty list', () {
        expect(MediaPreviewResolver.selectThumbnailMedia([]), isNull);
      });

      test('returns first image when multiple types present', () {
        final media = [
          {'type': 'video', 'url': 'video.mp4'},
          {'type': 'image', 'url': 'photo.jpg'},
        ];
        final result = MediaPreviewResolver.selectThumbnailMedia(media);
        expect(result!['type'], 'image');
        expect(result['url'], 'photo.jpg');
      });

      test('returns first item when no images present', () {
        final media = [
          {'type': 'video', 'url': 'video1.mp4'},
          {'type': 'video', 'url': 'video2.mp4'},
        ];
        final result = MediaPreviewResolver.selectThumbnailMedia(media);
        expect(result!['url'], 'video1.mp4');
      });
    });
  });
}
