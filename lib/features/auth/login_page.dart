import 'package:eme_app_systemmanager/core/ph.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand.dart';
import 'auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  late final _server = TextEditingController(
    text: ref.read(settingsProvider).serverUrl,
  );
  var _busy = false;
  var _showServer = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _server.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    ref.read(settingsProvider.notifier).setServerUrl(_server.text);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() => _run(() async {
    if (!_email.text.contains('@')) throw 'Enter your email address';
    final res = await ref
        .read(authProvider.notifier)
        .sendUserCode(email: _email.text);
    if (res.isNoUser) throw 'No account found for ${_email.text.trim()}';
    if (!res.isSuccess) throw res.errorMessage ?? 'Could not send the code';
  });

  Future<void> _verify() => _run(() async {
    if (_code.text.trim().length < 4) throw 'Enter the code from your email';
    final res = await ref
        .read(authProvider.notifier)
        .loginWithCode(email: _email.text, code: _code.text);
    if (!res.isSuccess) throw res.errorMessage ?? 'Invalid code';
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final codeStep = ref.watch(
      authProvider.select(
        (a) => a.isCodeSent || (a.isLoading && a.email != null),
      ),
    );
    return Scaffold(
      backgroundColor: c.shell,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: BrandMark(size: 44)),
                const SizedBox(height: 28),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            codeStep ? 'Check your email' : 'Sign in',
                            style: context.text.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            codeStep
                                ? 'Enter the code we sent to ${_email.text.trim()}.'
                                : 'We will email you a 6 digit sign-in code.',
                            style: TextStyle(color: c.muted),
                          ),
                          const SizedBox(height: 20),
                          ..._fields(codeStep),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              style: TextStyle(color: context.scheme.error),
                            ),
                          ],
                          const SizedBox(height: 18),
                          FilledButton(
                            onPressed: _busy
                                ? null
                                : codeStep
                                ? _verify
                                : _sendCode,
                            child: _busy
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(codeStep ? 'Sign in' : 'Send code'),
                          ),
                          const SizedBox(height: 8),
                          if (codeStep)
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : ref.read(authProvider.notifier).resetFlow,
                              child: const Text('Back'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => setState(() => _showServer = !_showServer),
                  icon: const Icon(Ph.hardDrives, size: 14),
                  label: Text(
                    _showServer
                        ? 'Hide server'
                        : 'Server: ${ref.watch(settingsProvider).serverUrl}',
                  ),
                  style: TextButton.styleFrom(foregroundColor: c.muted),
                ),
                if (_showServer)
                  TextField(
                    controller: _server,
                    decoration: const InputDecoration(
                      labelText: 'Server address',
                      hintText: defaultServerUrl,
                    ),
                    onSubmitted: (v) =>
                        ref.read(settingsProvider.notifier).setServerUrl(v),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _fields(bool codeStep) => !codeStep
      ? [
          TextField(
            controller: _email,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Ph.envelopeSimple, size: 16),
            ),
            onSubmitted: (_) => _sendCode(),
          ),
        ]
      : [
          TextField(
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            style: const TextStyle(
              fontSize: 22,
              letterSpacing: 8,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(hintText: '••••••'),
            onSubmitted: (_) => _verify(),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy ? null : _sendCode,
              child: const Text('Send a new code'),
            ),
          ),
        ];
}
