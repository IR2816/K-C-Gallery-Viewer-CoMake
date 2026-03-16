import '../../domain/repositories/kemono_repository.dart';
import '../../domain/entities/creator.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/comment.dart';
import '../../domain/entities/api_source.dart';
import '../datasources/kemono_remote_datasource.dart';
import '../datasources/kemono_remote_datasource_impl.dart';
import '../datasources/kemono_local_datasource.dart';
import '../models/creator_model.dart';
import '../models/post_model.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../../utils/logger.dart';

class KemonoRepositoryImpl implements KemonoRepository {
  final KemonoRemoteDataSource remoteDataSource;
  final KemonoLocalDataSource localDataSource;

  KemonoRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<List<Creator>> getCreators({
    String? service,
    ApiSource apiSource = ApiSource.kemono,
  }) async {
    final creators = await remoteDataSource.getCreators(
      service: service,
      apiSource: apiSource,
    );
    final favorites = await localDataSource.getFavoriteCreators();

    return creators.map((creator) {
      final isFavorited = favorites.any(
        (fav) => fav.id == creator.id && fav.service == creator.service,
      );
      return creator.copyWith(favorited: isFavorited);
    }).toList();
  }

  @override
  Future<Creator> getCreator(
    String service,
    String creatorId, {
    ApiSource apiSource = ApiSource.kemono,
  }) async {
    return await remoteDataSource.getCreator(
      service,
      creatorId,
      apiSource: apiSource,
    );
  }

  @override
  Future<List<dynamic>> getCreatorLinks(
    String service,
    String creatorId, {
    ApiSource apiSource = ApiSource.kemono,
  }) async {
    return await remoteDataSource.getCreatorLinks(
      service,
      creatorId,
      apiSource: apiSource,
    );
  }

  @override
  Future<List<Post>> getCreatorPosts(
    String service,
    String creatorId, {
    int offset = 0,
    ApiSource apiSource = ApiSource.kemono,
  }) async {
    final postModels = await remoteDataSource.getCreatorPosts(
      service,
      creatorId,
      offset: offset,
      apiSource: apiSource,
    );
    final savedPosts = await localDataSource.getSavedPosts();

    return postModels.map((postModel) {
      final isSaved = savedPosts.any((saved) => saved.id == postModel.id);
      return Post(
        id: postModel.id,
        user: postModel.user,
        service: postModel.service,
        title: postModel.title,
        content: postModel.content,
        embedUrl: postModel.embedUrl,
        sharedFile: postModel.sharedFile,
        added: postModel.added,
        published: postModel.published,
        edited: postModel.edited,
        attachments: postModel.attachments,
        file: postModel.file,
        tags: postModel.tags,
        saved: isSaved,
      );
    }).toList();
  }

  @override
  Future<Post> getPost(
    String service,
    String creatorId,
    String postId, {
    ApiSource apiSource = ApiSource.kemono,
  }) async {
    final postModel = await remoteDataSource.getPost(
      service,
      creatorId,
      postId,
      apiSource: apiSource,
    );
    final savedPosts = await localDataSource.getSavedPosts();

    final isSaved = savedPosts.any((saved) => saved.id == postModel.id);
    return Post(
      id: postModel.id,
      user: postModel.user,
      service: postModel.service,
      title: postModel.title,
      content: postModel.content,
      embedUrl: postModel.embedUrl,
      sharedFile: postModel.sharedFile,
      added: postModel.added,
      published: postModel.published,
      edited: postModel.edited,
      attachments: postModel.attachments,
      file: postModel.file,
      tags: postModel.tags,
      saved: isSaved,
    );
  }

  @override
  Future<List<Post>> searchPosts(
    String query, {
    int offset = 0,
    int limit = 50,
    ApiSource apiSource = ApiSource.kemono,
  }) async {
    final postModels = await remoteDataSource.searchPosts(
      query,
      offset: offset,
      limit: limit,
      apiSource: apiSource,
    );
    final savedPosts = await localDataSource.getSavedPosts();

    return postModels.map((postModel) {
      final isSaved = savedPosts.any((saved) => saved.id == postModel.id);
      return Post(
        id: postModel.id,
        user: postModel.user,
        service: postModel.service,
        title: postModel.title,
        content: postModel.content,
        embedUrl: postModel.embedUrl,
        sharedFile: postModel.sharedFile,
        added: postModel.added,
        published: postModel.published,
        edited: postModel.edited,
        attachments: postModel.attachments,
        file: postModel.file,
        tags: postModel.tags,
        saved: isSaved,
      );
    }).toList();
  }

  @override
  Future<List<Post>> getPostsByTags(
    List<String> tags, {
    int offset = 0,
    ApiSource apiSource = ApiSource.kemono,
  }) async {
    final query = tags.join(' ');
    return await searchPosts(query, offset: offset, apiSource: apiSource);
  }

