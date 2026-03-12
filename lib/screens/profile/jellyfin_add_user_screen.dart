import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../focus/dpad_navigator.dart';
import 'package:provider/provider.dart';

import '../../models/jellyfin_public_user.dart';
import '../../models/registered_server.dart';
import '../../providers/libraries_provider.dart';
import '../../providers/multi_server_provider.dart';
import '../../services/jellyfin_auth_service.dart';
import '../../services/offline_watch_sync_service.dart';
import '../../services/server_connection_orchestrator.dart';
import '../../utils/app_logger.dart';
import '../../utils/auth_button_style.dart';
import '../../services/server_registry.dart';
import '../../services/storage_service.dart';
import '../../theme/mono_tokens.dart';
import '../../utils/platform_detector.dart';
import '../../focus/focusable_wrapper.dart';
import '../../i18n/strings.g.dart';

/// Screen to add another Jellyfin user on the same server (from Switch profile).
/// Shows only users not already logged in; layout like auth user step (centered grid, Manual login + Back).
class JellyfinAddUserScreen extends StatefulWidget {
  const JellyfinAddUserScreen({
    super.key,
    required this.baseUrl,
    this.existingUserIds = const {},
  });

  final String baseUrl;
  /// User IDs already authorized on this server; they are excluded from the grid.
  final Set<String> existingUserIds;

  @override
  State<JellyfinAddUserScreen> createState() => _JellyfinAddUserScreenState();
}

class _JellyfinAddUserScreenState extends State<JellyfinAddUserScreen> {
  List<JellyfinPublicUser>? _publicUsers;
  String _step = 'users'; // users | manual | quick_connect
  JellyfinPublicUser? _selectedUser;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  String? _quickConnectCode;
  String? _quickConnectSecret;
  Timer? _quickConnectPollTimer;
  String? _errorMessage;
  bool _isAuthenticating = false;
  bool _loadingUsers = true;

  String get _baseUrl => widget.baseUrl;

  @override
  void initState() {
    super.initState();
    _loadPublicUsers();
  }

