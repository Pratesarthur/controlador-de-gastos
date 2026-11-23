import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'accounts_screen.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

/// Configurações: profile, appearance, accounts/cards, security and sign-out.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Store.i,
    builder: (context, _) {
      final s = Store.i;
      final p = s.profile;
      return ScreenList(
        title: 'Configurações',
        subtitle: 'Perfil, aparência e segurança',
        children: [
          Reveal(
            index: 1,
            child: Pressable(
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const EditProfileScreen())),
              child: SoftCard(
                child: Row(
                  children: [
                    ProfileAvatar(size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: T.body.copyWith(fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(p.email.isEmpty ? 'Adicione seu e-mail' : p.email, style: T.small, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: C.faint),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _Section('Aparência'),
          Reveal(
            index: 2,
            child: SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(C.dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined, size: 18, color: C.ink),
                      const SizedBox(width: 10),
                      Text('Tema', style: T.body),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SegmentedPill(
                    labels: const ['Claro', 'Escuro'],
                    index: C.dark ? 1 : 0,
                    onChanged: (i) {
                      HapticFeedback.selectionClick();
                      setDarkMode(i == 1);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          _Section('Dinheiro'),
          Reveal(
            index: 3,
            child: SoftCard(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _NavRow(
                    Icons.account_balance_outlined,
                    'Minhas contas',
                    '${s.accounts.length} ${s.accounts.length == 1 ? 'conta' : 'contas'} · onde fica seu dinheiro',
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const AccountsScreen(mode: AccountsMode.accounts)),
                    ),
                  ),
                  Divider(height: 1, color: C.track),
                  _NavRow(
                    Icons.credit_card_rounded,
                    'Meus cartões',
                    '${s.cards.length} ${s.cards.length == 1 ? 'cartão' : 'cartões'} de crédito',
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const AccountsScreen(mode: AccountsMode.cards)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          _Section('Segurança'),
          Reveal(
            index: 4,
            child: SoftCard(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _NavRow(
                Icons.lock_outline_rounded,
                'Alterar senha',
                'Troque a senha da sua conta',
                () => showPasswordSheet(context),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Reveal(
            index: 5,
            child: Pressable(
              onTap: () => _confirmSignOut(context),
              child: Container(
                height: 52,
                decoration: BoxDecoration(color: C.accentBg, borderRadius: BorderRadius.circular(26)),
                child: const Center(
                  child: Text('Sair da conta', style: TextStyle(color: C.accent, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  void _confirmSignOut(BuildContext context) => _sheet<void>(
    context,
    (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Sair da conta?', style: T.title.copyWith(fontSize: 20)),
        const SizedBox(height: 6),
        Text(
          'Seus dados ficam salvos na nuvem. Para voltar, entre com seu e-mail e senha em qualquer aparelho.',
          style: T.sub,
        ),
        const SizedBox(height: 16),
        _BigButton('Sair', danger: true, onTap: () {
          Navigator.of(ctx).pop();
          Store.i.signOut();
        }),
        const SizedBox(height: 8),
        _BigButton('Cancelar', ghost: true, onTap: () => Navigator.of(ctx).pop()),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  final String text;
  const _Section(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4),
    child: Text(text, style: T.small.copyWith(fontWeight: FontWeight.w700)),
  );
}

class _NavRow extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  final VoidCallback onTap;
  const _NavRow(this.icon, this.title, this.sub, this.onTap);
  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, size: 18, color: C.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: T.body.copyWith(fontSize: 13.5)),
                Text(sub, style: T.small),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 20, color: C.faint),
        ],
      ),
    ),
  );
}

/// Photo when set, otherwise the initials.
class ProfileAvatar extends StatelessWidget {
  final double size;
  const ProfileAvatar({super.key, this.size = 56});
  @override
  Widget build(BuildContext context) {
    final p = Store.i.profile;
    final parts = p.name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final initials = parts.isEmpty ? '?' : (parts.length == 1 ? parts.first[0] : parts.first[0] + parts.last[0]).toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: C.ink,
        shape: BoxShape.circle,
        image: p.photo == null ? null : DecorationImage(image: MemoryImage(p.photo!), fit: BoxFit.cover),
      ),
      child: p.photo != null
          ? null
          : Text(initials, style: TextStyle(color: C.onInk, fontSize: size * 0.36, fontWeight: FontWeight.w700)),
    );
  }
}

// ---------------------------------------------------------------- shared sheet helpers

Future<R?> _sheet<R>(BuildContext context, Widget Function(BuildContext) child) => showModalBottomSheet<R>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  barrierColor: Colors.black38,
  builder: (ctx) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
    child: Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(30)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 36, height: 4, decoration: BoxDecoration(color: C.track, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 14),
              child(ctx),
            ],
          ),
        ),
      ),
    ),
  ),
);

class _BigButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool danger, ghost;
  const _BigButton(this.label, {required this.onTap, this.danger = false, this.ghost = false});
  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Container(
      height: 50,
      decoration: BoxDecoration(
        color: danger ? C.accent : (ghost ? C.bg : C.ink),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w600, color: danger ? Colors.white : (ghost ? C.ink : C.onInk)),
        ),
      ),
    ),
  );
}

Widget _input(TextEditingController c, String hint, {bool obscure = false, TextInputType? type, IconData? icon}) => Container(
  height: 48,
  margin: const EdgeInsets.only(bottom: 10),
  padding: const EdgeInsets.symmetric(horizontal: 14),
  decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(14)),
  child: Row(
    children: [
      if (icon != null) ...[Icon(icon, size: 18, color: C.ink), const SizedBox(width: 10)],
      Expanded(
        child: TextField(
          controller: c,
          obscureText: obscure,
          keyboardType: type,
          autocorrect: !obscure,
          enableSuggestions: !obscure,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: C.ink),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: hint,
            hintStyle: TextStyle(color: C.faint, fontWeight: FontWeight.w400),
          ),
        ),
      ),
    ],
  ),
);

