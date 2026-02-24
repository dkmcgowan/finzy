import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import '../models/jellyfin_public_user.dart';
import '../models/registered_server.dart';
import '../services/jellyfin_auth_service.dart';
import '../services/server_connection_orchestrator.dart';
import '../services/server_registry.dart';
import '../services/storage_service.dart';
import '../providers/multi_server_provider.dart';
import '../providers/libraries_provider.dart';
import '../services/offline_watch_sync_service.dart';
import '../i18n/strings.g.dart';
import '../theme/mono_tokens.dart';
import '../utils/app_logger.dart';
import '../utils/platform_detector.dart';
import 'main_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isAuthenticating = false;
  String? _errorMessage;

  /// Jellyfin multi-step: server URL -> user picker -> manual or quick connect
  String _jellyfinStep = 'server'; // server | users | manual | quick_connect
  String? _jellyfinBaseUrl;
  List<JellyfinPublicUser>? _jellyfinPublicUsers;
  JellyfinPublicUser? _jellyfinSelectedUser; // for prefilled manual
  String? _quickConnectCode;
  String? _quickConnectSecret;
  Timer? _quickConnectPollTimer;

  final _jellyfinUrlController = TextEditingController();
  final _jellyfinUsernameController = TextEditingController();
  final _jellyfinPasswordController = TextEditingController();

  @override
  void dispose() {
    _quickConnectPollTimer?.cancel();
    _jellyfinUrlController.dispose();
    _jellyfinUsernameController.dispose();
    _jellyfinPasswordController.dispose();
    super.dispose();
  }

  /// Normalize Jellyfin base URL (ensure scheme, no trailing slash)
  static String _normalizeJellyfinBaseUrl(String input) {
    var url = input.trim();
    if (url.isEmpty) return url;
    if (!url.startsWith(RegExp(r'https?://'))) url = 'https://$url';
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    return url;
  }

  Future<void> _signInWithJellyfin() async {
    final baseUrl = _jellyfinBaseUrl ?? _normalizeJellyfinBaseUrl(_jellyfinUrlController.text);
    final username = _jellyfinUsernameController.text.trim();
    final password = _jellyfinPasswordController.text;

    if (baseUrl.isEmpty) {
      setState(() => _errorMessage = 'Please enter server URL');
      return;
    }
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
        baseUrl: baseUrl,
        username: username,
        password: password,
      );
      final userName = _jellyfinSelectedUser?.name ?? username;
      final primaryImageTag = _jellyfinSelectedUser?.primaryImageTag;
      await _completeJellyfinAuth(baseUrl: baseUrl, result: result, userName: userName, primaryImageTag: primaryImageTag);
    } catch (e) {
      appLogger.e('Jellyfin sign-in failed', error: e);
      if (!mounted) return;
      setState(() {
        _isAuthenticating = false;
        _errorMessage = t.errors.authenticationFailed(error: e);
      });
    }
  }

  /// After any successful Jellyfin auth (password or Quick Connect): resolve server info, save user, connect, navigate.
  Future<void> _completeJellyfinAuth({
    required String baseUrl,
    required JellyfinAuthResult result,
    required String userName,
    String? primaryImageTag,
  }) async {
    String serverId = result.serverId ?? baseUrl.hashCode.abs().toString();
    String serverName = result.serverName ?? 'Jellyfin';
    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          headers: {
            'Authorization': 'MediaBrowser Client="Finzy", Device="Finzy", DeviceId="finzy-jellyfin", Version="1.0.0", Token="${result.accessToken}"',
          },
        ),
      );
      final info = await dio.get<Map<String, dynamic>>('/System/Info');
      final data = info.data;
      if (data != null) {
        serverName = data['ServerName'] as String? ?? serverName;
        final id = data['Id'] as String?;
        if (id != null && id.isNotEmpty) serverId = id;
      }
    } catch (_) {
      // Use defaults if System/Info fails
    }

    final storedUser = JellyfinStoredUser(
      userId: result.userId,
      accessToken: result.accessToken,
      userName: userName,
      primaryImageTag: primaryImageTag,
    );

    final storage = await StorageService.getInstance();
    final registry = ServerRegistry(storage);
    final servers = await registry.getServers();
    final existing = servers.toList();

    if (existing.isNotEmpty && existing.first.jellyfinData.serverId == serverId) {
      await registry.addOrUpdateJellyfinUserAndSetCurrent(storedUser);
    } else {
      final jellyfinData = JellyfinServerData(
        baseUrl: baseUrl,
        serverId: serverId,
        serverName: serverName,
        users: [storedUser],
        currentUserId: result.userId,
      );
      await registry.addOrReplaceJellyfinServer(jellyfinData);
    }
    final allServers = await registry.getServers();

    if (!mounted) return;
    final connResult = await ServerConnectionOrchestrator.connectAndInitialize(
      servers: allServers,
      multiServerProvider: context.read<MultiServerProvider>(),
      librariesProvider: context.read<LibrariesProvider>(),
      syncService: context.read<OfflineWatchSyncService>(),
      clientIdentifier: storage.getClientIdentifier(),
    );

    if (!mounted) return;
    if (!connResult.hasConnections) {
      setState(() {
        _isAuthenticating = false;
        _errorMessage = t.serverSelection.allServerConnectionsFailed;
      });
      return;
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => MainScreen(client: connResult.firstClient!)),
    );
  }

  /// Step 1: Connect to server and load public users.
  Future<void> _jellyfinConnectToServer() async {
    final baseUrl = _normalizeJellyfinBaseUrl(_jellyfinUrlController.text);
    if (baseUrl.isEmpty) {
      setState(() => _errorMessage = 'Please enter server URL');
      return;
    }
    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });
    try {
      final ok = await JellyfinAuthService.testConnection(baseUrl);
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _isAuthenticating = false;
          _errorMessage = 'Could not connect to server. Check the URL.';
        });
        return;
      }
      final users = await JellyfinAuthService.getPublicUsers(baseUrl);
      if (!mounted) return;
      setState(() {
        _jellyfinBaseUrl = baseUrl;
        _jellyfinPublicUsers = users;
        _jellyfinStep = 'users';
        _isAuthenticating = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAuthenticating = false;
        _errorMessage = t.errors.authenticationFailed(error: e);
      });
    }
  }

  /// Start Quick Connect for the given user (or no user).
  Future<void> _jellyfinStartQuickConnect([JellyfinPublicUser? user]) async {
    final baseUrl = _jellyfinBaseUrl!;
    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
      _jellyfinSelectedUser = user;
    });
    try {
      final state = await JellyfinAuthService.quickConnectInitiate(baseUrl);
      if (!mounted) return;
      setState(() {
        _quickConnectCode = state.code;
        _quickConnectSecret = state.secret;
        _jellyfinStep = 'quick_connect';
        _isAuthenticating = false;
      });
      _startQuickConnectPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAuthenticating = false;
        _errorMessage = 'Quick Connect failed. It may be disabled on the server.';
      });
    }
  }

  void _startQuickConnectPolling() {
    _quickConnectPollTimer?.cancel();
    final baseUrl = _jellyfinBaseUrl!;
    final secret = _quickConnectSecret!;
    void checkOnce() async {
      try {
        final state = await JellyfinAuthService.quickConnectGetState(baseUrl, secret);
        if (!mounted) return;
        if (state.authenticated) {
          _quickConnectPollTimer?.cancel();
          final result = await JellyfinAuthService.authenticateWithQuickConnect(baseUrl, secret);
          if (!mounted) return;
          final userName = _jellyfinSelectedUser?.name ?? result.userId;
          final primaryImageTag = _jellyfinSelectedUser?.primaryImageTag;
          await _completeJellyfinAuth(
            baseUrl: baseUrl,
            result: result,
            userName: userName,
            primaryImageTag: primaryImageTag,
          );
        }
      } catch (_) {
        // Ignore poll/network errors; auth exchange failures will leave user on screen
      }
    }
    checkOnce(); // poll immediately so we don't wait 3s after user approves
    _quickConnectPollTimer = Timer.periodic(const Duration(seconds: 3), (_) => checkOnce());
  }

  void _jellyfinCancelQuickConnect() {
    _quickConnectPollTimer?.cancel();
    setState(() {
      _jellyfinStep = 'users';
      _quickConnectCode = null;
      _quickConnectSecret = null;
    });
  }

  void _jellyfinGoToManual([JellyfinPublicUser? user]) {
    setState(() {
      _jellyfinSelectedUser = user;
      _jellyfinStep = 'manual';
      if (user != null) {
        _jellyfinUsernameController.text = user.name;
      } else {
        _jellyfinUsernameController.clear();
      }
      _jellyfinPasswordController.clear();
      _errorMessage = null;
    });
  }

  void _jellyfinBackToUsers() {
    setState(() {
      _jellyfinStep = 'users';
      _jellyfinSelectedUser = null;
      _errorMessage = null;
    });
  }

  void _jellyfinBackToServer() {
    setState(() {
      _jellyfinStep = 'server';
      _jellyfinBaseUrl = null;
      _jellyfinPublicUsers = null;
      _jellyfinSelectedUser = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use two-column layout on desktop, single column on mobile
    final isDesktop = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: isDesktop ? 800 : 400),
          padding: const EdgeInsets.all(24),
          child: isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // First column - Logo and title (always visible)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Image.asset('assets/finzy.png', width: 120, height: 120),
                          const SizedBox(height: 24),
                          Text(
                            t.app.title,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48),
                    // Second column - All authentication content
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_isAuthenticating)
                                const Center(child: CircularProgressIndicator())
                              else
                                _buildAuthContent(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset('assets/finzy.png', width: 120, height: 120),
                      const SizedBox(height: 24),
                      Text(
                        t.app.title,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),
                      if (_isAuthenticating)
                        const Center(child: CircularProgressIndicator())
                      else
                        _buildAuthContent(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  /// Builds the Jellyfin sign-in form and any error message
  Widget _buildAuthContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildJellyfinForm(),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildJellyfinForm() {
    if (_jellyfinStep == 'quick_connect') {
      return _buildJellyfinQuickConnectStep();
    }
    if (_jellyfinStep == 'manual') {
      return _buildJellyfinManualStep();
    }
    if (_jellyfinStep == 'users') {
      return _buildJellyfinUsersStep();
    }
    // server
    return _buildJellyfinServerStep();
  }

  Widget _buildJellyfinServerStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _jellyfinUrlController,
          decoration: InputDecoration(
            labelText: t.auth.jellyfinServerUrl,
            hintText: t.auth.jellyfinServerUrlHint,
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _jellyfinConnectToServer(),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isAuthenticating ? null : _jellyfinConnectToServer,
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          child: _isAuthenticating
              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Connect'),
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
    );
  }

  Widget _buildJellyfinUsersStep() {
    final users = _jellyfinPublicUsers ?? [];
    final isTV = PlatformDetector.isTV();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Select a user',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        // Users as clickable squares in a grid (no fixed-height box; grid scrolls with page)
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: isTV ? 140 : 120,
            childAspectRatio: 0.85,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final imageUrl = user.primaryImageTag != null ? user.imageUrl(_jellyfinBaseUrl!) : null;
            return _buildJellyfinUserCard(
              label: user.name,
              imageUrl: imageUrl,
              onTap: () => _showJellyfinUserOptions(user),
            );
          },
        ),
        const SizedBox(height: 24),
        // Two buttons same style as Connect on server step
        ElevatedButton(
          onPressed: () => _jellyfinGoToManual(null),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          child: const Text('Manual login'),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _jellyfinBackToServer,
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          child: const Text('Change server'),
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
    );
  }

  Widget _buildJellyfinUserCard({
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
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (imageUrl != null && imageUrl.isNotEmpty)
                ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Icon(icon ?? Symbols.person_rounded, size: 40),
                    errorWidget: (_, __, ___) => Icon(icon ?? Symbols.person_rounded, size: 40),
                  ),
                )
              else
                Icon(icon ?? Symbols.person_rounded, size: 40),
              const SizedBox(height: 6),
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

  void _showJellyfinUserOptions(JellyfinPublicUser user) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Symbols.link_rounded),
              title: const Text('Quick Connect'),
              subtitle: const Text('Pair with your phone or another device'),
              onTap: () {
                Navigator.pop(context);
                _jellyfinStartQuickConnect(user);
              },
            ),
            ListTile(
              leading: const Icon(Symbols.lock_rounded),
              title: const Text('Manual login'),
              subtitle: Text('Password for ${user.name}'),
              onTap: () {
                Navigator.pop(context);
                _jellyfinGoToManual(user);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJellyfinManualStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_jellyfinSelectedUser != null)
          Text(
            'Sign in as ${_jellyfinSelectedUser!.name}',
            style: Theme.of(context).textTheme.titleSmall,
          )
        else
          Text(
            'Manual login',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _jellyfinUsernameController,
          decoration: InputDecoration(
            labelText: t.auth.jellyfinUsername,
            border: const OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _jellyfinPasswordController,
          decoration: InputDecoration(
            labelText: t.auth.jellyfinPassword,
            border: const OutlineInputBorder(),
          ),
          obscureText: true,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _signInWithJellyfin(),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isAuthenticating ? null : _signInWithJellyfin,
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          child: _isAuthenticating
              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(t.auth.jellyfinSignIn),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _jellyfinBackToUsers,
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
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
    );
  }

  Widget _buildJellyfinQuickConnectStep() {
    return Column(
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
        Text(
          'Settings → Quick Connect on your server or app',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: _jellyfinCancelQuickConnect,
          child: Text(t.common.cancel),
        ),
      ],
    );
  }

}