  @override
  void dispose() {
    _quickConnectPollTimer?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadPublicUsers() async {
    setState(() {
      _loadingUsers = true;
      _errorMessage = null;
    });
    try {
      final all = await JellyfinAuthService.getPublicUsers(_baseUrl);
      if (mounted) {
        final filtered = widget.existingUserIds.isEmpty
            ? all
            : all.where((u) => !widget.existingUserIds.contains(u.id)).toList();
        setState(() {
          _publicUsers = filtered;
          _loadingUsers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _publicUsers = [];
          _loadingUsers = false;
          _errorMessage = 'Failed to load users';
        });
      }
    }
  }

  Future<void> _completeAddUser({
    required JellyfinAuthResult result,
    required String userName,
    String? primaryImageTag,
  }) async {
    String serverName = result.serverName ?? 'Jellyfin';
    final storage = await StorageService.getInstance();
    final deviceId = await storage.getOrCreateDeviceId();
    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: _baseUrl,
          headers: {
            'Authorization': JellyfinAuthService.authHeaderWithToken(result.accessToken, deviceId: deviceId),
          },
        ),
      );
      final info = await dio.get<Map<String, dynamic>>('/System/Info');
      final data = info.data;
      if (data != null) {
        serverName = data['ServerName'] as String? ?? serverName;
      }
    } catch (e) {
      appLogger.w('Failed to fetch server info after login', error: e);
    }

    final storedUser = JellyfinStoredUser(
      userId: result.userId,
      accessToken: result.accessToken,
      userName: userName,
      primaryImageTag: primaryImageTag,
    );

    final registry = ServerRegistry(storage);
    final added = await registry.addOrUpdateJellyfinUserAndSetCurrent(storedUser);
    if (!added || !mounted) return;

    final allServers = await registry.getServers();
    if (!mounted) return;
    final connResult = await ServerConnectionOrchestrator.connectAndInitialize(
      servers: allServers,
      multiServerProvider: context.read<MultiServerProvider>(),
      librariesProvider: context.read<LibrariesProvider>(),
      syncService: context.read<OfflineWatchSyncService>(),
      clientIdentifier: storage.getClientIdentifier(),
      deviceId: deviceId,
    );
    if (!connResult.hasConnections || !mounted) return;

    Navigator.of(context).pop(true);
  }

  void _goToManual([JellyfinPublicUser? user]) {
    setState(() {
      _selectedUser = user;
      _step = 'manual';
      if (user != null) {
        _usernameController.text = user.name;
      } else {
        _usernameController.clear();
      }
      _passwordController.clear();
      _errorMessage = null;
    });
  }

  void _backToUsers() {
    setState(() {
      _step = 'users';
      _selectedUser = null;
      _errorMessage = null;
    });
  }

  Future<void> _signInManual() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty) {
      setState(() => _errorMessage = 'Please enter username');
      return;
    }
    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });
    try {
      final result = await JellyfinAuthService.authenticateByName(
        baseUrl: _baseUrl,
        username: username,
        password: password,
      );
      final userName = _selectedUser?.name ?? username;
      final primaryImageTag = _selectedUser?.primaryImageTag;
      await _completeAddUser(
        result: result,
        userName: userName,
        primaryImageTag: primaryImageTag,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
          _errorMessage = t.errors.authenticationFailed(error: e);
        });
      }
    }
  }

  Future<void> _startQuickConnect([JellyfinPublicUser? user]) async {
    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
      _selectedUser = user;
    });
    try {
      final state = await JellyfinAuthService.quickConnectInitiate(_baseUrl);
      if (!mounted) return;
      setState(() {
        _quickConnectCode = state.code;
        _quickConnectSecret = state.secret;
        _step = 'quick_connect';
        _isAuthenticating = false;
      });
      _startPolling();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
          _errorMessage = 'Quick Connect failed. It may be disabled on the server.';
        });
      }
    }
  }

  void _startPolling() {
    _quickConnectPollTimer?.cancel();
    final secret = _quickConnectSecret!;
    void checkOnce() async {
      try {
        final state = await JellyfinAuthService.quickConnectGetState(_baseUrl, secret);
        if (!mounted) return;
        if (state.authenticated) {
          _quickConnectPollTimer?.cancel();
          final result = await JellyfinAuthService.authenticateWithQuickConnect(_baseUrl, secret);
          if (!mounted) return;
          final userName = _selectedUser?.name ?? result.userId;
          final primaryImageTag = _selectedUser?.primaryImageTag;
          await _completeAddUser(
            result: result,
            userName: userName,
            primaryImageTag: primaryImageTag,
          );
        }
      } catch (e) {
        appLogger.d('Quick Connect poll check failed', error: e);
      }
    }
    checkOnce();
    _quickConnectPollTimer = Timer.periodic(const Duration(seconds: 3), (_) => checkOnce());
  }

  void _cancelQuickConnect() {
    _quickConnectPollTimer?.cancel();
    setState(() {
      _step = 'users';
      _quickConnectCode = null;
      _quickConnectSecret = null;
    });
  }

  void _showUserOptions(JellyfinPublicUser user) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Symbols.link_rounded),
              title: const Text('Quick Connect'),
              subtitle: const Text('Pair with your phone or another device'),
              onTap: () {
                Navigator.pop(ctx);
                _startQuickConnect(user);
              },
            ),
            ListTile(
              leading: const Icon(Symbols.lock_rounded),
              title: const Text('Manual login'),
              subtitle: Text('Password for ${user.name}'),
              onTap: () {
                Navigator.pop(ctx);
                _goToManual(user);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard({
    required String label,
    String? subtitle,
    String? imageUrl,
    IconData? icon,
    required VoidCallback onTap,
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
    if (_step == 'quick_connect') {
      return Scaffold(
        appBar: AppBar(title: const Text('Add user')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enter this code on your server or another device',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(tokens(context).radiusMd),
                  ),
                  child: Text(
                    _quickConnectCode ?? '',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          letterSpacing: 8,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _cancelQuickConnect,
                  style: authPillButtonStyle(context, primary: false),
                  child: Text(t.common.cancel),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_step == 'manual') {
      final isTV = PlatformDetector.isTV();
      final theme = Theme.of(context);
      final inputDecoration = isTV
          ? InputDecoration(
              border: const OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.5), width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: theme.colorScheme.primary, width: 4),
              ),
            )
          : const InputDecoration(border: OutlineInputBorder());
      return Scaffold(
        appBar: AppBar(title: const Text('Add user')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_selectedUser != null)
                Text(
                  'Sign in as ${_selectedUser!.name}',
                  style: Theme.of(context).textTheme.titleSmall,
                )
              else
                Text(
                  'Manual login',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              const SizedBox(height: 16),
              Focus(
                onKeyEvent: (node, event) {
                  if (!event.isActionable) return KeyEventResult.ignored;
                  if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                    node.focusInDirection(TraversalDirection.down);
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: TextFormField(
                  focusNode: _usernameFocusNode,
                  autofocus: _selectedUser == null,
                  controller: _usernameController,
                  decoration: inputDecoration.copyWith(labelText: t.auth.jellyfinUsername),
                  cursorColor: isTV ? theme.colorScheme.primary : null,
                  cursorWidth: isTV ? 3 : 2.0,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                ),
              ),
              const SizedBox(height: 16),
              Focus(
                onKeyEvent: (node, event) {
                  if (!event.isActionable) return KeyEventResult.ignored;
                  if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                    node.focusInDirection(TraversalDirection.down);
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    _usernameFocusNode.requestFocus();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: TextFormField(
                  focusNode: _passwordFocusNode,
                  autofocus: _selectedUser != null,
                  controller: _passwordController,
                  decoration: inputDecoration.copyWith(labelText: t.auth.jellyfinPassword),
                  cursorColor: isTV ? theme.colorScheme.primary : null,
                  cursorWidth: isTV ? 3 : 2.0,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) {
                    final user = _usernameController.text.trim();
                    final pass = _passwordController.text;
                    if (user.isEmpty) {
                      _usernameFocusNode.requestFocus();
                      return;
                    }
                    if (pass.isEmpty) {
                      _passwordFocusNode.requestFocus();
                      return;
                    }
                    _signInManual();
                  },
                ),
              ),
              const SizedBox(height: 24),
              isTV
                  ? Focus(
                      onKeyEvent: (node, event) {
                        if (!event.isActionable) return KeyEventResult.ignored;
                        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                          _passwordFocusNode.requestFocus();
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: ElevatedButton(
                        onPressed: _isAuthenticating ? null : _signInManual,
                        style: authPillButtonStyle(context),
                        child: _isAuthenticating
                            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(t.auth.jellyfinSignIn),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: _isAuthenticating ? null : _signInManual,
                      style: authPillButtonStyle(context),
                      child: _isAuthenticating
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(t.auth.jellyfinSignIn),
                    ),
              const SizedBox(height: 12),
              isTV
                  ? Focus(
                      onKeyEvent: (node, event) {
                        if (!event.isActionable) return KeyEventResult.ignored;
                        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                          FocusManager.instance.primaryFocus?.focusInDirection(TraversalDirection.up);
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: ElevatedButton(
                        onPressed: _backToUsers,
                        style: authPillButtonStyle(context, primary: false),
                        child: Text(t.common.back),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: _backToUsers,
                      style: authPillButtonStyle(context, primary: false),
                      child: Text(t.common.back),
                    ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      );
    }

    // users step: remaining users only, centered grid, no scroll; Manual login + Back below
    final users = _publicUsers ?? [];
    final isTV = PlatformDetector.isTV();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add user'),
      ),
      body: _loadingUsers
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Select a user or sign in manually',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: isTV ? 200 : 160,
                          childAspectRatio: 0.9,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                        ),
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          final imageUrl = user.primaryImageTag != null ? user.imageUrl(_baseUrl) : null;
                          final card = _buildUserCard(
                            label: user.name,
                            imageUrl: imageUrl,
                            onTap: () => _showUserOptions(user),
                          );
                          return isTV
                              ? FocusableWrapper(
                                  autofocus: index == 0,
                                  onSelect: () => _showUserOptions(user),
                                  child: card,
                                )
                              : card;
                        },
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => _goToManual(null),
                        style: authPillButtonStyle(context),
                        child: const Text('Manual login'),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
