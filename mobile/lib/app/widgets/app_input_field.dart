import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';

/// `AppInputField` 的变体（规范 §2.13）。
enum AppInputFieldVariant {
  /// 标准输入框：`--bg-surface` 背景，用于 Auth / 表单。
  standard,

  /// 搜索框：`--bg-sunken` 背景 + 前置搜索图标 + 可选清除按钮（Discover）。
  search,
}

/// 共享输入框组件（规范 §2.13 InputField，2026-05-31 抽取）。
///
/// 收敛目标态：高度 ≈48、圆角 8（`--radius-sm` / `AppLayoutConstants.smallRadius`）、
/// 内边距 12/16、字号 16/w400、占位符 `textMuted`，聚焦态边框转 `accent`（1.4px）。
///
/// **平台取舍**：规范中「聚焦 0 0 0 3px rgba(255,140,66,0.1) 光晕」为 Web/HTML 概念，
/// Flutter `OutlineInputBorder` 无法原生渲染外发光，这里以 `accent` 加粗边框作为等价
/// 聚焦反馈（与主题 `inputDecorationTheme.focusedBorder` 一致），不伪造阴影环。
///
/// 该组件自建 `InputDecoration`（不复用主题 r16 默认），以保证圆角恒为 r8。
class AppInputField extends StatelessWidget {
  const AppInputField({
    super.key,
    this.controller,
    this.variant = AppInputFieldVariant.standard,
    this.hintText,
    this.labelText,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.obscureText = false,
    this.enabled = true,
    this.autofocus = false,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffixIcon,
    this.semanticsLabel,
    this.fieldKey,
  });

  final TextEditingController? controller;
  final AppInputFieldVariant variant;
  final String? hintText;
  final String? labelText;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// 搜索变体的清除回调；非空时在有文本时显示清除按钮。
  final VoidCallback? onClear;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final bool enabled;
  final bool autofocus;
  final int maxLines;

  /// 自定义前置图标（标准变体）；搜索变体默认使用 `Icons.search`。
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? semanticsLabel;

  /// 落在内部 `TextField` 上的语义 key，保持既有测试定位不变。
  final Key? fieldKey;

  bool get _isSearch => variant == AppInputFieldVariant.search;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final fillColor = _isSearch ? colors.bgSunken : colors.bgSurface;

    OutlineInputBorder borderWith(Color color, {double width = 1}) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppLayoutConstants.smallRadius),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    final effectivePrefix =
        prefixIcon ??
        (_isSearch
            ? Icon(
                Icons.search,
                size: AppLayoutConstants.iconSizeSm,
                color: colors.textMuted,
              )
            : null);

    Widget buildField(Widget? effectiveSuffix) {
      return TextField(
        key: fieldKey,
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        autofocus: autofocus,
        obscureText: obscureText,
        maxLines: obscureText ? 1 : maxLines,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: colors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          labelText: labelText,
          errorText: errorText,
          hintStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: colors.textMuted,
          ),
          prefixIcon: effectivePrefix,
          suffixIcon: effectiveSuffix,
          filled: true,
          fillColor: fillColor,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppLayoutConstants.spacingMd,
            vertical: AppLayoutConstants.spacingSm,
          ),
          border: borderWith(colors.outlineSoft),
          enabledBorder: borderWith(colors.outlineSoft),
          focusedBorder: borderWith(colors.accent, width: 1.4),
          errorBorder: borderWith(colors.error),
          focusedErrorBorder: borderWith(colors.error, width: 1.4),
          disabledBorder: borderWith(colors.outlineSoft),
        ),
      );
    }

    Widget? buildSuffixWithText(String text) {
      final showClear = _isSearch && onClear != null && text.isNotEmpty;
      return suffixIcon ??
          (showClear
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    size: AppLayoutConstants.iconSizeMd,
                    color: colors.textMuted,
                  ),
                  onPressed: onClear,
                )
              : null);
    }

    final field = controller == null
        ? buildField(buildSuffixWithText(''))
        : ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller!,
            builder: (context, value, _) {
              return buildField(buildSuffixWithText(value.text));
            },
          );

    if (semanticsLabel == null) {
      return field;
    }
    return Semantics(label: semanticsLabel, textField: true, child: field);
  }
}
