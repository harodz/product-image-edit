import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../l10n/app_localizations.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_shell.dart';
import '../widgets/common_widgets.dart';

class ApiSettingsScreen extends StatefulWidget {
  const ApiSettingsScreen({super.key});

  @override
  State<ApiSettingsScreen> createState() => _ApiSettingsScreenState();
}

class _ApiSettingsScreenState extends State<ApiSettingsScreen> {
  final FocusNode _keyFocus = FocusNode();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _keyFocus.addListener(_onKeyFocusChange);
  }

  void _onKeyFocusChange() {
    if (!_keyFocus.hasFocus) {
      final app = AppStateScope.of(context);
      unawaited(app.flushApiKeyToDisk());
    }
  }

  @override
  void dispose() {
    _keyFocus.removeListener(_onKeyFocusChange);
    _keyFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final l10n = AppLocalizations.of(context)!;
    return AppShell(
      title: l10n.screenApiAccount,
      child: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          return SingleChildScrollView(
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.geminiApiKeyTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppTokens.spacingSm),
                  Text(
                    l10n.geminiApiKeyDescription,
                    style: TextStyle(
                      color: AppTokens.onBackground.withValues(alpha: 0.72),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: AppTokens.spacingMd),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: appState.apiKeyController,
                          focusNode: _keyFocus,
                          obscureText: _obscure,
                          autocorrect: false,
                          enableSuggestions: false,
                          keyboardType: TextInputType.visiblePassword,
                          autofillHints: const [],
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: l10n.apiKeyHint,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: _obscure ? l10n.showKey : l10n.hideKey,
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTokens.spacingSm),
                  if (appState.apiKeyLastPersistedAt != null)
                    Text(
                      l10n.lastSavedAt(_formatTime(appState.apiKeyLastPersistedAt!)),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTokens.success.withValues(alpha: 0.9),
                      ),
                    ),
                  const SizedBox(height: AppTokens.spacingMd),
                  Wrap(
                    spacing: AppTokens.spacingSm,
                    runSpacing: AppTokens.spacingSm,
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          final err = await appState.saveApiKeyToAppSupport();
                          if (!context.mounted) {
                            return;
                          }
                          if (err == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.apiKeySaved)),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  err,
                                  style: TextStyle(color: Theme.of(context).colorScheme.onError),
                                ),
                                backgroundColor: Theme.of(context).colorScheme.error,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTokens.primaryContainer,
                          foregroundColor: AppTokens.onBackground,
                        ),
                        child: Text(l10n.saveNow),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTokens.spacingLg),
                  const Divider(),
                  const SizedBox(height: AppTokens.spacingSm),
                  Text(
                    l10n.storagePath,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    '${appState.applicationSupportPath}/.env',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

String _formatTime(DateTime t) {
  final l = t.toLocal();
  return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')} '
      '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}
