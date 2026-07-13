import 'package:flutter/material.dart';

/// AppBar のタイトル欄など幅が固定された場所で使う。
/// テキストが収まりきらない場合だけ、自動で左右にスクロールして全体を見せる。
class SlidingAppTitle extends StatelessWidget {
  const SlidingAppTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style;
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
        )..layout();

        if (painter.width <= constraints.maxWidth) {
          return Text(text, maxLines: 1, overflow: TextOverflow.clip);
        }
        return _MarqueeText(key: ValueKey(text), text: text);
      },
    );
  }
}

class _MarqueeText extends StatefulWidget {
  const _MarqueeText({super.key, required this.text});

  final String text;

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText> {
  final _scrollController = ScrollController();
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runLoop());
  }

  @override
  void dispose() {
    _disposed = true;
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _runLoop() async {
    while (!_disposed) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (_disposed || !_scrollController.hasClients) continue;
      final max = _scrollController.position.maxScrollExtent;
      if (max <= 0) continue;
      await _scrollController.animateTo(
        max,
        duration: Duration(
          milliseconds: (max * 30).round().clamp(800, 8000),
        ),
        curve: Curves.linear,
      );
      if (_disposed) return;
      await Future<void>.delayed(const Duration(seconds: 1));
      if (_disposed || !_scrollController.hasClients) continue;
      await _scrollController.animateTo(
        0,
        duration: Duration(
          milliseconds: (max * 30).round().clamp(800, 8000),
        ),
        curve: Curves.linear,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(widget.text, maxLines: 1, softWrap: false),
    );
  }
}
