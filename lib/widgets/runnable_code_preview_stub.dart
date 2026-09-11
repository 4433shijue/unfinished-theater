import 'package:flutter/material.dart';

class RunnableCodePreview extends StatelessWidget {
  const RunnableCodePreview({
    super.key,
    required this.document,
    required this.height,
    this.onAction,
  });

  final String document;
  final double height;
  final ValueChanged<String>? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: height),
      alignment: Alignment.center,
      child: Text(
        '当前平台暂不支持直接运行 HTML 预览。',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class RunnableCodePreviewInteractionGuard {
  const RunnableCodePreviewInteractionGuard._();

  static void pushBlock() {}

  static void popBlock() {}
}