  @override
  Future<List<Creator>> searchCreators(
    String query, {
    ApiSource apiSource = ApiSource.kemono,
    String? service,
  }) async {
    final lowerQuery = query.toLowerCase().trim();

    debugPrint(
      'KemonoRepository: searchCreators query=$query apiSource=$apiSource service=$service',
    );

    if (lowerQuery.isEmpty) {
      return [];
    }

    final isNumericId = RegExp(r'^\d+$').hasMatch(lowerQuery);
    if (isNumericId &&
        service != null &&
        service.isNotEmpty &&
        service != 'all') {
      try {
        debugPrint(
          'KemonoRepository: Trying direct creator lookup: /v1/$service/user/$lowerQuery/profile',
        );
        final creator = await remoteDataSource.getCreator(
          service,
          lowerQuery,
          apiSource: apiSource,
        );
        debugPrint(
          'KemonoRepository: Found creator: ${creator.name} (${creator.id})',
        );
        return [creator];
      } catch (e) {
        debugPrint('KemonoRepository: Direct lookup failed: $e');
        // Fall back to list-based search below.
      }
    }

    final allCreators = await remoteDataSource.getCreators(
      service: service,
      apiSource: apiSource,
    );

    // Separate exact matches from partial matches
    final exactIdMatches = <Creator>[];
    final exactNameMatches = <Creator>[];
    final partialMatches = <Creator>[];

    for (final creator in allCreators) {
      final creatorId = creator.id.toLowerCase();
      final creatorName = creator.name.toLowerCase();
      final creatorService = creator.service.toLowerCase();

      // Exact ID match (highest priority)
      if (creatorId == lowerQuery) {
        exactIdMatches.add(creator);
      }
      // Exact name match (second priority)
      else if (creatorName == lowerQuery) {
        exactNameMatches.add(creator);
      }
      // Partial matches
      else if (creatorId.contains(lowerQuery) ||
          creatorName.contains(lowerQuery) ||
          creatorService.contains(lowerQuery)) {
        partialMatches.add(creator);
      }
    }

    // Return results in priority order: exact ID matches, exact name matches, then partial matches
    return [...exactIdMatches, ...exactNameMatches, ...partialMatches];
  }

  @override
  Future<List<Creator>> getFavoriteCreators() async {
    return await localDataSource.getFavoriteCreators();
  }

  @override
  Future<void> saveFavoriteCreator(Creator creator) async {
    await localDataSource.saveFavoriteCreator(CreatorModel.fromEntity(creator));
  }

  @override
  Future<void> removeFavoriteCreator(String id, {String? service}) async {
    await localDataSource.removeFavoriteCreator(id, service: service);
  }

  @override
  Future<List<Post>> getSavedPosts({int offset = 0, int limit = 50}) async {
    final allSaved = await localDataSource.getSavedPosts();
    final paginated = allSaved.skip(offset).take(limit).toList();
    return paginated
        .map(
          (postModel) => Post(
            id: postModel.id,
            user: postModel.user,
            service: postModel.service,
            title: postModel.title,
            content: postModel.content,
            embedUrl: postModel.embedUrl,
            sharedFile: postModel.sharedFile,
            added: postModel.added,
            published: postModel.published,
            edited: postModel.edited,
            attachments: postModel.attachments,
            file: postModel.file,
            tags: postModel.tags,
            saved: true,
          ),
        )
        .toList();
  }

  @override
  Future<void> savePost(Post post) async {
    await localDataSource.savePost(PostModel.fromEntity(post));
  }

  @override
  Future<void> removeSavedPost(String id) async {
    await localDataSource.removeSavedPost(id);
  }

  @override
  Future<Map<String, dynamic>> getSettings() async {
    return await localDataSource.getSettings();
  }

  @override
  Future<void> saveSettings(Map<String, dynamic> settings) async {
    await localDataSource.saveSettings(settings);
  }

  @override
  Future<List<Comment>> getComments(
    String postId,
    String service,
    String creatorId,
  ) async {
    try {
      AppLogger.debug(
        '🔍 DEBUG: Repository getComments called with postId: $postId, service: $service, creatorId: $creatorId',
      );
      final commentsData = await remoteDataSource.getComments(
        postId,
        service,
        creatorId,
      );
      AppLogger.debug(
        '🔍 DEBUG: Remote datasource returned ${commentsData.length} comment data items',
      );

      final comments = commentsData
          .map((data) => Comment.fromJson(data))
          .toList();
      AppLogger.debug('🔍 DEBUG: Parsed ${comments.length} comment objects');
      return comments;
    } catch (e) {
      debugPrint('Error fetching comments: $e');
      AppLogger.debug('🔍 DEBUG: Repository error: $e');
      return [];
    }
  }

  @override
  String? getLastSuccessfulDomain() {
    final remoteDS = remoteDataSource;
    if (remoteDS is KemonoRemoteDataSourceImpl) {
      return remoteDS.lastSuccessfulDomain;
    }
    return null;
  }
}