// ---------------------------------------------------------------- edit profile

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _s = Store.i;
  late final _name = TextEditingController(text: _s.profile.name);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 85);
      if (f == null) return;
      _s.updateProfile(photo: await f.readAsBytes());
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível abrir a galeria');
    }
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return setState(() => _error = 'Informe seu nome');
    HapticFeedback.mediumImpact();
    _s.updateProfile(name: name);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListenableBuilder(
        listenable: _s,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            Row(
              children: [
                RoundIcon(Icons.arrow_back_rounded, onTap: () => Navigator.of(context).pop()),
                const SizedBox(width: 12),
                Expanded(child: Text('Editar perfil', style: T.title)),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ProfileAvatar(size: 104),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Pressable(
                      onTap: _pickPhoto,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: C.accent, shape: BoxShape.circle, border: Border.all(color: C.bg, width: 3)),
                        child: const Icon(Icons.photo_camera_rounded, size: 17, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_s.profile.photo != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Pressable(
                    onTap: () => _s.updateProfile(photo: null),
                    child: Text('Remover foto', style: T.small.copyWith(color: C.accent, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            _input(_name, 'Nome', icon: Icons.person_outline_rounded),
            // The e-mail is the login, so it is shown but not editable.
            Container(
              height: 48,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  Icon(Icons.mail_outline_rounded, size: 18, color: C.faint),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_s.profile.email, style: T.sub, overflow: TextOverflow.ellipsis)),
                  Icon(Icons.lock_outline_rounded, size: 16, color: C.faint),
                ],
              ),
            ),
            if (_error != null) Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(_error!, style: T.small.copyWith(color: C.accent, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 6),
            _BigButton('Salvar', onTap: _save),
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------- password

Future<void> showPasswordSheet(BuildContext context) => _sheet<void>(context, (_) => const _PasswordForm());

class _PasswordForm extends StatefulWidget {
  const _PasswordForm();
  @override
  State<_PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends State<_PasswordForm> {
  final _cur = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _cur.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    if (_new.text != _confirm.text) return setState(() => _error = 'As senhas não conferem');
    setState(() => _busy = true);
    final err = await Store.i.changePassword(_cur.text, _new.text);
    if (!mounted) return;
    if (err != null) {
      return setState(() {
        _error = err;
        _busy = false;
      });
    }
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(const SnackBar(content: Text('Senha atualizada')));
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Alterar senha', style: T.title.copyWith(fontSize: 20)),
      const SizedBox(height: 4),
      Text('É a senha da sua conta: vale para entrar em qualquer aparelho.', style: T.sub),
      const SizedBox(height: 14),
      _input(_cur, 'Senha atual', obscure: true, icon: Icons.lock_outline_rounded),
      _input(_new, 'Nova senha (mín. 6 caracteres)', obscure: true, icon: Icons.lock_reset_rounded),
      _input(_confirm, 'Confirmar nova senha', obscure: true, icon: Icons.check_circle_outline_rounded),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(_error!, style: T.small.copyWith(color: C.accent, fontWeight: FontWeight.w600)),
        ),
      _BigButton(_busy ? 'Salvando…' : 'Salvar senha', onTap: _save),
    ],
  );
}

// ---------------------------------------------------------------- confirm e-mail

/// Shown after sign-up (or when logging into an unconfirmed account) until the link is opened.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});
  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> with WidgetsBindingObserver {
  bool _busy = false;
  String? _error, _info;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back from the e-mail app: check by ourselves, no button needed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) Store.i.checkVerified();
  }

  Future<void> _check() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await Store.i.checkVerified();
    if (!mounted || ok) return; // on success the app moves on by itself
    setState(() {
      _busy = false;
      _info = null;
      _error = 'Ainda não confirmado. Abra o link que enviamos para o seu e-mail.';
    });
  }

  Future<void> _resend() async {
    if (_busy) return;
    setState(() => _busy = true);
    final err = await Store.i.resendVerification();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
      _info = err == null ? 'E-mail reenviado.' : null;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(color: C.accentBg, borderRadius: BorderRadius.circular(22)),
                    child: const Icon(Icons.mark_email_unread_outlined, color: C.accent, size: 34),
                  ),
                ),
                const SizedBox(height: 18),
                Text('Confirme seu e-mail', textAlign: TextAlign.center, style: T.title),
                const SizedBox(height: 6),
                Text(
                  'Enviamos um link para ${Store.i.user?.email ?? 'o seu e-mail'}. '
                  'Abra-o para ativar sua conta. Não chegou? Veja também a caixa de spam.',
                  textAlign: TextAlign.center,
                  style: T.sub,
                ),
                const SizedBox(height: 24),
                if (_error != null || _info != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      _error ?? _info!,
                      textAlign: TextAlign.center,
                      style: T.small.copyWith(color: _error != null ? C.accent : C.green, fontWeight: FontWeight.w600),
                    ),
                  ),
                _BigButton(_busy ? 'Verificando…' : 'Já confirmei', onTap: _check),
                const SizedBox(height: 8),
                _BigButton('Reenviar e-mail', ghost: true, onTap: _resend),
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Center(
                    child: Pressable(
                      onTap: Store.i.signOut,
                      child: Text('Usar outro e-mail', style: T.small.copyWith(color: C.accent, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------- login / sign-up

/// Shown when nobody is signed in: "Entrar" with an existing account or "Criar conta".
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _signUp = false, _demo = false, _busy = false;
  String? _error, _info;

  @override
  void dispose() {
    for (final c in [_name, _email, _pass, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _toggle() => setState(() {
    _signUp = !_signUp;
    _error = _info = null;
  });

  Future<void> _submit() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    String? err;
    if (_email.text.trim().isEmpty || _pass.text.isEmpty) {
      err = 'Preencha e-mail e senha';
    } else if (_signUp && _name.text.trim().isEmpty) {
      err = 'Informe seu nome';
    } else if (_signUp && _pass.text != _confirm.text) {
      err = 'As senhas não conferem';
    }
    if (err != null) return _show(err);
    setState(() {
      _busy = true;
      _error = _info = null;
    });
    err = _signUp
        ? await Store.i.signUp(_name.text, _email.text, _pass.text, demo: _demo)
        : await Store.i.signIn(_email.text, _pass.text);
    // On success the app switches screens by itself (Store listens to Firebase Auth).
    if (mounted) {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  void _show(String err) => setState(() {
    _error = err;
    _info = null;
  });

  Future<void> _forgot() async {
    if (_email.text.trim().isEmpty) return _show('Digite seu e-mail acima');
    setState(() => _busy = true);
    final err = await Store.i.resetPassword(_email.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
      _info = err == null ? 'Enviamos um link para redefinir a senha. Veja seu e-mail (e o spam).' : null;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(22)),
                    child: Icon(Icons.account_balance_wallet_rounded, color: C.onInk, size: 34),
                  ),
                ),
                const SizedBox(height: 18),
                Text(_signUp ? 'Criar conta' : 'Bem-vindo de volta', textAlign: TextAlign.center, style: T.title),
                const SizedBox(height: 4),
                Text(
                  _signUp ? 'Seus dados ficam salvos na nuvem.' : 'Entre para ver suas finanças.',
                  textAlign: TextAlign.center,
                  style: T.sub,
                ),
                const SizedBox(height: 24),
                if (_signUp) _input(_name, 'Nome', icon: Icons.person_outline_rounded),
                _input(_email, 'E-mail', type: TextInputType.emailAddress, icon: Icons.mail_outline_rounded),
                _input(_pass, _signUp ? 'Senha (mín. 6 caracteres)' : 'Senha', obscure: true, icon: Icons.lock_outline_rounded),
                if (_signUp) ...[
                  _input(_confirm, 'Confirmar senha', obscure: true, icon: Icons.check_circle_outline_rounded),
                  Pressable(
                    onTap: () => setState(() => _demo = !_demo),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            _demo ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                            size: 22,
                            color: _demo ? C.accent : C.faint,
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text('Começar com dados de exemplo', style: T.body.copyWith(fontSize: 13.5))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                if (_error != null || _info != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      _error ?? _info!,
                      textAlign: TextAlign.center,
                      style: T.small.copyWith(color: _error != null ? C.accent : C.green, fontWeight: FontWeight.w600),
                    ),
                  ),
                _BigButton(_busy ? 'Aguarde…' : (_signUp ? 'Criar conta' : 'Entrar'), onTap: _submit),
                const SizedBox(height: 8),
                _BigButton(_signUp ? 'Já tenho conta' : 'Criar uma conta', ghost: true, onTap: _toggle),
                if (!_signUp)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Center(
                      child: Pressable(
                        onTap: _forgot,
                        child: Text('Esqueci minha senha', style: T.small.copyWith(color: C.accent, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
