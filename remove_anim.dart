import 'dart:io';
void main() {
  final file = File('lib/presentation/widgets/post_grid.dart');
  var content = file.readAsStringSync();
  
  content = content.replaceAll(
    'return RepaintBoundary(\n              child: StaggeredFadeItem(\n                index: index,\n                epoch: animationEpoch,\n                child: PostCard(',
    'return RepaintBoundary(\n              child: PostCard('
  );
  content = content.replaceAll(
    'onCreatorTap: () => onCreatorTap(post),\n                ),\n              ),\n            );',
    'onCreatorTap: () => onCreatorTap(post),\n              ),\n            );'
  );
  
  file.writeAsStringSync(content);
}
