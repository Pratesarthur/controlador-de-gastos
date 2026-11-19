import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'calendar_sheet.dart';
import 'statement_parser.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

/// Opens the bank statement importer flow (File/Text → Review & Confirm → Save).
Future<void> openStatementImport(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const StatementImportScreen()));

String _formatDateBr(DateTime d) {
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd/$mm/${d.year}';
}

String _formatLabel(StatementFormat f) => switch (f) {
  StatementFormat.pdf => 'PDF',
  StatementFormat.csv => 'CSV',
  StatementFormat.ofx => 'OFX',
  StatementFormat.text => 'Texto',
};

// ---------------------------------------------------------------- Step 1: pick file or paste text

class StatementImportScreen extends StatefulWidget {
  const StatementImportScreen({super.key});
  @override
  State<StatementImportScreen> createState() => _StatementImportScreenState();
}

class _StatementImportScreenState extends State<StatementImportScreen> {
  final _textCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  static const _banks = [
    'Nubank',
    'Inter',
    'Itaú',
    'Bradesco',
    'Santander',
    'BB',
    'Caixa',
    'C6',
    'BTG',
    'PicPay',
    'Mercado Pago',
    '+ outros',
  ];

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    if (_loading) return;
    HapticFeedback.selectionClick();
    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      final picked = await FilePicker.pickFile(
        dialogTitle: 'Selecionar extrato bancário',
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'csv', 'ofx', 'qfx', 'txt'],
      );
      if (picked == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final bytes = await picked.readAsBytes();
      await _parseFileBytes(bytes, picked.name);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Não foi possível abrir o arquivo selecionado.';
        });
      }
    }
  }

  Future<void> _parseFileBytes(
    Uint8List bytes,
    String fileName, {
    String? password,
  }) async {
    try {
      final result = StatementParser.parseBytes(
        bytes,
        fileName: fileName,
        password: password,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      await _handleResult(result);
    } on StatementPasswordRequiredException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      final pwd = await _askPdfPassword(wrongPassword: e.wrongPassword);
      if (pwd == null || !mounted) return;
      setState(() {
        _loading = true;
        _error = null;
      });
      await _parseFileBytes(bytes, fileName, password: pwd);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'Não foi possível ler este arquivo. Verifique se o PDF contém texto selecionável ou exporte em CSV/OFX.';
      });
    }
  }

  Future<void> _parsePastedText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _loading) return;
    HapticFeedback.selectionClick();
    setState(() {
      _error = null;
      _loading = true;
    });
    final parsed = StatementParser.parseRawString(text);
    if (!mounted) return;
    setState(() => _loading = false);
    await _handleResult(parsed);
  }

  Future<void> _handleResult(StatementParseResult result) async {
    if (result.items.isEmpty) {
      setState(() {
        _error = result.ignoredBalanceLines > 0
            ? 'Foram encontradas apenas linhas de saldo/resumo (${result.ignoredBalanceLines}), sem lançamentos válidos.'
            : 'Nenhum lançamento foi reconhecido. Verifique se o extrato possui datas e valores (ex.: 12/05/2026 Mercado -85,40).';
      });
      return;
    }

    StatementParser.markDuplicates(result.items, Store.i);
    final savedCount = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(builder: (_) => StatementConfirmScreen(result)),
    );
    if (savedCount != null && savedCount > 0 && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$savedCount ${savedCount == 1 ? 'lançamento importado' : 'lançamentos importados'} com sucesso.',
          ),
        ),
      );
    }
  }

  Future<String?> _askPdfPassword({bool wrongPassword = false}) {
    final ctrl = TextEditingController();
    return showModalBottomSheet<String>(
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
            decoration: BoxDecoration(
              color: C.surface,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: C.track,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text('PDF protegido por senha', style: T.title.copyWith(fontSize: 20)),
                const SizedBox(height: 6),
                Text(
                  wrongPassword
                      ? 'A senha informada não abriu o documento. Tente novamente.'
                      : 'Na maioria dos bancos brasileiros, a senha são os primeiros dígitos do seu CPF.',
                  style: T.sub.copyWith(
                    color: wrongPassword ? C.accent : C.muted,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: C.bg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 18, color: C.ink),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: ctrl,
                          obscureText: true,
                          autofocus: true,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: C.ink,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Digite a senha do PDF',
                            hintStyle: TextStyle(
                              color: C.faint,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          onSubmitted: (_) =>
                              Navigator.of(ctx).pop(ctrl.text.trim()),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Pressable(
                  onTap: () => Navigator.of(ctx).pop(ctrl.text.trim()),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: C.ink,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Center(
                      child: Text(
                        'Desbloquear PDF',
                        style: TextStyle(
                          color: C.onInk,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _textCtrl.text.trim().isNotEmpty;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            Reveal(
              child: Row(
                children: [
                  RoundIcon(
                    Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Importar extrato', style: T.title),
                        Text('PDF, CSV, OFX ou texto bancário', style: T.sub),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Reveal(
              index: 1,
              child: SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: C.bg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.upload_file_rounded,
                            size: 20,
                            color: C.ink,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Ler arquivo do banco', style: T.body),
                              Text(
                                'Selecione PDF, CSV, OFX ou TXT exportado do banco.',
                                style: T.small,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final b in _banks)
                          Pill(b, fg: C.muted, bg: C.bg),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: C.bg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.filter_alt_outlined,
                            size: 16,
                            color: C.green,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Linhas de saldo em conta e saldos diários são filtradas automaticamente. Você revisa tudo antes de salvar.',
                              style: T.small.copyWith(color: C.ink),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Pressable(
                      onTap: _loading ? null : _pickFile,
                      child: AnimatedContainer(
                        duration: Motion.base,
                        curve: Motion.curve,
                        height: 50,
                        decoration: BoxDecoration(
                          color: _loading ? C.track : C.ink,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Center(
                          child: _loading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: C.ink,
                                  ),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.folder_open_rounded,
                                      size: 18,
                                      color: C.onInk,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Escolher arquivo',
                                      style: TextStyle(
                                        color: C.onInk,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Reveal(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: C.accentBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 18,
                        color: C.accent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: T.small.copyWith(
                            color: C.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Reveal(
              index: 2,
              child: SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Colar texto do extrato', style: T.body),
                              Text(
                                'Copie os lançamentos do app ou internet banking.',
                                style: T.small,
                              ),
                            ],
                          ),
                        ),
                        if (hasText)
                          GestureDetector(
                            onTap: () {
                              _textCtrl.clear();
                              setState(() => _error = null);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 8,
                              ),
                              child: Text(
                                'Limpar',
                                style: T.small.copyWith(
                                  color: C.accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: C.bg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TextField(
                        controller: _textCtrl,
                        minLines: 5,
                        maxLines: 9,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: C.ink,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText:
                              'Ex.:\n12/05/2026 Supermercado Extra -185,40\n12/05/2026 Saldo do dia 2.450,00\n13/05/2026 Pix recebido Maria +500,00',
                          hintStyle: TextStyle(
                            color: C.faint,
                            fontWeight: FontWeight.w400,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Pressable(
                      onTap: hasText && !_loading ? _parsePastedText : null,
                      child: AnimatedContainer(
                        duration: Motion.base,
                        curve: Motion.curve,
                        height: 50,
                        decoration: BoxDecoration(
                          color: hasText ? C.ink : C.track,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Center(
                          child: Text(
                            'Analisar texto',
                            style: TextStyle(
                              color: hasText ? C.onInk : C.faint,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Step 2: confirmation screen

class StatementConfirmScreen extends StatefulWidget {
  final StatementParseResult result;
  const StatementConfirmScreen(this.result, {super.key});
  @override
  State<StatementConfirmScreen> createState() => _StatementConfirmScreenState();
}

class _StatementConfirmScreenState extends State<StatementConfirmScreen> {
  final _s = Store.i;
  late final List<ParsedTxn> _items = List<ParsedTxn>.from(widget.result.items);
  late bool _isCard;
  String? _srcId;
  int _filterTab = 0; // 0 Todas · 1 Despesas · 2 Receitas
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _isCard = widget.result.looksLikeCard && _s.cards.isNotEmpty;
    _srcId = _pickInitialSource();
  }

  String? _pickInitialSource() {
    final bank = widget.result.detectedBank?.toLowerCase();
    if (_isCard) {
      if (bank != null) {
        final match = _s.cards
            .where((c) => c.name.toLowerCase().contains(bank))
            .firstOrNull;
        if (match != null) return match.id;
      }
      return _s.favCard?.id;
    }
    if (bank != null) {
      final match = _s.accounts
          .where((a) => a.name.toLowerCase().contains(bank))
          .firstOrNull;
      if (match != null) return match.id;
    }
    return _s.accounts.isEmpty ? null : _s.favAccountId;
  }

  void _setCard(bool card) {
    HapticFeedback.selectionClick();
    setState(() {
      _isCard = card;
      _srcId = card
          ? (_s.cards.isEmpty ? null : _s.favCard!.id)
          : (_s.accounts.isEmpty ? null : _s.favAccountId);
    });
  }

  List<ParsedTxn> get _selectedItems =>
      _items.where((t) => t.selected).toList();

  List<ParsedTxn> get _visibleItems => switch (_filterTab) {
    1 => _items.where((t) => t.kind == Kind.expense).toList(),
    2 => _items.where((t) => t.kind == Kind.income).toList(),
    _ => _items,
  };

  double get _selectedIncome => _selectedItems
      .where((t) => t.kind == Kind.income)
      .fold(0.0, (a, t) => a + t.amount);

  double get _selectedExpense => _selectedItems
      .where((t) => t.kind == Kind.expense)
      .fold(0.0, (a, t) => a + t.amount);

  int get _duplicateCount =>
      _items.where((t) => t.possibleDuplicate).length;

  void _toggleAll() {
    HapticFeedback.selectionClick();
    final selectAll = _selectedItems.length < _items.length;
    setState(() {
      for (final item in _items) {
        item.selected = selectAll;
      }
    });
  }

  Future<void> _editItem(ParsedTxn item) async {
    HapticFeedback.selectionClick();
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black38,
      builder: (_) => _EditParsedTxnSheet(item: item),
    );
    if (!mounted) return;
    if (action == 'delete') {
      setState(() => _items.removeWhere((e) => e.id == item.id));
    } else if (action == 'updated') {
      setState(() {
        item.possibleDuplicate = _s.hasSimilarTxn(
          item.date,
          item.amount,
          item.kind,
        );
      });
    }
  }

  Future<void> _confirmSave() async {
    final chosen = _selectedItems;
    if (chosen.isEmpty || _srcId == null || _saved) return;
    HapticFeedback.mediumImpact();

    _s.addBatch([
      for (final item in chosen)
        (
          title: item.title,
          categoryId: item.categoryId,
          subId: item.subId,
          amount: item.amount,
          kind: item.kind,
          date: item.date,
          accountId: _srcId!,
          isCard: _isCard && item.kind == Kind.expense,
        ),
    ]);

    setState(() => _saved = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) Navigator.of(context).pop(chosen.length);
  }

  Widget _srcChips() {
    final list = _isCard
        ? [for (final c in _s.cards) (c.id, c.name, Icons.credit_card_rounded)]
        : [
            for (final a in _s.accounts)
              (a.id, a.name, Icons.account_balance_outlined),
          ];
    if (list.isEmpty) {
      return Text(
        'Nenhum cartão cadastrado. Cadastre em Início ▸ Gerenciar.',
        style: T.small.copyWith(color: C.accent),
      );
    }
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          for (final e in list)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Pressable(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _srcId = e.$1);
                },
                child: AnimatedContainer(
                  duration: Motion.base,
                  curve: Motion.curve,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: _srcId == e.$1 ? C.ink : C.bg,
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        e.$3,
                        size: 15,
                        color: _srcId == e.$1 ? C.onInk : C.ink,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        e.$2,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _srcId == e.$1 ? C.onInk : C.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selCount = _selectedItems.length;
    final visible = _visibleItems;
    final canSave = selCount > 0 && _srcId != null;
    final subtitleParts = [
      if (widget.result.detectedBank != null) widget.result.detectedBank!,
      if (widget.result.fileName != null) widget.result.fileName!,
      if (widget.result.detectedBank == null && widget.result.fileName == null)
        'Revise os dados antes de gravar',
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Reveal(
                    child: Row(
                      children: [
                        RoundIcon(
                          Icons.arrow_back_rounded,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Confirmar importação', style: T.title),
                              Text(
                                subtitleParts.join(' · '),
                                style: T.sub,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Reveal(
                    index: 1,
                    child: SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (widget.result.detectedBank != null)
                                Pill(
                                  widget.result.detectedBank!,
                                  fg: C.ink,
                                  bg: C.bg,
                                ),
                              Pill(
                                _formatLabel(widget.result.format),
                                fg: C.muted,
                                bg: C.bg,
                              ),
                              if (widget.result.ignoredBalanceLines > 0)
                                Pill(
                                  '${widget.result.ignoredBalanceLines} ${widget.result.ignoredBalanceLines == 1 ? 'saldo ignorado' : 'saldos ignorados'}',
                                  fg: C.green,
                                  bg: C.greenBg,
                                ),
                              if (_duplicateCount > 0)
                                Pill(
                                  '$_duplicateCount ${_duplicateCount == 1 ? 'possível duplicado' : 'possíveis duplicados'}',
                                  fg: C.amber,
                                  bg: C.amberBg,
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _SummaryFlow(
                                  label: 'Receitas',
                                  value: _selectedIncome,
                                  icon: Icons.arrow_downward_rounded,
                                  fg: C.green,
                                  bg: C.greenBg,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _SummaryFlow(
                                  label: 'Despesas',
                                  value: _selectedExpense,
                                  icon: Icons.arrow_upward_rounded,
                                  fg: C.accent,
                                  bg: C.accentBg,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '$selCount de ${_items.length} selecionados',
                                  style: T.small.copyWith(
                                    color: C.ink,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: _toggleAll,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    selCount < _items.length
                                        ? 'Selecionar todos'
                                        : 'Desmarcar todos',
                                    style: T.small.copyWith(
                                      color: C.accent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Reveal(
                    index: 2,
                    child: SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Onde lançar?', style: T.body),
                          const SizedBox(height: 10),
                          SegmentedPill(
                            labels: const ['Conta', 'Cartão de crédito'],
                            index: _isCard ? 1 : 0,
                            onChanged: (i) => _setCard(i == 1),
                          ),
                          const SizedBox(height: 10),
                          _srcChips(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Reveal(
                    index: 3,
                    child: SegmentedPill(
                      labels: const ['Todas', 'Despesas', 'Receitas'],
                      index: _filterTab,
                      onChanged: (i) {
                        HapticFeedback.selectionClick();
                        setState(() => _filterTab = i);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toque em um lançamento para editar categoria, data, valor ou tipo.',
                    style: T.small.copyWith(fontSize: 11, color: C.muted),
                  ),
                  const SizedBox(height: 10),
                  if (visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(28),
                      child: Center(
                        child: Text(
                          'Nenhum lançamento neste filtro',
                          style: T.sub,
                        ),
                      ),
                    ),
                  for (var i = 0; i < visible.length; i++)
                    Padding(
                      key: ValueKey(visible[i].id),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ParsedTxnRow(
                        item: visible[i],
                        onToggle: () {
                          HapticFeedback.selectionClick();
                          setState(
                            () => visible[i].selected = !visible[i].selected,
                          );
                        },
                        onEdit: () => _editItem(visible[i]),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: C.surface,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 18,
                    offset: Offset(0, -6),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Pressable(
                  onTap: canSave ? _confirmSave : null,
                  child: AnimatedContainer(
                    duration: Motion.base,
                    curve: Motion.curve,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _saved ? C.green : (!canSave ? C.track : C.ink),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: Motion.fast,
                        transitionBuilder: (c, a) => ScaleTransition(
                          scale: a,
                          child: FadeTransition(opacity: a, child: c),
                        ),
                        child: _saved
                            ? const Row(
                                key: ValueKey('saved'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Importado!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                selCount == 0
                                    ? 'Selecione ao menos 1 lançamento'
                                    : 'Confirmar e salvar $selCount ${selCount == 1 ? 'lançamento' : 'lançamentos'}',
                                key: ValueKey('btn_$selCount'),
                                style: TextStyle(
                                  color: !canSave ? C.faint : C.onInk,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryFlow extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final Color fg, bg;
  const _SummaryFlow({
    required this.label,
    required this.value,
    required this.icon,
    required this.fg,
    required this.bg,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: C.bg,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Icon(icon, size: 15, color: fg),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: T.small.copyWith(fontSize: 10.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SplitText(brl(value), style: T.body.copyWith(fontSize: 13.5)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ParsedTxnRow extends StatelessWidget {
  final ParsedTxn item;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  const _ParsedTxnRow({
    required this.item,
    required this.onToggle,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final inc = item.kind == Kind.income;
    final cat = item.category;
    final sub = item.sub;
    final subtitle = [
      sub == null ? cat.name : '${cat.name} › ${sub.name}',
      _formatDateBr(item.date),
    ].join(' · ');

    return AnimatedOpacity(
      duration: Motion.fast,
      opacity: item.selected ? 1.0 : 0.45,
      child: SoftCard(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: AnimatedContainer(
                    duration: Motion.fast,
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: item.selected ? C.ink : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: item.selected ? C.ink : C.faint,
                        width: 1.8,
                      ),
                    ),
                    child: item.selected
                        ? Icon(Icons.check_rounded, size: 15, color: C.onInk)
                        : null,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Pressable(
                onTap: onEdit,
                child: Padding(
                  padding: const EdgeInsets.only(right: 6, top: 4, bottom: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: C.bg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(cat.icon, size: 18, color: C.ink),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: T.body.copyWith(fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              subtitle,
                              style: T.small,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (item.possibleDuplicate ||
                                item.installmentLabel != null) ...[
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  if (item.possibleDuplicate)
                                    Pill(
                                      'Possível duplicado',
                                      fg: C.amber,
                                      bg: C.amberBg,
                                    ),
                                  if (item.installmentLabel != null)
                                    Pill(
                                      'Parcela ${item.installmentLabel}',
                                      fg: C.muted,
                                      bg: C.bg,
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${inc ? '+' : '−'} ${brl(item.amount)}',
                            style: T.body.copyWith(
                              fontSize: 13,
                              color: inc ? C.green : C.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.edit_outlined,
                                size: 11,
                                color: C.faint,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Editar',
                                style: T.small.copyWith(
                                  fontSize: 10,
                                  color: C.faint,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Edit draft bottom sheet

enum _EditView { main, categories, subs }

class _EditParsedTxnSheet extends StatefulWidget {
  final ParsedTxn item;
  const _EditParsedTxnSheet({required this.item});
  @override
  State<_EditParsedTxnSheet> createState() => _EditParsedTxnSheetState();
}

class _EditParsedTxnSheetState extends State<_EditParsedTxnSheet> {
  late Kind _kind = widget.item.kind;
  late String _cat = widget.item.categoryId;
  late String? _sub = widget.item.subId;
  late DateTime _date = widget.item.date;
  late final _titleCtrl = TextEditingController(text: widget.item.title);
  late final _amountCtrl = TextEditingController(
    text: widget.item.amount.toStringAsFixed(2).replaceAll('.', ','),
  );
  Category? _pendingCat;
  _EditView _view = _EditView.main;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  List<Category> get _cats => categories.where((c) => c.kind == _kind).toList();

  double? _parseAmount() {
    final s = _amountCtrl.text.trim().replaceAll('R\$', '').trim();
    if (s.isEmpty) return null;
    if (s.contains(',')) {
      return double.tryParse(s.replaceAll('.', '').replaceAll(',', '.'));
    }
    return double.tryParse(s);
  }

  Future<void> _pickDate() async {
    final d = await showCalendarSheet(context, _date);
    if (d != null && mounted) setState(() => _date = d);
  }

  void _apply() {
    final amount = _parseAmount();
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Informe um valor válido maior que zero.');
      return;
    }
    final title = _titleCtrl.text.trim();
    final cat = categoryById(_cat);
    widget.item
      ..kind = _kind
      ..categoryId = _cat
      ..subId = _sub
      ..date = _date
      ..amount = amount
      ..title = title.isEmpty ? (cat.subById(_sub)?.name ?? cat.name) : title;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop('updated');
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(30),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: C.track,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              switch (_view) {
                _EditView.main => _mainView(),
                _EditView.categories => _categoryGrid(),
                _EditView.subs => _subList(),
              },
            ],
          ),
        ),
      ),
    ),
  );

  Widget _mainView() {
    final cat = categoryById(_cat);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Editar lançamento', style: T.title.copyWith(fontSize: 20)),
        const SizedBox(height: 12),
        SegmentedPill(
          labels: const ['Despesa', 'Receita'],
          index: _kind.index,
          onChanged: (i) {
            HapticFeedback.selectionClick();
            setState(() {
              _kind = Kind.values[i];
              final (c, s) = StatementParser.categorize(_titleCtrl.text, _kind);
              _cat = c;
              _sub = s;
            });
          },
        ),
        const SizedBox(height: 12),
        Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: C.bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: TextField(
            controller: _titleCtrl,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: C.ink,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Descrição',
              hintStyle: TextStyle(color: C.faint, fontWeight: FontWeight.w400),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: C.bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Text('R\$', style: T.body.copyWith(color: C.muted)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _kind == Kind.income ? C.green : C.ink,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: '0,00',
                    hintStyle: TextStyle(
                      color: C.faint,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Pressable(
                onTap: () => setState(() => _view = _EditView.categories),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: C.bg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(cat.icon, size: 18, color: C.ink),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Categoria',
                              style: T.small.copyWith(fontSize: 10.5),
                            ),
                            Text(
                              cat.subById(_sub) == null
                                  ? cat.name
                                  : '${cat.name} › ${cat.subById(_sub)!.name}',
                              style: T.body.copyWith(fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 18, color: C.faint),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Pressable(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: C.bg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 18, color: C.ink),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Data',
                              style: T.small.copyWith(fontSize: 10.5),
                            ),
                            Text(
                              _formatDateBr(_date),
                              style: T.body.copyWith(fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 18, color: C.faint),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (widget.item.rawLine.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: C.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Linha original do extrato',
                  style: T.small.copyWith(fontSize: 10, color: C.faint),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.item.rawLine,
                  style: T.small.copyWith(fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: T.small.copyWith(
              color: C.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 14),
        Pressable(
          onTap: _apply,
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: C.ink,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Center(
              child: Text(
                'Aplicar alterações',
                style: TextStyle(color: C.onInk, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Pressable(
          onTap: () => Navigator.of(context).pop('delete'),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: C.accentBg,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Center(
              child: Text(
                'Remover da importação',
                style: TextStyle(
                  color: C.accent,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _categoryGrid() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          RoundIcon(
            Icons.arrow_back_rounded,
            onTap: () => setState(() => _view = _EditView.main),
          ),
          const SizedBox(width: 12),
          Text('Escolha a categoria', style: T.title.copyWith(fontSize: 20)),
        ],
      ),
      const SizedBox(height: 14),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.05,
        children: [
          for (final c in _cats)
            Pressable(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  if (c.subs.isEmpty && !c.dynamicSubs) {
                    _cat = c.id;
                    _sub = null;
                    _view = _EditView.main;
                  } else {
                    _pendingCat = c;
                    _view = _EditView.subs;
                  }
                });
              },
              child: AnimatedContainer(
                duration: Motion.base,
                curve: Motion.curve,
                decoration: BoxDecoration(
                  color: _cat == c.id ? C.ink : C.bg,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      c.icon,
                      size: 24,
                      color: _cat == c.id ? C.onInk : C.ink,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      c.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _cat == c.id ? C.onInk : C.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ],
  );

  Widget _subList() {
    final c = _pendingCat ?? categoryById(_cat);
    void pick(String? subId) {
      HapticFeedback.selectionClick();
      setState(() {
        _cat = c.id;
        _sub = subId;
        _view = _EditView.main;
      });
    }

    Widget row(String label, String? id, {IconData? icon}) {
      final sel = _cat == c.id && _sub == id;
      return Pressable(
        onTap: () => pick(id),
        child: AnimatedContainer(
          duration: Motion.base,
          curve: Motion.curve,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: sel ? C.ink : C.bg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: sel ? C.onInk : C.ink),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: sel ? C.onInk : C.ink,
                  ),
                ),
              ),
              if (sel) Icon(Icons.check_rounded, size: 18, color: C.onInk),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            RoundIcon(
              Icons.arrow_back_rounded,
              onTap: () => setState(() => _view = _EditView.categories),
            ),
            const SizedBox(width: 12),
            Icon(c.icon, size: 20, color: C.ink),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                c.name,
                style: T.title.copyWith(fontSize: 20),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (final sub in c.subs) row(sub.name, sub.id),
        if (!c.dynamicSubs)
          row('Sem subcategoria', null, icon: Icons.remove_rounded),
      ],
    );
  }
}
