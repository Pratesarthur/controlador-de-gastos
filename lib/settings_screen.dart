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
                s.password == null ? 'Definir senha' : 'Alterar senha',
                s.password == null ? 'Proteja o acesso ao app' : 'Troque sua senha de acesso',
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
          Store.i.password == null
              ? 'Seus dados continuam neste aparelho. Como você não definiu senha, basta tocar em Entrar para voltar.'
              : 'Seus dados continuam neste aparelho. Para voltar você precisará da sua senha.',
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
  late final _email = TextEditingController(text: _s.profile.email);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
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
    final email = _email.text.trim();
    if (name.isEmpty) return setState(() => _error = 'Informe seu nome');
    if (email.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return setState(() => _error = 'E-mail inválido');
    }
    HapticFeedback.mediumImpact();
    _s.updateProfile(name: name, email: email);
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
            _input(_email, 'E-mail', type: TextInputType.emailAddress, icon: Icons.mail_outline_rounded),
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
  bool get _hasPassword => Store.i.password != null;

  @override
  void dispose() {
    _cur.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _save() {
    if (_new.text != _confirm.text) return setState(() => _error = 'As senhas não conferem');
    final err = Store.i.changePassword(_cur.text, _new.text);
    if (err != null) return setState(() => _error = err);
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Senha atualizada')));
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(_hasPassword ? 'Alterar senha' : 'Definir senha', style: T.title.copyWith(fontSize: 20)),
      const SizedBox(height: 4),
      Text('A senha fica somente neste aparelho e protege o acesso ao app depois de sair da conta.', style: T.sub),
      const SizedBox(height: 14),
      if (_hasPassword) _input(_cur, 'Senha atual', obscure: true, icon: Icons.lock_outline_rounded),
      _input(_new, 'Nova senha (mín. 6 caracteres)', obscure: true, icon: Icons.lock_reset_rounded),
      _input(_confirm, 'Confirmar nova senha', obscure: true, icon: Icons.check_circle_outline_rounded),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(_error!, style: T.small.copyWith(color: C.accent, fontWeight: FontWeight.w600)),
        ),
      _BigButton('Salvar senha', onTap: _save),
    ],
  );
}

// ---------------------------------------------------------------- signed-out screen

class SignedOutScreen extends StatefulWidget {
  const SignedOutScreen({super.key});
  @override
  State<SignedOutScreen> createState() => _SignedOutScreenState();
}

class _SignedOutScreenState extends State<SignedOutScreen> {
  final _pass = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pass.dispose();
    super.dispose();
  }

  void _enter() {
    if (!Store.i.signIn(_pass.text)) setState(() => _error = 'Senha incorreta');
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
                Center(child: ProfileAvatar(size: 84)),
                const SizedBox(height: 16),
                Text('Olá, ${Store.i.profile.name}', textAlign: TextAlign.center, style: T.title),
                const SizedBox(height: 4),
                Text(
                  Store.i.password == null ? 'Você saiu da conta.' : 'Digite sua senha para entrar.',
                  textAlign: TextAlign.center,
                  style: T.sub,
                ),
                const SizedBox(height: 24),
                if (Store.i.password != null) _input(_pass, 'Senha', obscure: true, icon: Icons.lock_outline_rounded),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(_error!, textAlign: TextAlign.center, style: T.small.copyWith(color: C.accent, fontWeight: FontWeight.w600)),
                  ),
                _BigButton('Entrar', onTap: _enter),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
