import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:finzy/widgets/app_icon.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../i18n/strings.g.dart';
import '../providers/jellyfin_profile_provider.dart';
import '../providers/user_profile_provider.dart';

/// Profile avatar + menu (Switch Profile / Logout) for app bars.
/// Use in [actions] of [DesktopSliverAppBar] or [CustomAppBar] for a uniform header.
class ProfileAppBarButton extends StatelessWidget {
  const ProfileAppBarButton({
    super.key,
    this.onSwitchProfile,
    this.onLogout,
  });

  final VoidCallback? onSwitchProfile;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return Consumer2<UserProfileProvider, JellyfinProfileProvider>(
      builder: (context, userProvider, jellyfinProvider, child) {
        final showSwitch = jellyfinProvider.currentUser != null;
        Widget avatar;
        final jUser = jellyfinProvider.currentUser;
        if (jUser != null) {
          final imageUrl = jellyfinProvider.imageUrlFor(jUser);
          avatar = imageUrl.isNotEmpty
              ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const AppIcon(Symbols.account_circle_rounded, fill: 1, size: 32),
                    errorWidget: (_, __, ___) => const AppIcon(Symbols.account_circle_rounded, fill: 1, size: 32),
                  ),
                )
              : const AppIcon(Symbols.account_circle_rounded, fill: 1, size: 32);
        } else {
          avatar = const AppIcon(Symbols.account_circle_rounded, fill: 1, size: 32);
        }
        return PopupMenuButton<String>(
          icon: avatar,
          offset: const Offset(0, 8),
          onSelected: (value) {
            if (value == 'switch_profile') {
              onSwitchProfile?.call();
            } else if (value == 'logout') {
              onLogout?.call();
            }
          },
          itemBuilder: (context) => [
            if (showSwitch)
              PopupMenuItem(
                value: 'switch_profile',
                child: Row(
                  children: [
                    const AppIcon(Symbols.people_rounded, fill: 1),
                    const SizedBox(width: 8),
                    Text(t.discover.switchProfile),
                  ],
                ),
              ),
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  const AppIcon(Symbols.logout_rounded, fill: 1),
                  const SizedBox(width: 8),
                  Text(t.common.logout),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
