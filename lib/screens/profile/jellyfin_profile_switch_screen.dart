import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/jellyfin_profile_provider.dart';
import '../../utils/snackbar_helper.dart';
import '../../i18n/strings.g.dart';
import '../../theme/mono_tokens.dart';
import '../../utils/platform_detector.dart';
import '../../focus/focusable_wrapper.dart';
import 'jellyfin_add_user_screen.dart';

/// Screen to switch between stored Jellyfin users on this device.
/// Shows stored users as icon grid; "Add user" square opens add-user flow (remaining users + manual/back).
class JellyfinProfileSwitchScreen extends StatelessWidget {
  const JellyfinProfileSwitchScreen({super.key});

  static Widget _buildUserCard({
    required BuildContext context,
    required String label,
    String? subtitle,
    String? imageUrl,
    IconData? icon,
    bool isCurrent = false,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(tokens(context).radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens(context).radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        placeholder: (context, loadingProgress) => Icon(icon ?? Symbols.person_rounded, size: 48),
                        errorWidget: (context, error, stackTrace) => Icon(icon ?? Symbols.person_rounded, size: 48),
                      ),
                    )
                  else
                    Icon(icon ?? Symbols.person_rounded, size: 48),
                  if (isCurrent)
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Icon(
                        Symbols.check_circle_rounded,
                        size: 24,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t.discover.switchProfile),
      ),
      body: Consumer<JellyfinProfileProvider>(
        builder: (context, provider, _) {
          final users = provider.users;
          final baseUrl = provider.baseUrl;
          final isTV = PlatformDetector.isTV();
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: isTV ? 200 : 160,
                        childAspectRatio: 0.9,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                      ),
                      itemCount: users.length + 1,
                      itemBuilder: (context, index) {
                        if (index == users.length) {
                          final card = _buildUserCard(
                            context: context,
                            label: 'Add user',
                            icon: Symbols.person_add_rounded,
                            onTap: baseUrl.isEmpty
                                ? null
                                : () async {
                                    final added = await Navigator.push<bool>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => JellyfinAddUserScreen(
                                          baseUrl: baseUrl,
                                          existingUserIds: users.map((u) => u.userId).toSet(),
                                        ),
                                      ),
                                    );
                                    if (context.mounted && added == true) {
                                      await provider.refresh();
                                    }
                                  },
                          );
                          return isTV && baseUrl.isNotEmpty
                              ? FocusableWrapper(
                                  onSelect: () async {
                                    final added = await Navigator.push<bool>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => JellyfinAddUserScreen(
                                          baseUrl: baseUrl,
                                          existingUserIds: users.map((u) => u.userId).toSet(),
                                        ),
                                      ),
                                    );
                                    if (context.mounted && added == true) {
                                      await provider.refresh();
                                    }
                                  },
                                  child: card,
                                )
                              : card;
                        }
                        final user = users[index];
                        final isCurrent = provider.currentUser?.userId == user.userId;
                        final imageUrl = provider.imageUrlFor(user);
                        final card = _buildUserCard(
                          context: context,
                          label: user.userName,
                          imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
                          icon: Symbols.person_rounded,
                          isCurrent: isCurrent,
                          onTap: isCurrent
                              ? () => Navigator.of(context).pop()
                              : () => _switchToUser(context, provider, user),
                        );
                        return isTV
                            ? FocusableWrapper(
                                onSelect: isCurrent
                                    ? () => Navigator.of(context).pop()
                                    : () => _switchToUser(context, provider, user),
                                child: card,
                              )
                            : card;
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _switchToUser(BuildContext context, JellyfinProfileProvider provider, JellyfinProfileUser user) async {
    final success = await provider.setCurrentUser(user.userId);
    if (context.mounted) {
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        showErrorSnackBar(context, t.errors.failedToSwitchProfile(displayName: user.userName));
      }
    }
  }
}
