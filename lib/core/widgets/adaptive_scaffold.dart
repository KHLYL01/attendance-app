import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../config/app_config.dart';
import '../constant/app_colors.dart';
import '../constant/app_icons.dart';
import '../constant/app_images.dart';
import '../constant/app_text_styles.dart';
import '../responsive/breakpoints.dart';
import 'app_icon.dart';

class AdaptiveDestination {
  const AdaptiveDestination({required this.label, required this.iconAsset, this.section});

  final String label;
  final String iconAsset;
  final String? section;
}

class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    super.key,
    required this.title,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.body,
    this.subtitle,
    this.detail,
    this.floatingActionButton,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final List<AdaptiveDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget body;
  final Widget? detail;
  final Widget? floatingActionButton;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final wide = context.useWebLayout;
    final useBottomBar = !wide && destinations.length <= 4;

    if (wide) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            _Rail(destinations: destinations, selectedIndex: selectedIndex, onSelected: onSelected),
            Expanded(
              child: Column(
                children: [
                  _WorkspaceBar(title: title, subtitle: subtitle, actions: actions),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: detail == null
                          ? _Surface(child: body)
                          : Row(
                              children: [
                                Expanded(child: _Surface(child: body)),
                                const SizedBox(width: 16),
                                Expanded(child: _Surface(child: detail!)),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: floatingActionButton,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _MenuBar(title: title, subtitle: subtitle, actions: actions, showMenu: !useBottomBar),
      drawer: useBottomBar
          ? null
          : Drawer(
              backgroundColor: AppColors.ink,
              child: _Rail(
                destinations: destinations,
                selectedIndex: selectedIndex,
                onSelected: (index) {
                  Navigator.pop(context);
                  onSelected(index);
                },
                inDrawer: true,
              ),
            ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: _Surface(child: body),
      ),
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: useBottomBar
          ? _BottomBar(
              destinations: destinations,
              selectedIndex: selectedIndex,
              onSelected: onSelected,
              notched: floatingActionButton != null,
            )
          : null,
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: Color(0x140C1926), blurRadius: 24, offset: Offset(0, 8))],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(18), child: child),
    );
  }
}

class _MenuBar extends StatelessWidget implements PreferredSizeWidget {
  const _MenuBar({required this.title, required this.actions, required this.showMenu, this.subtitle});

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showMenu;

  @override
  Size get preferredSize => const Size.fromHeight(88);

  @override
  Widget build(BuildContext context) {
    return _WorkspaceBar(
      title: title,
      subtitle: subtitle,
      actions: actions,
      compact: true,
      leading: showMenu
          ? Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Tooltip(
                message: 'Menu'.tr,
                child: Material(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Scaffold.of(context).openDrawer(),
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(child: AppIcon(AppIcons.menu, size: 18)),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _WorkspaceBar extends StatelessWidget implements PreferredSizeWidget {
  const _WorkspaceBar({required this.title, required this.actions, this.subtitle, this.leading, this.compact = false});

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;
  final bool compact;

  @override
  Size get preferredSize => Size.fromHeight(compact ? 64 : 84);

  @override
  Widget build(BuildContext context) {
    final bar = Padding(
      padding: EdgeInsets.fromLTRB(compact ? 4 : 24, 8, 16, 8),
      child: Row(
        children: [
          if (leading != null) leading!,
          if (compact && leading == null) const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: compact ? AppTextStyles.title : AppTextStyles.headline),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );

    if (compact) {
      final statusTop = MediaQuery.paddingOf(context).top;
      return Material(
        color: AppColors.background,
        child: Padding(
          padding: EdgeInsets.only(top: statusTop + 10),
          child: bar,
        ),
      );
    }
    return Material(
      color: AppColors.background,
      child: SafeArea(bottom: false, child: bar),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    this.inDrawer = false,
  });

  final List<AdaptiveDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool inDrawer;

  @override
  Widget build(BuildContext context) {
    final name = 'Offline mode'.tr;

    return Container(
      width: inDrawer ? double.infinity : 268,
      color: AppColors.ink,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Row(
                children: [
                  const AppLogo(size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppConfig.appName, style: AppTextStyles.title.copyWith(color: AppColors.white)),
                        Text(
                          AppConfig.appSubtitle,
                          style: AppTextStyles.caption.copyWith(color: AppColors.accentOnInk, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (var i = 0; i < destinations.length; i++) ...[
                    if (_showSection(i))
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
                        child: Text(
                          destinations[i].section!.tr,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.inkMuted,
                            fontSize: 11,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    _RailItem(destination: destinations[i], selected: selectedIndex == i, onTap: () => onSelected(i)),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.accent,
                        child: AppIcon(AppIcons.offline, size: 16, color: AppColors.white),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name,
                          style: AppTextStyles.body.copyWith(color: AppColors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _showSection(int index) {
    final section = destinations[index].section;
    if (section == null) return false;
    if (index == 0) return true;
    return destinations[index - 1].section != section;
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({required this.destination, required this.selected, required this.onTap});

  final AdaptiveDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.white : AppColors.inkMuted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 10),
                AppIcon(destination.iconAsset, size: 20, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(destination.label, style: AppTextStyles.body.copyWith(color: color, fontSize: 14)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.notched,
  });

  final List<AdaptiveDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool notched;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: AppColors.white,
      shape: notched ? const CircularNotchedRectangle() : null,
      notchMargin: 8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < destinations.length; i++) ...[
            if (notched && i == destinations.length ~/ 2) const SizedBox(width: 48),
            Expanded(
              child: _NavButton(destination: destinations[i], selected: selectedIndex == i, onTap: () => onSelected(i)),
            ),
          ],
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.destination, required this.selected, required this.onTap});

  final AdaptiveDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(destination.iconAsset, size: 20, color: color),
            const SizedBox(height: 2),
            Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(color: color, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

/// The institute's logo in a white circle.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: AppColors.white, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(AppImages.logo, fit: BoxFit.cover),
    );
  }
}
