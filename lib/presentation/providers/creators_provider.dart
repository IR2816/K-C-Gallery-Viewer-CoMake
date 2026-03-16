import 'package:flutter/foundation.dart';
import '../../domain/repositories/kemono_repository.dart';
import '../../domain/entities/creator.dart';
import '../../domain/entities/api_source.dart';
import 'settings_provider.dart';

class CreatorsProvider with ChangeNotifier {
  final KemonoRepository repository;
  final SettingsProvider settingsProvider;

  CreatorsProvider({required this.repository, required this.settingsProvider});

  List<Creator> _creators = [];
  bool _isLoading = false;
  String? _error;
  String? _selectedService;
  List<String> _favoriteCreators = [];

  List<Creator> get creators => _creators;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedService => _selectedService;
  List<String> get favoriteCreators => _favoriteCreators;

  Future<void> loadCreators({String? service}) async {
    _isLoading = true;
    _error = null;
    _selectedService = service;
    notifyListeners();

    try {
      _creators = await repository.getCreators(
        service: service,
        apiSource: settingsProvider.defaultApiSource,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
      _creators = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchCreators(
    String query, {
    ApiSource apiSource = ApiSource.kemono,
    String? service,
  }) async {
    final trimmedQuery = query.trim();
    final isNumericId = RegExp(r'^\d+$').hasMatch(trimmedQuery);
    final isAllService = service == null || service.isEmpty || service == 'all';
    if (isNumericId && isAllService) {
      _isLoading = false;
      _selectedService = service;
      _creators = [];
      _error =
          'Numeric ID search requires selecting a specific service (e.g. Patreon/OnlyFans). Please pick a service and retry.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    _selectedService = service;
    notifyListeners();

    try {
      _creators = await repository.searchCreators(
        trimmedQuery,
        apiSource: apiSource,
        service: service,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
      _creators = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadFavorites() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _creators = await repository.getFavoriteCreators();
      _favoriteCreators = _creators.map((c) => c.id).toList();
      _error = null;
    } catch (e) {
      _error = e.toString();
      _creators = [];
      _favoriteCreators = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(Creator creator) async {
    try {
      final isCurrentlyFavorited = _favoriteCreators.contains(creator.id);

      if (isCurrentlyFavorited) {
        // Remove from favorites
        await repository.removeFavoriteCreator(
          creator.id,
          service: creator.service,
        );
        _favoriteCreators.remove(creator.id);

        // Remove from creators list if it's currently loaded
        _creators.removeWhere((c) => c.id == creator.id);
      } else {
        // Add to favorites
        await repository.saveFavoriteCreator(creator);
        _favoriteCreators.add(creator.id);

        // Add to creators list if it's currently loaded and not already present
        if (!_creators.any((c) => c.id == creator.id)) {
          _creators.insert(0, creator.copyWith(favorited: true));
        } else {
          // Update existing creator in the list
          final index = _creators.indexWhere((c) => c.id == creator.id);
          if (index != -1) {
            _creators[index] = _creators[index].copyWith(favorited: true);
          }
        }
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void clearCreators() {
    _creators.clear();
    _error = null;
    notifyListeners();
  }

  /// Get specific creator details
  Future<Creator?> getCreatorDetails(
    String service,
    String creatorId, {
    ApiSource apiSource = ApiSource.kemono,
  }) async {
    try {
      return await repository.getCreator(
        service,
        creatorId,
        apiSource: apiSource,
      );
    } catch (e) {
      _error = e.toString();
      return null;
    }
  }
}
