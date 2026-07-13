import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';

/// 下部ナビ(Back / Home / アプリ一覧)。Android 標準の並び・図形を踏襲する
/// (馴染みのあるパターン)。
///
/// Recents(アプリ履歴)ボタンは意図的に持たない: Android には
/// ディスプレイ単位で Recents を呼び出す公式 API が存在せず
/// (`GLOBAL_ACTION_RECENTS` は常に本体側ディスプレイに作用する)、
/// 端からのスワイプ注入も外部ディスプレイ側にジェスチャーナビゲーションの
/// 受け手が無ければ何も起きないため。代わりに、任意のアプリを外部ディスプレイで
/// 直接起動できる「アプリ一覧」ボタンを Home の右に置く。
class SystemNavBar extends StatelessWidget {
  const SystemNavBar({
    super.key,
    required this.enabled,
    required this.onBack,
    required this.onHome,
    required this.onAppList,
  });

  final bool enabled;
  final VoidCallback onBack;
  final VoidCallback onHome;
  final VoidCallback onAppList;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppDimens.bottomNavHeight,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: _NavButton(
              icon: Icons.arrow_back,
              enabled: enabled,
              onTap: onBack,
            ),
          ),
          Expanded(
            child: _NavButton(
              icon: Icons.circle_outlined,
              enabled: enabled,
              onTap: onHome,
            ),
          ),
          Expanded(
            child: _NavButton(
              icon: Icons.apps,
              enabled: enabled,
              onTap: onAppList,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatefulWidget {
  const _NavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = !widget.enabled
        ? AppColors.disabled
        : (_pressed ? AppColors.foregroundPressed : AppColors.foreground);

    return GestureDetector(
      // アイコンの描画領域だけでなく、3分割された各エリア全体をタップ可能にする
      // (deferToChild のままだとアイコン上しか反応せず操作ミスを誘発する)。
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.enabled ? widget.onTap : null,
      child: SizedBox.expand(child: Icon(widget.icon, color: color, size: 28)),
    );
  }
}
