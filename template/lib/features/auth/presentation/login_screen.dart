import 'package:fluframe_app/core/logging/app_logger.dart';
import 'package:fluframe_app/features/auth/domain/auth_exception.dart';
import 'package:fluframe_app/features/auth/presentation/auth_controller.dart';
import 'package:fluframe_app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Email/password sign-in form.
///
/// Navigation away from this screen is handled entirely by the router's
/// redirect (see `app_router.dart`): once the sign-in succeeds the auth
/// state changes and the redirect leaves `/login` for the `?from=` target.
class LoginScreen extends ConsumerStatefulWidget {
  /// Creates the login screen.
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  var _submitting = false;
  String? _errorMessage;

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    // The disabled button is not the only entry point — the password
    // field submits on Enter too, and holding it down fired a second
    // sign-in over the first.
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
    } on AuthException {
      if (mounted) setState(() => _errorMessage = l10n.loginFailedMessage);
    } on Object catch (error, stackTrace) {
      // Only AuthException used to be caught, so everything a real backend
      // can raise — a socket error, a misconfigured SDK, a null
      // dereference — escaped into the zone: the form stopped at "nothing
      // happened", with no message and no way forward. Anything unexpected
      // still reaches the log so the underlying bug stays findable; the
      // user gets the generic message rather than credential advice that
      // would be wrong here.
      ref.read(appLoggerProvider).error('Sign-in failed', error, stackTrace);
      if (mounted) setState(() => _errorMessage = l10n.genericErrorMessage);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.loginTitle)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(labelText: l10n.emailLabel),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty) return l10n.emailRequired;
                      if (!_emailPattern.hasMatch(email)) {
                        return l10n.emailInvalid;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(labelText: l10n.passwordLabel),
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    validator: (value) => (value == null || value.isEmpty)
                        ? l10n.passwordRequired
                        : null,
                    onFieldSubmitted: (_) async {
                      await _submit();
                    },
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    // Both entry points await _submit inside the callback
                    // instead of handing it over as a tear-off, so the
                    // progress state and the error handling inside it run
                    // as one sequence rather than as a dropped Future.
                    onPressed: _submitting
                        ? null
                        : () async {
                            await _submit();
                          },
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.signInButton),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
