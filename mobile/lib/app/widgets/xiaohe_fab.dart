import 'package:flutter/material.dart';
import 'package:mobile/app/widgets/app_haptics.dart';
import 'package:mobile/features/mentor/presentation/widgets/mentor_panel_sheet.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// 共享「小禾」导师 FAB（规范 §XiaoheFAB，2026-05-29 收敛）。
///
/// 统一三要素：`Icons.auto_awesome` 图标、`mentorName` tooltip、点击时的
/// 轻触 haptics + `openMentorPanelSheet`。外观沿用主题
/// `floatingActionButtonTheme`（accent / white / CircleBorder）。
///
/// 调用点仅需提供 [launcher]（埋点入口）、[surface]（来源面）与可选 [small]
/// 形态；`key` 由调用方通过 `super.key` 传入以保留各自的语义标识。
class XiaoheFab extends StatelessWidget {
  const XiaoheFab({
    super.key,
    required this.launcher,
    this.surface = 'home',
    this.small = false,
  });

  /// 埋点入口标识，例如 `shell_fab` / `home_fab`。
  final String launcher;

  /// 来源面标识，透传给 [openMentorPanelSheet]。
  final String surface;

  /// 是否使用 `FloatingActionButton.small` 紧凑形态。
  final bool small;

  void _onPressed(BuildContext context) {
    AppHaptics.lightTap();
    openMentorPanelSheet(context, launcher: launcher, surface: surface);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    const icon = Icon(Icons.auto_awesome);
    if (small) {
      return FloatingActionButton.small(
        tooltip: l.mentorName,
        onPressed: () => _onPressed(context),
        child: icon,
      );
    }
    return FloatingActionButton(
      tooltip: l.mentorName,
      onPressed: () => _onPressed(context),
      child: icon,
    );
  }
}
