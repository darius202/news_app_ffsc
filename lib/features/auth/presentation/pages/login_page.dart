import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/auth_cubit.dart';
import '../widgets/auth_form_scaffold.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    context.read<AuthCubit>().login(_email.text, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    return AuthFormScaffold(
      title: 'Connexion',
      subtitle: "Accédez à l'actualité du monde entier",
      formKey: _formKey,
      submitLabel: 'Se connecter',
      onSubmit: _submit,
      fields: [
        TextFormField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'E-mail',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          validator: validateEmail,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _password,
          obscureText: _obscure,
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: 'Mot de passe',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          validator: (v) =>
              (v == null || v.isEmpty) ? 'Mot de passe requis' : null,
        ),
      ],
      footer: TextButton(
        onPressed: () {
          context.read<AuthCubit>().clearError();
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const RegisterPage()),
          );
        },
        child: const Text('Pas encore de compte ? Créer un compte'),
      ),
    );
  }
}
