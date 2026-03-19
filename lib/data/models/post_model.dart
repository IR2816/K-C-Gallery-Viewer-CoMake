import '../../domain/entities/post.dart';
import 'post_file_model.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class PostModel extends Post {
  PostModel({
    required super.id,
    required super.user,
    required super.service,
    required super.title,
    required super.content,
    super.embedUrl,
    required super.sharedFile,
    required super.added,
    required super.published,
    required super.edited,
    required super.attachments,
    required super.file,
    required super.tags,
    super.saved,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    // Handle both single post API response (with "post" wrapper) and list API response (direct)
    final Map<String, dynamic> postData;
    if (json.containsKey('post') && json['post'] is Map) {
      postData = json['post'] as Map<String, dynamic>;
      debugPrint('PostModel: Parsing single post response with wrapper');
    } else {
      postData = json;
      debugPrint('PostModel: Parsing list response (direct)');
    }

    debugPrint('PostModel: postData keys=${postData.keys.toList()}');
    debugPrint(
      'PostModel: postData types=${postData.map((key, value) => MapEntry(key, value.runtimeType))}',
    );
    debugPrint(
      'PostModel: content length=${postData['content']?.toString().length ?? 0}',
    );
    debugPrint(
      'PostModel: content preview=${postData['content']?.toString().length != null && postData['content'].toString().length > 100 ? postData['content'].toString().substring(0, 100) : postData['content']}',
    );
    debugPrint('PostModel: tags=${postData['tags']}');

    // DEBUG: Check media data
    debugPrint('=== DEBUG: MEDIA DATA ===');
    debugPrint(
      'PostModel: attachments type=${postData['attachments'].runtimeType}',
    );
    debugPrint(
      'PostModel: attachments length=${(postData['attachments'] as List?)?.length ?? 0}',
    );
    if (postData['attachments'] != null &&
        postData['attachments'] is List &&
        (postData['attachments'] as List).isNotEmpty) {
      debugPrint(
        'PostModel: first attachment=${(postData['attachments'] as List).first}',
      );
    }

    debugPrint('PostModel: file type=${postData['file'].runtimeType}');
    if (postData['file'] != null) {
      if (postData['file'] is Map) {
        debugPrint(
          'PostModel: file is Map with keys=${(postData['file'] as Map).keys.toList()}',
        );
      } else if (postData['file'] is List) {
        debugPrint(
          'PostModel: file is List with length=${(postData['file'] as List).length}',
        );
        if ((postData['file'] as List).isNotEmpty) {
          debugPrint(
            'PostModel: first file=${(postData['file'] as List).first}',
          );
        }
      }
    }
    debugPrint('=== END MEDIA DEBUG ===');

    // Safe parsing with type checking
    return PostModel(
      id: postData['id']?.toString() ?? '',
      user: postData['user']?.toString() ?? '',
      service: postData['service']?.toString() ?? '',
      title: postData['title']?.toString().isNotEmpty == true
          ? postData['title'].toString()
          : 'Post from ${DateTime.tryParse(postData['published']?.toString() ?? '')?.day ?? ''}',
      content:
          postData['content']?.toString() ??
          postData['substring']?.toString() ??
          postData['text']?.toString() ??
          '',
      embedUrl: postData['embed']?['url']?.toString(),
      sharedFile: postData['shared_file']?.toString() ?? '',
      added:
          DateTime.tryParse(postData['added']?.toString() ?? '') ??
          DateTime.now(),
      published:
          DateTime.tryParse(postData['published']?.toString() ?? '') ??
          DateTime.now(),
      edited:
          DateTime.tryParse(postData['edited']?.toString() ?? '') ??
          DateTime.now(),
      attachments:
          (postData['attachments'] as List?)
              ?.map((e) => PostFileModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      file: (postData['file'] != null && postData['file'] is Map)
          ? [PostFileModel.fromJson(postData['file'] as Map<String, dynamic>)]
          : (postData['file'] as List?)
                    ?.map(
                      (e) => PostFileModel.fromJson(e as Map<String, dynamic>),
                    )
                    .toList() ??
                [],
      tags:
          (postData['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      saved: postData['saved'] is bool
          ? postData['saved'] as bool
          : postData['saved']?.toString().toLowerCase() == 'true',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': user,
      'service': service,
      'title': title,
      'content': content,
      'embed': embedUrl != null ? {'url': embedUrl} : null,
      'shared_file': sharedFile,
      'added': added.toIso8601String(),
      'published': published.toIso8601String(),
      'edited': edited.toIso8601String(),
      'attachments': attachments
          .map((e) => (e as PostFileModel).toJson())
          .toList(),
      'file': file.map((e) => (e as PostFileModel).toJson()).toList(),
      'tags': tags,
      'saved': saved,
    };
  }

  factory PostModel.fromEntity(Post post) {
    return PostModel(
      id: post.id,
      user: post.user,
      service: post.service,
      title: post.title,
      content: post.content,
      embedUrl: post.embedUrl,
      sharedFile: post.sharedFile,
      added: post.added,
      published: post.published,
      edited: post.edited,
      attachments: post.attachments,
      file: post.file,
      tags: post.tags,
      saved: post.saved,
    );
  }
}
