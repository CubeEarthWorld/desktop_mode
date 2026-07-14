import 'package:flutter/widgets.dart';

/// go_router の Navigator に登録し、画面が他の画面(設定など)に覆われた/
/// 覆いから戻ったことを `RouteAware` で購読できるようにする。
final routeObserver = RouteObserver<PageRoute<dynamic>>();
