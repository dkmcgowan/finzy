import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/jellyfin_profile_provider.dart';
import '../../utils/snackbar_helper.dart';
import '../libraries/state_messages.dart';
import '../../i18n/strings.g.dart';
import 'jellyfin_add_user_screen.dart';

/// Screen to switch between stored Jellyfin users on this device.
/// Shows stored users; tap to switch. "Add user" opens the same UX as login (user grid → Quick Connect or Manual).
class JellyfinProfileSwitchScreen extends StatelessWidget {
  const JellyfinProfileSwitchScreen({super.key});

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
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length + 1,
            itemBuilder: (context, index) {
              if (index == users.length) {
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: const Icon(Symbols.person_add_rounded),
                    ),
                    title: const Text('Add user'),
                    subtitle: const Text('Sign in with another user on this server'),
                    trailing: const Icon(Symbols.chevron_right_rounded),
                    onTap: baseUrl.isEmpty
                        ? null
                        : () async {
                            final added = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (context) => JellyfinAddUserScreen(baseUrl: baseUrl),
                              ),
                            );
                            if (context.mounted && added == true) {
                              await provider.refresh();
                            }
                          },
                  ),
                );
              }
              final user = users[index];
              final isCurrent = provider.currentUser?.userId == user.userId;
              final imageUrl = provider.imageUrlFor(user);
              return Card(
                child: ListTile(
                  leading: imageUrl.isNotEmpty
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const Icon(Symbols.person_rounded),
                            errorWidget: (_, __, ___) => const Icon(Symbols.person_rounded),
                          ),
                        )
                      : const Icon(Symbols.person_rounded),
                  title: Text(user.userName),
                  trailing: isCurrent
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            t.userStatus.current,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : const Icon(Symbols.chevron_right_rounded),
                  onTap: isCurrent ? null : () => _switchToUser(context, provider, user),
                ),
              );
            },
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
