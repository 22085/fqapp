import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/home/home_design.dart';

/// About page: centered logo/name header, then the version row.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  /// Display version, kept in lockstep with pubspec.yaml's
  /// `version`. Without a package_info dependency the value is
  /// static, so test/about_version_test.dart parses the pubspec and fails the
  /// build check when the two drift apart after a version bump.
  static const versionText = '1.0.133 (138)';

  /// Pixel width of the bundled logo (assets/images/app_logo.webp). The logo
  /// is displayed at 80dp, so it only needs re-decoding above 4× DPI; clamping
  /// to the asset's real width keeps a high-DPI device from asking the decoder
  /// to upscale a surface the asset does not have. Keep it in sync with
  /// LOGO_SIZE in scripts/generate_app_icons.py.
  static const _logoPixelWidth = 384;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;
    final palette = HomePalette.of(context);

    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(title: const Text('关于'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        children: [
          const _AboutLogo(),
          const SizedBox(height: 12),
          const _AboutHeading(),
          const SizedBox(height: 16),
          const _AboutInfoCard(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// 版本行点按：把版本号写进剪贴板，并用 SnackBar 明示已复制。
  static void _copyVersion(BuildContext context) {
    unawaited(Clipboard.setData(const ClipboardData(text: versionText)));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制版本号')));
  }

/// 头部 logo：全幅图片，圆角与投影跟随图版的 15% 板式圆角。
class _AboutLogo extends StatelessWidget {
  const _AboutLogo();

  @override
  Widget build(BuildContext context) {
    return Center(
      // The bundled logo is full-bleed; 12 of 80 keeps the plate's 15%
      // corner radius so the image and the shadow outline agree.
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: HomePalette.accent.withValues(alpha: 0.20),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            'assets/images/app_logo.webp',
            width: 80,
            height: 80,
            // Decode at the display size rather than the whole 384²
            // surface, which would hold ~590 KB in the image cache for a
            // 80dp logo.
            cacheWidth: (80 * MediaQuery.devicePixelRatioOf(context))
                .round()
                .clamp(80, AboutPage._logoPixelWidth),
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
        ),
      ),
    );
  }
}

/// 头部应用名与一行定位副标题。
class _AboutHeading extends StatelessWidget {
  const _AboutHeading();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          '什锦铺',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '小说 / 短剧 / 漫剧 / 漫画 / 听书聚合客户端',
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.colorScheme.outline, fontSize: 13),
        ),
      ],
    );
  }
}

/// 信息卡：只有版本行（点按复制）。
class _AboutInfoCard extends StatelessWidget {
  const _AboutInfoCard();

  @override
  Widget build(BuildContext context) {
    return _AboutCard(
      children: [
        _AboutRow(
          icon: Icons.commit_outlined,
          title: '当前版本',
          trailingText: AboutPage.versionText,
          showCopyGlyph: true,
          onTap: () => AboutPage._copyVersion(context),
        ),
      ],
    );
  }
}

class _AboutCard extends StatelessWidget {
  final List<Widget> children;
  const _AboutCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      // 横向间距由页面 ListView 的 padding 统一承担，卡片自身不再带 margin，
      // 卡间节奏只靠外层 SizedBox 一套控制。
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final bool showCopyGlyph;
  final VoidCallback? onTap;

  const _AboutRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.showCopyGlyph = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;
    final tappable = onTap != null;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: theme.colorScheme.primary),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: theme.textTheme.labelMedium?.copyWith(color: outline),
            ),
      trailing: trailingText != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trailingText!,
                  style: TextStyle(fontSize: 13, color: outline),
                ),
                if (showCopyGlyph) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.content_copy, size: 15, color: outline),
                ],
              ],
            )
          : tappable
          ? Icon(Icons.arrow_forward, size: 16, color: outline)
          : null,
    );
  }
}
