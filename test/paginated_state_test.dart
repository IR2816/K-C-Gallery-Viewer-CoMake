import 'package:flutter_test/flutter_test.dart';
import 'package:kc_gallery_viewer/presentation/utils/paginated_state.dart';

void main() {
  group('PaginatedState', () {
    test('constructor copies initial items list', () {
      final original = <int>[1, 2];
      final state = PaginatedState<int>(items: original);

      original.add(3);
      expect(state.items, <int>[1, 2]);
    });

    test('reset returns state to defaults and clears items', () {
      final state = PaginatedState<int>(
        items: <int>[1, 2],
        offset: 10,
        hasMore: false,
        isLoading: true,
        error: 'err',
      );

      state.reset();

      expect(state.items, isEmpty);
      expect(state.offset, 0);
      expect(state.hasMore, isTrue);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('setLoading updates isLoading flag', () {
      final state = PaginatedState<int>();
      state.setLoading(true);
      expect(state.isLoading, isTrue);
      state.setLoading(false);
      expect(state.isLoading, isFalse);
    });

    test('setError updates error field', () {
      final state = PaginatedState<int>();
      state.setError('boom');
      expect(state.error, 'boom');
      state.setError(null);
      expect(state.error, isNull);
    });

    test('appendPage appends items and increments offset', () {
      final state = PaginatedState<int>(items: <int>[1], offset: 1);
      state.appendPage(<int>[2, 3], 10);

      expect(state.items, <int>[1, 2, 3]);
      expect(state.offset, 3);
    });

    test('appendPage sets hasMore true when page size equals limit', () {
      final state = PaginatedState<int>();
      state.appendPage(<int>[1, 2], 2);
      expect(state.hasMore, isTrue);
    });

    test('appendPage sets hasMore false when page size is below limit', () {
      final state = PaginatedState<int>();
      state.appendPage(<int>[1], 2);
      expect(state.hasMore, isFalse);
    });
  });
}
