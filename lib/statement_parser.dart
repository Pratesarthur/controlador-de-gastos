import 'dart:convert';
import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'store.dart';

enum StatementFormat { pdf, csv, ofx, text }

/// Thrown when a PDF statement is encrypted and needs a password (commonly the first digits of the CPF).
class StatementPasswordRequiredException implements Exception {
  final bool wrongPassword;
  const StatementPasswordRequiredException({this.wrongPassword = false});

  @override
  String toString() => wrongPassword
      ? 'Senha do PDF incorreta.'
      : 'Este PDF é protegido por senha.';
}

/// Editable draft transaction extracted from a bank statement before confirmation.
class ParsedTxn {
  final String id;
  DateTime date;
  String title;
  final String rawLine;
  double amount; // always positive
  Kind kind;
  String categoryId;
  String? subId;
  bool selected;
  bool possibleDuplicate;
  final String? installmentLabel;

  ParsedTxn({
    required this.id,
    required this.date,
    required this.title,
    required this.rawLine,
    required this.amount,
    required this.kind,
    required this.categoryId,
    this.subId,
    this.selected = true,
    this.possibleDuplicate = false,
    this.installmentLabel,
  });

  Category get category => categoryById(categoryId);
  Sub? get sub => category.subById(subId);
}

class StatementParseResult {
  final List<ParsedTxn> items;
  final String? detectedBank;
  final bool looksLikeCard;
  final StatementFormat format;
  final int ignoredBalanceLines;
  final String? fileName;

  const StatementParseResult({
    required this.items,
    required this.detectedBank,
    required this.looksLikeCard,
    required this.format,
    required this.ignoredBalanceLines,
    this.fileName,
  });
}

/// Multi-bank Brazilian statement parser (PDF, CSV, OFX and pasted text).
///
/// Supports Nubank, Banco Inter, Itaú, Bradesco, Santander, Banco do Brasil,
/// Caixa, C6 Bank, BTG Pactual, PicPay, Mercado Pago, PagBank, Neon, XP,
/// Sicoob, Sicredi, Will Bank, Banrisul, Stone, Cora, Safra and others.
class StatementParser {
  static int _seq = 0;
  static String _nextId() => 'imp_${++_seq}';

  // ---------------------------------------------------------------- entry points

  /// Parses raw file bytes based on extension or magic header.
  static StatementParseResult parseBytes(
    Uint8List bytes, {
    required String fileName,
    String? password,
    DateTime? referenceDate,
  }) {
    final lower = fileName.toLowerCase();
    final isPdfMagic = bytes.length >= 4 &&
        bytes[0] == 0x25 && // %
        bytes[1] == 0x50 && // P
        bytes[2] == 0x44 && // D
        bytes[3] == 0x46; // F

    if (lower.endsWith('.pdf') || isPdfMagic) {
      return parsePdfBytes(
        bytes,
        fileName: fileName,
        password: password,
        referenceDate: referenceDate,
      );
    }

    final content = decodeBytes(bytes);
    return parseRawString(
      content,
      fileName: fileName,
      referenceDate: referenceDate,
    );
  }

  /// Auto-detects OFX, CSV or plain text statement from an already decoded string.
  static StatementParseResult parseRawString(
    String content, {
    String? fileName,
    DateTime? referenceDate,
  }) {
    final lower = (fileName ?? '').toLowerCase();
    if (lower.endsWith('.ofx') ||
        lower.endsWith('.qfx') ||
        content.contains('<OFX>') ||
        content.contains('<STMTTRN>')) {
      return parseOfx(content, fileName: fileName);
    }

    if (lower.endsWith('.csv') || _looksLikeCsv(content)) {
      final csvRes = parseCsv(
        content,
        fileName: fileName,
        referenceDate: referenceDate,
      );
      if (csvRes.items.isNotEmpty) return csvRes;
    }

    return parseText(
      content,
      fileName: fileName,
      format: StatementFormat.text,
      referenceDate: referenceDate,
    );
  }

  /// Decodes UTF-8 (with optional BOM) or falls back to Latin-1 (common in Itaú/BB/Bradesco/Caixa exports).
  static String decodeBytes(Uint8List bytes) {
    try {
      var text = utf8.decode(bytes);
      if (text.startsWith('\uFEFF')) text = text.substring(1);
      return text;
    } catch (_) {
      return latin1.decode(bytes);
    }
  }

  // ---------------------------------------------------------------- PDF parser

  /// Extracts spatially ordered rows from a PDF, strips running-balance columns
  /// when a "Saldo" table column header is detected, and parses transactions.
  static StatementParseResult parsePdfBytes(
    Uint8List bytes, {
    String? fileName,
    String? password,
    DateTime? referenceDate,
  }) {
    PdfDocument document;
    try {
      document = PdfDocument(inputBytes: bytes, password: password);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('password') ||
          msg.contains('encrypt') ||
          msg.contains('security') ||
          msg.contains('senha')) {
        throw StatementPasswordRequiredException(
          wrongPassword: password != null && password.isNotEmpty,
        );
      }
      rethrow;
    }

    try {
      final extractor = PdfTextExtractor(document);
      final extracted = <String>[];
      final pageCount = document.pages.count;

      for (var p = 0; p < pageCount; p++) {
        final pageWidth = document.pages[p].size.width;
        final lines = extractor.extractTextLines(
          startPageIndex: p,
          endPageIndex: p,
        );
        if (lines.isEmpty) {
          final plain = extractor.extractText(
            startPageIndex: p,
            endPageIndex: p,
            layoutText: true,
          );
          if (plain.trim().isNotEmpty) extracted.addAll(plain.split('\n'));
          continue;
        }
        extracted.addAll(_reconstructPdfPageRows(lines, pageWidth));
      }

      return parseText(
        extracted.join('\n'),
        fileName: fileName,
        format: StatementFormat.pdf,
        referenceDate: referenceDate,
      );
    } finally {
      document.dispose();
    }
  }

  /// Groups PDF text fragments into visual rows (by Y coordinate) and applies
  /// column-aware filtering so "Saldo" columns are stripped and separate
  /// "Crédito" / "Débito" columns preserve their sign.
  static List<String> _reconstructPdfPageRows(
    List<TextLine> lines,
    double pageWidth,
  ) {
    final words = <({double top, double left, double right, String text})>[];
    for (final line in lines) {
      if (line.wordCollection.isNotEmpty) {
        for (final w in line.wordCollection) {
          final t = w.text.trim();
          if (t.isEmpty) continue;
          words.add((
            top: w.bounds.top,
            left: w.bounds.left,
            right: w.bounds.right,
            text: t,
          ));
        }
      } else {
        final t = line.text.trim();
        if (t.isEmpty) continue;
        words.add((
          top: line.bounds.top,
          left: line.bounds.left,
          right: line.bounds.right,
          text: t,
        ));
      }
    }
    if (words.isEmpty) return const [];

    words.sort((a, b) {
      final dy = a.top - b.top;
      if (dy.abs() > 4.5) return dy.compareTo(0);
      return a.left.compareTo(b.left);
    });

    final rows = <List<({double top, double left, double right, String text})>>[];
    for (final w in words) {
      if (rows.isEmpty || (w.top - rows.last.first.top).abs() > 4.5) {
        rows.add([w]);
      } else {
        rows.last.add(w);
      }
    }

    double? saldoMinX;
    double? creditCenterX;
    double? debitCenterX;

    final out = <String>[];
    for (final row in rows) {
      row.sort((a, b) => a.left.compareTo(b.left));
      final fullLine = _joinRowTokens(row);
      final normFull = _normalize(fullLine);

      // Detect table header rows to locate Saldo / Crédito / Débito columns.
      final looksHeader = (normFull.contains('data') ||
              normFull.contains('lancamento') ||
              normFull.contains('descricao') ||
              normFull.contains('historico')) &&
          (normFull.contains('saldo') ||
              normFull.contains('valor') ||
              normFull.contains('credito') ||
              normFull.contains('debito'));

      if (looksHeader) {
        for (final tok in row) {
          final nt = _normalize(tok.text);
          final center = (tok.left + tok.right) / 2;
          if (nt == 'saldo' && tok.left > pageWidth * 0.52) {
            saldoMinX = tok.left - 24;
          } else if (nt.startsWith('credit') || nt.startsWith('entrad')) {
            creditCenterX = center;
          } else if (nt.startsWith('debit') || nt.startsWith('said')) {
            debitCenterX = center;
          }
        }
        out.add(fullLine);
        continue;
      }

      // If we know the Saldo column position and the row has at least one value
      // BEFORE the Saldo column, strip tokens inside the Saldo column.
      var filteredRow = row;
      if (saldoMinX != null) {
        final beforeSaldo = row.where((t) => t.left < saldoMinX!).toList();
        final inSaldo = row.where((t) => t.left >= saldoMinX!).toList();
        if (inSaldo.isNotEmpty &&
            _moneyRegex.hasMatch(_joinRowTokens(beforeSaldo))) {
          filteredRow = beforeSaldo;
        }
      }

      // If separate Crédito and Débito columns exist, tag unsigned amounts with +/-
      if (creditCenterX != null && debitCenterX != null) {
        final tagged = <String>[];
        for (var i = 0; i < filteredRow.length; i++) {
          final tok = filteredRow[i];
          final center = (tok.left + tok.right) / 2;
          var txt = tok.text;
          final isUnsignedMoney = _pureUnsignedMoneyRegex.hasMatch(txt);
          if (isUnsignedMoney) {
            final distCredit = (center - creditCenterX).abs();
            final distDebit = (center - debitCenterX).abs();
            if (distDebit < distCredit && distDebit < 70) {
              txt = '-$txt';
            } else if (distCredit < distDebit && distCredit < 70) {
              txt = '+$txt';
            }
          }
          if (i > 0) {
            final gap = tok.left - filteredRow[i - 1].right;
            tagged.add(gap > 14 ? '   ' : ' ');
          }
          tagged.add(txt);
        }
        out.add(tagged.join());
      } else {
        out.add(_joinRowTokens(filteredRow));
      }
    }

    return out;
  }

  static String _joinRowTokens(
    List<({double top, double left, double right, String text})> row,
  ) {
    final buf = StringBuffer();
    for (var i = 0; i < row.length; i++) {
      if (i > 0) {
        final gap = row[i].left - row[i - 1].right;
        buf.write(gap > 14 ? '   ' : ' ');
      }
      buf.write(row[i].text);
    }
    return buf.toString().trim();
  }

  // ---------------------------------------------------------------- OFX parser

  static StatementParseResult parseOfx(String content, {String? fileName}) {
    final bank = _detectBankFromOfx(content) ?? detectBank(content);
    final looksCard = content.toUpperCase().contains('<CREDITCARDMSGSRSV1>') ||
        content.toUpperCase().contains('<CCSTMTRS>') ||
        detectIsCard(content);

    final items = <ParsedTxn>[];
    var ignoredBalances = 0;

    // Count <LEDGERBAL> / <AVAILBAL> blocks as ignored balances if present.
    if (RegExp(r'<(LEDGERBAL|AVAILBAL)>', caseSensitive: false)
        .hasMatch(content)) {
      ignoredBalances += RegExp(r'<(LEDGERBAL|AVAILBAL)>', caseSensitive: false)
          .allMatches(content)
          .length;
    }

    final blockRe = RegExp(
      r'<STMTTRN>([\s\S]*?)</STMTTRN>',
      caseSensitive: false,
    );
    for (final m in blockRe.allMatches(content)) {
      final block = m.group(1) ?? '';
      final trnType = _ofxTag(block, 'TRNTYPE')?.toUpperCase() ?? '';
      final dtRaw = _ofxTag(block, 'DTPOSTED') ?? '';
      final amtRaw = _ofxTag(block, 'TRNAMT') ?? '';
      final memo = _ofxTag(block, 'MEMO') ?? '';
      final name = _ofxTag(block, 'NAME') ?? '';

      final rawDesc = _combineOfxDesc(name, memo);
      if (rawDesc.isNotEmpty && isBalanceOrSummaryLine(rawDesc)) {
        ignoredBalances++;
        continue;
      }

      final date = _parseOfxDate(dtRaw);
      final parsedAmt = double.tryParse(amtRaw.replaceAll(',', '.').trim());
      if (date == null || parsedAmt == null || parsedAmt == 0) continue;

      final Kind kind;
      if (parsedAmt < 0) {
        kind = Kind.expense;
      } else if (trnType == 'DEBIT' ||
          trnType == 'PAYMENT' ||
          trnType == 'FEE' ||
          trnType == 'SRVCHG' ||
          trnType == 'ATM' ||
          trnType == 'POS') {
        kind = Kind.expense;
      } else {
        kind = Kind.income;
      }

      final title = cleanDescription(rawDesc.isEmpty ? 'Lançamento' : rawDesc);
      final inst = _extractInstallmentLabel(rawDesc);
      final (catId, subId) = categorize(rawDesc, kind);

      items.add(
        ParsedTxn(
          id: _nextId(),
          date: date,
          title: title,
          rawLine: '$dtRaw · $rawDesc · $amtRaw',
          amount: parsedAmt.abs(),
          kind: kind,
          categoryId: catId,
          subId: subId,
          installmentLabel: inst,
        ),
      );
    }

    return StatementParseResult(
      items: items,
      detectedBank: bank,
      looksLikeCard: looksCard,
      format: StatementFormat.ofx,
      ignoredBalanceLines: ignoredBalances,
      fileName: fileName,
    );
  }

  static String? _ofxTag(String block, String tag) {
    final re = RegExp(
      '<$tag>\\s*([^<\\r\\n]+)',
      caseSensitive: false,
    );
    return re.firstMatch(block)?.group(1)?.trim();
  }

  static String _combineOfxDesc(String name, String memo) {
    if (name.isEmpty) return memo;
    if (memo.isEmpty) return name;
    if (memo.toLowerCase().contains(name.toLowerCase())) return memo;
    if (name.toLowerCase().contains(memo.toLowerCase())) return name;
    return '$name - $memo';
  }

  static DateTime? _parseOfxDate(String raw) {
    final digits = RegExp(r'^(\d{4})(\d{2})(\d{2})').firstMatch(raw.trim());
    if (digits == null) return null;
    final y = int.tryParse(digits.group(1)!);
    final m = int.tryParse(digits.group(2)!);
    final d = int.tryParse(digits.group(3)!);
    if (y == null || m == null || d == null) return null;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    return DateTime(y, m, d);
  }

  static String? _detectBankFromOfx(String content) {
    final org = _ofxTag(content, 'ORG') ?? '';
    final fromOrg = detectBank(org);
    if (fromOrg != null) return fromOrg;

    final bankId = _ofxTag(content, 'BANKID')?.replaceAll(RegExp(r'\D'), '') ?? '';
    final parsedCode = int.tryParse(bankId);
    final code = parsedCode != null
        ? parsedCode.toString().padLeft(3, '0')
        : bankId.padLeft(3, '0');
    const compe = {
      '001': 'Banco do Brasil',
      '033': 'Santander',
      '041': 'Banrisul',
      '070': 'BRB',
      '077': 'Banco Inter',
      '104': 'Caixa',
      '208': 'BTG Pactual',
      '212': 'Banco Original',
      '237': 'Bradesco',
      '260': 'Nubank',
      '290': 'PagBank',
      '323': 'Mercado Pago',
      '336': 'C6 Bank',
      '341': 'Itaú',
      '380': 'PicPay',
      '403': 'Cora',
      '422': 'Safra',
      '623': 'Banco Pan',
      '637': 'Sofisa Direto',
      '655': 'Neon',
      '748': 'Sicredi',
      '756': 'Sicoob',
    };
    return compe[code];
  }

  // ---------------------------------------------------------------- CSV parser

  static bool _looksLikeCsv(String content) {
    final lines = content
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .take(12)
        .toList();
    if (lines.length < 2) return false;
    for (final sep in [';', ',']) {
      final headerMatches = lines.where((l) {
        final n = _normalize(l);
        return l.split(sep).length >= 3 &&
            (n.contains('data') || n.contains('date')) &&
            (n.contains('valor') ||
                n.contains('amount') ||
                n.contains('debito') ||
                n.contains('credito'));
      });
      if (headerMatches.isNotEmpty) return true;
    }
    return false;
  }

  static StatementParseResult parseCsv(
    String content, {
    String? fileName,
    DateTime? referenceDate,
  }) {
    final rawLines = content
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (rawLines.isEmpty) {
      return StatementParseResult(
        items: const [],
        detectedBank: null,
        looksLikeCard: false,
        format: StatementFormat.csv,
        ignoredBalanceLines: 0,
        fileName: fileName,
      );
    }

    final refYear = _detectReferenceYear(content, referenceDate);
    final bank = detectBank(content) ?? detectBank(fileName ?? '');
    var looksCard = detectIsCard(content) || detectIsCard(fileName ?? '');

    // Detect delimiter & header row (some banks like Inter/Bradesco add 3-6 metadata rows above the table header).
    String sep = ';';
    int headerIdx = -1;
    int? dateCol, descCol, extraDescCol, amountCol, creditCol, debitCol, typeCol, balanceCol;

    for (var i = 0; i < rawLines.length && i < 18; i++) {
      for (final candidate in [';', ',', '\t']) {
        final cols = _splitCsvRow(rawLines[i], candidate);
        if (cols.length < 3) continue;
        final norms = cols.map(_normalize).toList();

        int? dCol, dsCol, exCol, aCol, cCol, dbCol, tCol, bCol;
        for (var c = 0; c < norms.length; c++) {
          final h = norms[c];
          if (h.contains('saldo') || h.contains('balance')) {
            bCol = c;
          } else if (dCol == null &&
              (h == 'data' ||
                  h == 'date' ||
                  h.startsWith('data ') ||
                  h.startsWith('data/') ||
                  h.contains('dt '))) {
            dCol = c;
          } else if (cCol == null &&
              (h.contains('credito') || h.contains('entrada') || h == 'credit')) {
            cCol = c;
          } else if (dbCol == null &&
              (h.contains('debito') || h.contains('saida') || h == 'debit')) {
            dbCol = c;
          } else if (aCol == null &&
              (h.contains('valor') ||
                  h.contains('amount') ||
                  h.contains('montante'))) {
            aCol = c;
          } else if (tCol == null &&
              (h == 'tipo' ||
                  h == 'natureza' ||
                  h == 'operacao' ||
                  h == 'd/c' ||
                  h == 'c/d')) {
            tCol = c;
          } else if (dsCol == null &&
              (h.contains('descri') ||
                  h.contains('historic') ||
                  h.contains('titulo') ||
                  h == 'title' ||
                  h.contains('lancamento') ||
                  h.contains('estabelecimento') ||
                  h.contains('memo') ||
                  h == 'nome')) {
            dsCol = c;
          } else if (exCol == null &&
              (h.contains('descri') ||
                  h.contains('historic') ||
                  h.contains('detalhe') ||
                  h.contains('complemento') ||
                  h.contains('favorecido') ||
                  h.contains('estabelecimento') ||
                  h.contains('titulo'))) {
            exCol = c;
          }
        }

        if (dCol != null && (aCol != null || cCol != null || dbCol != null)) {
          sep = candidate;
          headerIdx = i;
          dateCol = dCol;
          descCol = dsCol;
          extraDescCol = exCol;
          amountCol = aCol;
          creditCol = cCol;
          debitCol = dbCol;
          typeCol = tCol;
          balanceCol = bCol;
          // Nubank fatura CSV has exact columns: date,title,amount (positive = expense)
          if (norms.contains('title') &&
              norms.contains('amount') &&
              !norms.any((h) => h.contains('saldo'))) {
            looksCard = true;
          }
          break;
        }
      }
      if (headerIdx != -1) break;
    }

    if (headerIdx == -1) {
      return StatementParseResult(
        items: const [],
        detectedBank: bank,
        looksLikeCard: looksCard,
        format: StatementFormat.csv,
        ignoredBalanceLines: 0,
        fileName: fileName,
      );
    }

    final items = <ParsedTxn>[];
    var ignoredBalances = 0;

    // Check metadata lines above header for ignored balance info (e.g. "Saldo;2500,00")
    for (var i = 0; i < headerIdx; i++) {
      if (isBalanceOrSummaryLine(rawLines[i])) ignoredBalances++;
    }

    for (var i = headerIdx + 1; i < rawLines.length; i++) {
      final cols = _splitCsvRow(rawLines[i], sep);
      if (cols.length <= dateCol!) continue;

      final date = _parseDate(cols[dateCol], refYear);
      if (date == null) {
        if (isBalanceOrSummaryLine(rawLines[i])) ignoredBalances++;
        continue;
      }

      final descParts = <String>[];
      if (descCol != null && descCol < cols.length && cols[descCol].trim().isNotEmpty) {
        descParts.add(cols[descCol].trim());
      }
      if (extraDescCol != null &&
          extraDescCol < cols.length &&
          cols[extraDescCol].trim().isNotEmpty &&
          !descParts.any((p) => p.toLowerCase() == cols[extraDescCol!].trim().toLowerCase())) {
        descParts.add(cols[extraDescCol].trim());
      }
      final rawDesc = descParts.join(' - ').trim();

      if (rawDesc.isNotEmpty && isBalanceOrSummaryLine(rawDesc)) {
        ignoredBalances++;
        continue;
      }

      // Note: balanceCol is intentionally ignored!
      final _ = balanceCol;

      _ParsedMoney? money;
      if (amountCol != null && amountCol < cols.length) {
        money = _parseMoneyToken(cols[amountCol]);
      }
      if ((money == null || money.value == 0) &&
          debitCol != null &&
          debitCol < cols.length) {
        final d = _parseMoneyToken(cols[debitCol]);
        if (d != null && d.value > 0) {
          money = _ParsedMoney(d.value, _Sign.negative);
        }
      }
      if ((money == null || money.value == 0) &&
          creditCol != null &&
          creditCol < cols.length) {
        final c = _parseMoneyToken(cols[creditCol]);
        if (c != null && c.value > 0) {
          money = _ParsedMoney(c.value, _Sign.positive);
        }
      }

      if (money == null || money.value <= 0) continue;

      final typeHint = (typeCol != null && typeCol < cols.length)
          ? _normalize(cols[typeCol])
          : '';

      final kind = _resolveKind(
        sign: money.sign,
        description: rawDesc,
        typeHint: typeHint,
        looksLikeCard: looksCard,
        sectionHint: null,
      );

      final title = cleanDescription(rawDesc.isEmpty ? 'Lançamento' : rawDesc);
      final inst = _extractInstallmentLabel(rawDesc);
      final (catId, subId) = categorize(rawDesc, kind);

      items.add(
        ParsedTxn(
          id: _nextId(),
          date: date,
          title: title,
          rawLine: rawLines[i],
          amount: money.value,
          kind: kind,
          categoryId: catId,
          subId: subId,
          installmentLabel: inst,
        ),
      );
    }

    return StatementParseResult(
      items: items,
      detectedBank: bank,
      looksLikeCard: looksCard,
      format: StatementFormat.csv,
      ignoredBalanceLines: ignoredBalances,
      fileName: fileName,
    );
  }

  static List<String> _splitCsvRow(String line, String sep) {
    final result = <String>[];
    final buf = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == sep && !inQuotes) {
        result.add(buf.toString().trim());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    result.add(buf.toString().trim());
    return result;
  }

  // ---------------------------------------------------------------- universal text / PDF parser

  static StatementParseResult parseText(
    String text, {
    String? fileName,
    StatementFormat format = StatementFormat.text,
    DateTime? referenceDate,
  }) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((l) => l.replaceAll('\u00A0', ' ').trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final bank = detectBank(text) ?? detectBank(fileName ?? '');
    final looksCard = detectIsCard(text) || detectIsCard(fileName ?? '');
    final refYear = _detectReferenceYear(text, referenceDate);

    final items = <ParsedTxn>[];
    var ignoredBalances = 0;

    DateTime? currentDate;
    Kind? sectionHint; // tracks "Entradas" vs "Saídas" blocks (e.g. Nubank PDF)
    String? pendingDesc; // buffered description line before a value-only line

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final norm = _normalize(line);

      // 1) Update section context from summary headers ("Total de entradas", "Total de saídas", etc.)
      if (_isIncomeSectionHeader(norm)) {
        sectionHint = Kind.income;
        ignoredBalances++;
        pendingDesc = null;
        continue;
      }
      if (_isExpenseSectionHeader(norm)) {
        sectionHint = Kind.expense;
        ignoredBalances++;
        pendingDesc = null;
        continue;
      }

      // 2) Reject standalone balance & summary lines (e.g. "Saldo em conta", "Saldo do dia", "S A L D O", "Saldo anterior")
      if (isBalanceOrSummaryLine(line)) {
        ignoredBalances++;
        pendingDesc = null;
        continue;
      }

      // 3) Check for a date-only section header line (e.g. "05 MAI 2026" or "12/05/2026")
      final dateMatch = _findLeadingDate(line, refYear);
      final moneys = _extractMoneyMatches(line);

      if (dateMatch != null && moneys.isEmpty) {
        final rest = line.substring(dateMatch.end).trim();
        currentDate = dateMatch.date;
        sectionHint = null;
        if (rest.isEmpty || _isNoiseLine(_normalize(rest))) {
          pendingDesc = null;
        } else if (!isBalanceOrSummaryLine(rest)) {
          // Date + description on this line, value might be on the next line.
          pendingDesc = rest;
        }
        continue;
      }

      // 4) Line has at least one monetary amount -> potential transaction!
      if (moneys.isNotEmpty) {
        final txnDate = dateMatch?.date ?? currentDate;
        if (dateMatch != null) {
          currentDate = dateMatch.date;
          sectionHint = null;
        }

        if (txnDate == null) {
          // Money without any date context yet (e.g. document header total/limit)
          pendingDesc = null;
          continue;
        }

        // Select the transaction money match, discarding any trailing running-balance column!
        final chosen = _pickTransactionAmount(moneys);
        if (chosen.money.value <= 0) {
          pendingDesc = null;
          continue;
        }

        // Build description from the text between the date (if any) and the first money match.
        final startPos = dateMatch?.end ?? 0;
        final endPos = moneys.first.start;
        var rawDesc = startPos < endPos
            ? line.substring(startPos, endPos).trim()
            : '';

        if (rawDesc.isEmpty && pendingDesc != null) {
          rawDesc = pendingDesc;
        }
        pendingDesc = null;

        // Strip leading doc/time tokens like "14:32" or "001234"
        rawDesc = _stripLeadingNoise(rawDesc);

        // Final check: does the extracted description represent a balance/summary row?
        if (rawDesc.isEmpty || isBalanceOrSummaryLine(rawDesc)) {
          ignoredBalances++;
          continue;
        }
        if (_isNoiseLine(_normalize(rawDesc))) continue;

        final kind = _resolveKind(
          sign: chosen.money.sign,
          description: rawDesc,
          typeHint: '',
          looksLikeCard: looksCard,
          sectionHint: sectionHint,
        );

        final title = cleanDescription(rawDesc);
        final inst = _extractInstallmentLabel(rawDesc);
        final (catId, subId) = categorize(rawDesc, kind);

        items.add(
          ParsedTxn(
            id: _nextId(),
            date: txnDate,
            title: title,
            rawLine: line,
            amount: chosen.money.value,
            kind: kind,
            categoryId: catId,
            subId: subId,
            installmentLabel: inst,
          ),
        );
        continue;
      }

      // 5) Line has NO date and NO money:
      //    Either it's a counterparty detail line right after a generic transaction
      //    (very common in Nubank/Inter PDFs: "Compra no débito 85,90" \n "SUPERMERCADO EXTRA")
      //    or a description line preceding a value-only line.
      if (!_isNoiseLine(norm)) {
        if (items.isNotEmpty &&
            currentDate != null &&
            items.last.date == currentDate &&
            _isGenericTitle(items.last.title) &&
            !_looksLikeHeaderOrFooter(norm)) {
          final detail = _cleanCounterpartyDetail(line);
          if (detail.isNotEmpty) {
            final combinedRaw = '${items.last.rawLine} · $detail';
            final enrichedTitle = _combineGenericAndDetail(items.last.title, detail);
            final (catId, subId) = categorize(combinedRaw, items.last.kind);
            items.last.title = enrichedTitle;
            items.last.categoryId = catId;
            items.last.subId = subId;
            continue;
          }
        }
        if (currentDate != null && !_looksLikeHeaderOrFooter(norm)) {
          pendingDesc = pendingDesc == null ? line : '$pendingDesc $line';
          if (pendingDesc.length > 140) pendingDesc = null;
        }
      }
    }

    return StatementParseResult(
      items: items,
      detectedBank: bank,
      looksLikeCard: looksCard,
      format: format,
      ignoredBalanceLines: ignoredBalances,
      fileName: fileName,
    );
  }

  /// Marks items that match an existing transaction (same day, amount and kind) in [store].
  static void markDuplicates(List<ParsedTxn> items, Store store) {
    for (final item in items) {
      item.possibleDuplicate = store.hasSimilarTxn(
        item.date,
        item.amount,
        item.kind,
      );
    }
  }

  // ---------------------------------------------------------------- balance & summary filters

  /// Returns true if [line] represents an account balance ("saldo em conta",
  /// "saldo do dia", "saldo anterior", "S A L D O", etc.) or a statement total/summary
  /// that must NOT be imported as a transaction.
  static bool isBalanceOrSummaryLine(String line) {
    final norm = _normalize(line);
    if (norm.isEmpty) return false;

    // Guard: legitimate transactions that happen to mention "saldo" (e.g. "Recarga saldo celular").
    final isRealTxnWord = norm.contains('recarga') ||
        norm.contains('adicao de saldo') ||
        norm.contains('compra') ||
        norm.contains('pix') ||
        norm.contains('boleto');

    if (!isRealTxnWord) {
      // Standard balance words: saldo, sdo, sld
      if (RegExp(r'\b(saldo|sdo|sld)\b').hasMatch(norm)) return true;

      // Spaced-out Banco do Brasil style: "S A L D O"
      final compact = norm.replaceAll(RegExp(r'[^a-z]'), '');
      if (compact == 'saldo' ||
          compact.startsWith('saldoanterior') ||
          compact.startsWith('saldododia') ||
          compact.startsWith('saldoemconta') ||
          compact.startsWith('saldofinal') ||
          compact.startsWith('saldoinicial') ||
          compact.startsWith('saldoatual') ||
          compact.startsWith('saldodisponivel') ||
          compact.startsWith('saldobloqueado') ||
          compact.startsWith('saldototal')) {
        return true;
      }
    }

    // Summary / total / credit limit lines (not actual transactions)
    const summaryPhrases = [
      'total de entradas',
      'total de saidas',
      'total entradas',
      'total saidas',
      'total do dia',
      'total do periodo',
      'total geral',
      'total lancamentos',
      'total movimentado',
      'total de movimentacoes',
      'total da fatura',
      'total a pagar',
      'total dos lancamentos',
      'total de debitos',
      'total de creditos',
      'subtotal',
      'sub-total',
      'valor total da fatura',
      'valor total',
      'resumo do periodo',
      'resumo financeiro',
      'resumo da fatura',
      'resumo das movimentacoes',
      'movimentacao do periodo',
      'limite disponivel',
      'limite total',
      'limite de credito',
      'limite cheque especial',
      'cheque especial',
      'lis disponivel',
      'lis contratado',
      'credito pre-aprovado',
      'pagamento minimo',
      'a transportar',
      'transportado',
      'rendimento liquido',
      'rendimento bruto',
      'rendimento no periodo',
      'rendimento acumulado',
      'fatura anterior',
      'saldo financiado',
    ];
    for (final p in summaryPhrases) {
      if (norm.contains(p)) return true;
    }

    // Bare "total" / "totais" line (e.g. "TOTAL   1.450,00")
    if (RegExp(r'^(\d{1,2}/\d{1,2}(/\d{2,4})?\s+)?totais?\b').hasMatch(norm)) {
      return true;
    }

    return false;
  }

  static bool _isIncomeSectionHeader(String norm) =>
      norm.startsWith('total de entradas') ||
      norm == 'entradas' ||
      norm == 'creditos';

  static bool _isExpenseSectionHeader(String norm) =>
      norm.startsWith('total de saidas') ||
      norm == 'saidas' ||
      norm == 'debitos';

  static bool _isNoiseLine(String norm) {
    if (norm.length <= 1) return true;
    const exactNoise = {
      'data',
      'descricao',
      'historico',
      'lancamento',
      'lancamentos',
      'valor',
      'saldo',
      'documento',
      'docto',
      'extrato',
      'movimentacoes',
    };
    if (exactNoise.contains(norm)) return true;
    return _looksLikeHeaderOrFooter(norm);
  }

  static bool _looksLikeHeaderOrFooter(String norm) {
    const prefixes = [
      'extrato de conta',
      'extrato bancario',
      'extrato consolidado',
      'extrato mensal',
      'extrato da conta',
      'periodo:',
      'periodo ',
      'agencia:',
      'conta:',
      'cpf:',
      'cnpj:',
      'titular:',
      'cliente:',
      'ouvidoria',
      'sac ',
      'sac:',
      'central de atendimento',
      'pagina ',
      'pag. ',
      'emitido em',
      'emissao:',
      'data de emissao',
      'valores em reais',
      'valores expressos em',
      'nu pagamentos',
      'banco inter s.a',
      'itau unibanco',
      'banco bradesco',
      'banco santander',
      'banco do brasil s.a',
      'caixa economica federal',
      'tem alguma duvida',
      'atendimento 24h',
    ];
    for (final p in prefixes) {
      if (norm.startsWith(p)) return true;
    }
    if (RegExp(r'^(pagina|pag\.?)\s*\d+\s*(de|/)\s*\d+$').hasMatch(norm)) {
      return true;
    }
    return false;
  }

  // ---------------------------------------------------------------- bank & card detection

  static String? detectBank(String text) {
    final n = _normalize(text);
    const banks = <(String, List<String>)>[
      ('Nubank', ['nubank', 'nu pagamentos', 'nu financeira', 'nuconta']),
      ('Banco Inter', ['banco inter', 'inter s.a', 'inter medium', 'conta digital inter', 'inter & co']),
      ('Itaú', ['itau', 'unibanco', 'itaucard', 'iti itau']),
      ('Bradesco', ['bradesco']),
      ('Santander', ['santander']),
      ('Banco do Brasil', ['banco do brasil', 'bb.com.br', 'ourocard']),
      ('Caixa', ['caixa economica', 'caixa tem']),
      ('C6 Bank', ['c6 bank', 'banco c6', 'c6bank']),
      ('BTG Pactual', ['btg pactual', 'btg+']),
      ('PicPay', ['picpay']),
      ('Mercado Pago', ['mercado pago', 'mercadopago']),
      ('PagBank', ['pagbank', 'pagseguro']),
      ('Neon', ['banco neon', 'neon pagamentos']),
      ('XP', ['banco xp', 'xp investimentos']),
      ('Sicoob', ['sicoob']),
      ('Sicredi', ['sicredi']),
      ('Will Bank', ['will bank', 'will financeira']),
      ('Banrisul', ['banrisul']),
      ('Next', ['banco next']),
      ('Banco Pan', ['banco pan']),
      ('Banco Original', ['banco original']),
      ('Safra', ['banco safra']),
      ('Stone', ['stone pagamentos', 'conta stone']),
      ('Cora', ['cora scd', 'banco cora']),
      ('Nomad', ['nomad']),
      ('Sofisa Direto', ['sofisa']),
    ];
    for (final b in banks) {
      for (final kw in b.$2) {
        if (n.contains(kw)) return b.$1;
      }
    }
    return null;
  }

  static bool detectIsCard(String text) {
    final n = _normalize(text);
    const cardKeywords = [
      'fatura do cartao',
      'fatura mensal',
      'extrato de cartao',
      'cartao de credito',
      'vencimento da fatura',
      'resumo da fatura',
      'total da fatura',
      'pagamento minimo',
      'melhor dia de compra',
      'itaucard',
      'ourocard',
      'credicard',
      'limite de credito',
    ];
    return cardKeywords.any(n.contains);
  }

  // ---------------------------------------------------------------- date helpers

  static const _monthsMap = <String, int>{
    'jan': 1, 'janeiro': 1,
    'fev': 2, 'feb': 2, 'fevereiro': 2,
    'mar': 3, 'marco': 3,
    'abr': 4, 'apr': 4, 'abril': 4,
    'mai': 5, 'may': 5, 'maio': 5,
    'jun': 6, 'junho': 6,
    'jul': 7, 'julho': 7,
    'ago': 8, 'aug': 8, 'agosto': 8,
    'set': 9, 'sep': 9, 'setembro': 9,
    'out': 10, 'oct': 10, 'outubro': 10,
    'nov': 11, 'novembro': 11,
    'dez': 12, 'dec': 12, 'dezembro': 12,
  };

  static int _detectReferenceYear(String text, DateTime? referenceDate) {
    final now = referenceDate ?? DateTime.now();
    // Look for an explicit 4-digit year in dates like DD/MM/2026 or 2026-MM-DD or "MAI 2026"
    final m1 = RegExp(r'\b\d{1,2}[/-]\d{1,2}[/-](20\d{2})\b').firstMatch(text);
    if (m1 != null) return int.parse(m1.group(1)!);
    final m2 = RegExp(r'\b(20\d{2})-\d{2}-\d{2}\b').firstMatch(text);
    if (m2 != null) return int.parse(m2.group(1)!);
    final m3 = RegExp(
      r'\b(jan|fev|mar|abr|mai|jun|jul|ago|set|out|nov|dez)[a-zç]*\s+(?:de\s+)?(20\d{2})\b',
      caseSensitive: false,
    ).firstMatch(_normalize(text));
    if (m3 != null) return int.parse(m3.group(2)!);
    return now.year;
  }

  static ({DateTime date, int end})? _findLeadingDate(String line, int refYear) {
    final norm = _normalize(line);

    // 1. YYYY-MM-DD
    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:\b|T|\s)').firstMatch(norm);
    if (iso != null) {
      final d = _validDate(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
      );
      if (d != null) return (date: d, end: iso.end);
    }

    // 2. DD/MM/YYYY or DD/MM/YY or DD.MM.YYYY or DD-MM-YYYY
    final dmy = RegExp(r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4})\b').firstMatch(norm);
    if (dmy != null) {
      var y = int.parse(dmy.group(3)!);
      if (y < 100) y += 2000;
      final d = _validDate(y, int.parse(dmy.group(2)!), int.parse(dmy.group(1)!));
      if (d != null) return (date: d, end: dmy.end);
    }

    // 3. DD MMM YYYY or DD de MMMM de YYYY or DD MMM
    final txtDate = RegExp(
      r'^(\d{1,2})\s+(?:de\s+)?(janeiro|fevereiro|marco|abril|maio|junho|julho|agosto|setembro|outubro|novembro|dezembro|jan|fev|feb|mar|abr|apr|mai|may|jun|jul|ago|aug|set|sep|out|oct|nov|dez|dec)\.?(?:\s+(?:de\s+)?(\d{2,4}))?\b',
    ).firstMatch(norm);
    if (txtDate != null) {
      final day = int.parse(txtDate.group(1)!);
      final month = _monthsMap[txtDate.group(2)!];
      var year = txtDate.group(3) != null ? int.parse(txtDate.group(3)!) : refYear;
      if (year < 100) year += 2000;
      if (month != null) {
        final d = _validDate(year, month, day);
        if (d != null) return (date: d, end: txtDate.end);
      }
    }

    // 4. DD/MM (without year, e.g. Itaú / Bradesco / Santander / BB)
    final dm = RegExp(r'^(\d{1,2})/(\d{1,2})(?=\s|$)').firstMatch(norm);
    if (dm != null) {
      final d = _validDate(refYear, int.parse(dm.group(2)!), int.parse(dm.group(1)!));
      if (d != null) return (date: d, end: dm.end);
    }

    return null;
  }

  static DateTime? _parseDate(String raw, int refYear) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return _findLeadingDate(trimmed, refYear)?.date;
  }

  static DateTime? _validDate(int y, int m, int d) {
    if (y < 2000 || y > 2100 || m < 1 || m > 12 || d < 1 || d > 31) return null;
    final dt = DateTime(y, m, d);
    if (dt.year != y || dt.month != m || dt.day != d) return null;
    return dt;
  }

  // ---------------------------------------------------------------- money helpers

  static final _moneyRegex = RegExp(
    r'(?:(?<![\S])[+\-−](?=R\$|\d)|(?<=^|\s{2})[+\-−]\s*(?=R\$|\d))?(?:R\$\s*)?(?:[+\-−]\s*)?(?:\()?(?<num>(?:\d{1,3}(?:\.\d{3})+,\d{2}|\d+,\d{2}|\d{1,3}(?:,\d{3})+\.\d{2}|\d+\.\d{2}))(?:\))?(?:[+\-−](?!\d)|\s*(?:\(\+\)|\(-\)|(?<![A-Za-z])[DC](?![A-Za-z])))?',
  );

  static final _pureUnsignedMoneyRegex = RegExp(
    r'^(?:\d{1,3}(?:\.\d{3})+,\d{2}|\d+,\d{2})$',
  );

  static List<_MoneyMatch> _extractMoneyMatches(String line) {
    final matches = <_MoneyMatch>[];
    for (final m in _moneyRegex.allMatches(line)) {
      // Avoid matching dates like 12.05 or version/doc numbers unless clearly money
      final full = m.group(0) ?? '';
      final numStr = m.namedGroup('num');
      if (numStr == null) continue;

      // Skip if immediately preceded or followed by '/' (part of a date or installment)
      if (m.start > 0 && line[m.start - 1] == '/') continue;
      if (m.end < line.length && line[m.end] == '/') continue;
      // Skip if attached to letters (like CPF/code)
      if (m.start > 0 && RegExp(r'[0-9]').hasMatch(line[m.start - 1])) continue;
      if (m.end < line.length && RegExp(r'[0-9]').hasMatch(line[m.end])) continue;

      final parsed = _parseMoneyToken(full);
      if (parsed == null) continue;
      matches.add(_MoneyMatch(m.start, m.end, parsed));
    }
    return matches;
  }

  /// When a statement line has multiple monetary values (e.g., Transaction Amount +
  /// Running Account Balance at the right edge), picks the transaction amount and
  /// ignores the running account balance.
  static _MoneyMatch _pickTransactionAmount(List<_MoneyMatch> matches) {
    if (matches.length == 1) return matches.first;

    // Classic bank layout: [Transaction Amount] [Running Balance]
    // Or 3 columns: [Credit] [Debit] [Running Balance]
    // Discard the rightmost column (running balance) and pick the last non-zero
    // value among the remaining columns (preferring signed values).
    final candidates = matches.sublist(0, matches.length - 1);
    final signedNonZero = candidates
        .where((c) => c.money.value > 0 && c.money.sign != _Sign.unsigned)
        .toList();
    if (signedNonZero.isNotEmpty) return signedNonZero.last;

    final nonZero = candidates.where((c) => c.money.value > 0).toList();
    if (nonZero.isNotEmpty) return nonZero.last;

    return matches.first;
  }

  static _ParsedMoney? _parseMoneyToken(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;

    var sign = _Sign.unsigned;
    if (s.contains('(-)') || s.startsWith('(') && s.endsWith(')')) {
      sign = _Sign.negative;
    } else if (s.contains('(+)')) {
      sign = _Sign.positive;
    } else if (RegExp(r'(?:^|\s)[−-]|R\$\s*[−-]|[−-]$').hasMatch(s)) {
      sign = _Sign.negative;
    } else if (RegExp(r'(?:^|\s)\+|R\$\s*\+|\+$').hasMatch(s)) {
      sign = _Sign.positive;
    } else if (RegExp(r'(?:\s|\d)D$', caseSensitive: false).hasMatch(s)) {
      sign = _Sign.negative;
    } else if (RegExp(r'(?:\s|\d)C$', caseSensitive: false).hasMatch(s)) {
      sign = _Sign.positive;
    }

    // Keep only digits, comma and dot
    final cleaned = s.replaceAll(RegExp(r'[^0-9.,]'), '');
    if (cleaned.isEmpty) return null;

    double? value;
    final lastComma = cleaned.lastIndexOf(',');
    final lastDot = cleaned.lastIndexOf('.');

    if (lastComma > lastDot) {
      // Brazilian format: 1.234,56
      value = double.tryParse(cleaned.replaceAll('.', '').replaceAll(',', '.'));
    } else if (lastDot > lastComma) {
      // US/CSV format: 1,234.56 or 1234.56
      final decimals = cleaned.length - lastDot - 1;
      if (decimals == 2) {
        value = double.tryParse(cleaned.replaceAll(',', ''));
      } else {
        // Likely thousands dot without cents (e.g. 1.234)
        value = double.tryParse(cleaned.replaceAll('.', ''));
      }
    } else {
      value = double.tryParse(cleaned);
    }

    if (value == null || value.isNaN || value.isInfinite) return null;
    // Reject implausibly large numbers (barcodes, doc IDs)
    if (value > 999999999.99) return null;
    return _ParsedMoney(value.abs(), sign);
  }

  // ---------------------------------------------------------------- kind & description helpers

  static Kind _resolveKind({
    required _Sign sign,
    required String description,
    required String typeHint,
    required bool looksLikeCard,
    required Kind? sectionHint,
  }) {
    final norm = _normalize('$description $typeHint');

    if (looksLikeCard) {
      // Credit card invoice: negative values or refund/credit keywords are income (credits/refunds);
      // normal unsigned/positive purchases are expenses.
      if (sign == _Sign.negative) return Kind.income;
      if (norm.contains('estorno') ||
          norm.contains('cashback') ||
          norm.contains('reembolso') ||
          norm.contains('devolucao') ||
          norm.contains('credito em fatura')) {
        return Kind.income;
      }
      return Kind.expense;
    }

    // Explicit sign or type column wins first
    if (sign == _Sign.negative) return Kind.expense;
    if (sign == _Sign.positive) return Kind.income;
    if (typeHint == 'd' ||
        typeHint.contains('debit') ||
        typeHint.contains('said') ||
        typeHint.contains('despes')) {
      return Kind.expense;
    }
    if (typeHint == 'c' ||
        typeHint.contains('credit') ||
        typeHint.contains('entrad') ||
        typeHint.contains('receit')) {
      return Kind.income;
    }

    // Section hint (e.g. Nubank PDF "Total de entradas" vs "Total de saídas")
    if (sectionHint != null) return sectionHint;

    // Description heuristics for unsigned bank account statements
    const incomeWords = [
      'pix recebido',
      'transferencia recebida',
      'transf recebida',
      'ted recebida',
      'doc recebida',
      'deposito',
      'salario',
      'folha pagto',
      'remuneracao',
      'rendimento',
      'dividendo',
      'jcp',
      'provento',
      'resgate',
      'estorno',
      'reembolso',
      'cashback',
      'devolucao',
      'recebimento',
      'credito em conta',
      'credito pix',
      'pagamento recebido',
    ];
    for (final w in incomeWords) {
      if (norm.contains(w)) return Kind.income;
    }

    const expenseWords = [
      'pix enviado',
      'transferencia enviada',
      'transf enviada',
      'ted enviada',
      'doc enviada',
      'compra',
      'pagamento de boleto',
      'pagamento efetuado',
      'pagamento fatura',
      'pagamento de fatura',
      'debito',
      'saque',
      'tarifa',
      'iof',
      'anuidade',
      'juros',
      'multa',
      'aplicacao',
      'boleto',
      'darf',
      'recarga',
      'fatura',
      'envio pix',
      'pagto',
      'pgto',
    ];
    for (final w in expenseWords) {
      if (norm.contains(w)) return Kind.expense;
    }

    return Kind.expense;
  }

  static String _stripLeadingNoise(String s) {
    var out = s.trim();
    // Strip leading time like "14:25" or "14:25:00"
    out = out.replaceFirst(RegExp(r'^\d{2}:\d{2}(?::\d{2})?\s*[-–]?\s*'), '');
    // Strip leading document numbers like "000123456 "
    out = out.replaceFirst(RegExp(r'^\d{5,}\s+'), '');
    return out.trim();
  }

  static String? _extractInstallmentLabel(String raw) {
    final m = RegExp(
      r'(?:parc(?:ela)?\.?\s*)?(\d{1,2})\s*(?:/|de)\s*(\d{1,2})\b',
      caseSensitive: false,
    ).firstMatch(raw);
    if (m == null) return null;
    final cur = int.tryParse(m.group(1)!);
    final tot = int.tryParse(m.group(2)!);
    if (cur == null || tot == null || tot < 2 || tot > 60 || cur < 1 || cur > tot) {
      return null;
    }
    // Avoid mistaking a date (e.g. 12/05 where cur > tot is already filtered,
    // also avoid 01/12..12/12 unless preceded by "parc" or common installment total)
    final hasParcWord = raw.toLowerCase().contains('parc');
    if (!hasParcWord && tot <= 12 && cur <= 31 && m.start < 6) return null;
    return '$cur/$tot';
  }

  static String cleanDescription(String raw) {
    var s = raw.trim();
    // Remove excess whitespace & trailing separators
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    // Remove masked CPF/CNPJ noise (e.g. "•••.123.456-••" or "12.345.678/0001-99")
    s = s.replaceAll(RegExp(r'[•*]{3}\.\d{3}\.\d{3}-[•*]{2}'), '');
    s = s.replaceAll(RegExp(r'\b\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2}\b'), '');
    s = s.replaceAll(RegExp(r'\b\d{3}\.\d{3}\.\d{3}-\d{2}\b'), '');
    // Remove standalone long document numbers (6+ digits)
    s = s.replaceAll(RegExp(r'\b\d{6,}\b'), '');
    // Replace merchant asterisk separators like "IFOOD *IFOOD" or "UBER *TRIP"
    s = s.replaceAll(RegExp(r'\s*\*\s*'), ' ');
    s = s.replaceAll(RegExp(r'\s*[-–|]+\s*$'), '');
    s = s.replaceAll(RegExp(r'^\s*[-–|]+\s*'), '');
    s = s.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

    if (s.isEmpty) return raw.trim();

    // If ALL CAPS (typical in Itaú/Bradesco/BB/Santander/Caixa), convert to clean title case
    final letters = s.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ]'), '');
    if (letters.isNotEmpty && letters == letters.toUpperCase()) {
      s = _toTitleCase(s);
    }

    if (s.length > 64) s = '${s.substring(0, 61).trim()}...';
    return s;
  }

  static String _toTitleCase(String input) {
    const keepLower = {'de', 'da', 'do', 'das', 'dos', 'e', 'em', 'na', 'no', 'com', 'para', 'por', 'a', 'o'};
    const keepUpper = {'PIX', 'TED', 'DOC', 'IOF', 'IPTU', 'IPVA', 'CDB', 'RDB', 'LCI', 'LCA', 'DARF', 'GPS', 'DAS', 'FII', 'JCP', 'MEI', 'LTDA', 'SA', 'BR', 'SP', 'RJ', 'MG'};

    final words = input.split(' ');
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      if (w.isEmpty) continue;
      final up = w.toUpperCase();
      if (keepUpper.contains(up)) {
        words[i] = up == 'PIX' ? 'Pix' : up;
      } else if (i > 0 && keepLower.contains(w.toLowerCase())) {
        words[i] = w.toLowerCase();
      } else {
        words[i] = w[0].toUpperCase() + w.substring(1).toLowerCase();
      }
    }
    return words.join(' ');
  }

  static bool _isGenericTitle(String title) {
    final n = _normalize(title);
    const generics = [
      'compra no debito',
      'compra no credito',
      'transferencia enviada pelo pix',
      'transferencia recebida pelo pix',
      'transferencia enviada',
      'transferencia recebida',
      'pix enviado',
      'pix recebido',
      'pagamento de boleto efetuado',
      'pagamento efetuado',
      'pagamento de fatura',
      'aplicacao rdb',
      'resgate rdb',
    ];
    return generics.contains(n);
  }

  static String _cleanCounterpartyDetail(String line) {
    // Nubank format: "NOME DA PESSOA - •••.123.456-•• - BANCO XYZ (0260) Agência: ..."
    var part = line.split(RegExp(r'\s+-\s+[•*\d]')).first.trim();
    part = part.split(RegExp(r'\bAg[eê]ncia:', caseSensitive: false)).first.trim();
    return cleanDescription(part);
  }

  static String _combineGenericAndDetail(String generic, String detail) {
    final n = _normalize(generic);
    if (n.contains('pix')) return 'Pix · $detail';
    if (n.contains('boleto')) return 'Boleto · $detail';
    if (n.contains('transferencia')) return 'Transf. · $detail';
    return detail;
  }

  // ---------------------------------------------------------------- auto-categorization

  /// Classifies a transaction into one of the app's [categories] and [Sub] ids.
  static (String categoryId, String? subId) categorize(
    String description,
    Kind kind,
  ) {
    final n = _normalize(description);

    if (kind == Kind.income) {
      return _categorizeIncome(n);
    }
    return _categorizeExpense(n);
  }

  static (String, String?) _categorizeIncome(String n) {
    const rules = <(String, String?, List<String>)>[
      ('salario', '13', ['13o', 'decimo terceiro', '13 salario']),
      ('salario', 'ferias', ['ferias']),
      ('salario', 'bonus', ['bonus', 'plr', 'ppr', 'comissao', 'premiacao', 'gratificacao']),
      ('salario', 'mensal', ['salario', 'folha pagto', 'pagto salario', 'remuneracao', 'pro-labore', 'prolabore', 'holerite', 'vencimento', 'adiantamento salarial']),
      ('invest', 'dividendos', ['dividendo', 'jcp', 'juros sobre capital', 'provento', 'fii']),
      ('invest', 'rendimentos', ['rendimento', 'cdb', 'rdb', 'lci', 'lca', 'tesouro', 'selic', 'caixinha', 'cofrinho', 'cashback', 'juros cred', 'remuneracao conta']),
      ('invest', 'resgates', ['resgate', 'xp invest', 'nuinvest', 'clear', 'rico', 'corretora', 'avenue']),
      ('freela', 'consultoria', ['consultoria', 'assessoria', 'honorario']),
      ('freela', 'projetos', ['freela', 'freelance', 'projeto', 'servico prestado', 'nfse', 'nota fiscal']),
      ('vendas', 'usados', ['olx', 'enjoei']),
      ('vendas', 'negocio', ['maquininha', 'stone', 'cielo', 'getnet', 'sumup', 'venda', 'recebimento vendas']),
      ('outras_rec', 'reembolsos', ['estorno', 'reembolso', 'devolucao', 'ressarcimento', 'chargeback']),
      ('outras_rec', 'alugueis', ['aluguel', 'locacao']),
      ('outras_rec', 'presentes_rec', ['presente', 'aniversario']),
    ];

    for (final r in rules) {
      for (final kw in r.$3) {
        if (n.contains(kw)) return (r.$1, r.$2);
      }
    }
    return ('outras_rec', null);
  }

  static (String, String?) _categorizeExpense(String n) {
    const rules = <(String, String?, List<String>)>[
      // Alimentação
      ('alimentacao', 'delivery', ['ifood', 'rappi', 'aiqfome', 'ze delivery', 'ubereats', 'uber eats', '99food', '99 food', 'delivery']),
      ('alimentacao', 'mercado', [
        'supermercado', 'mercado', 'atacadao', 'assai', 'carrefour',
        'pao de acucar', 'extra ', ' extra', 'hortifruti', 'sacolao',
        'feira', 'acougue', 'padaria', 'panificadora', 'emporio', 'zaffari',
        'guanabara', 'savegnago', 'condor', 'angeloni', 'sonda', 'mambo',
        'oxxo', 'sam s club', 'sams club', 'atacarejo', 'hipermercado', 'minimercado',
      ]),
      ('alimentacao', 'restaurantes', [
        'restaurante', 'lanchonete', 'hamburgueria', 'pizzaria', 'churrascaria',
        'sushi', 'cafeteria', 'starbucks', 'mcdonalds', 'mc donalds', 'bk ',
        'burger king', 'kfc', 'subway', 'bobs', 'habibs', 'outback', 'madero',
        'coco bambu', 'giraffas', 'spoletto', 'dominos', 'sorveteria', 'acai',
        'bistro', 'cantina', 'pastelaria', 'doceria', 'confeitaria', 'cafe ',
      ]),

      // Transporte
      ('transporte', 'apps', ['uber', '99app', '99pop', '99 pop', '99 taxi', 'indriver', 'cabify', 'taxi', 'blablacar']),
      ('transporte', 'combustivel', ['posto', 'ipiranga', 'shell', 'petrobras', 'br mania', 'raizen', 'combustivel', 'gasolina', 'etanol', 'abastecimento']),
      ('transporte', 'estacionamento', ['estacionamento', 'estapar', 'indigo', 'zona azul', 'sem parar', 'veloe', 'conectcar', 'c6 tag', 'taggy', 'pedagio', 'ccr', 'ecorodovias']),
      ('transporte', 'publico', ['metro', 'cptm', 'bilhete unico', 'riocard', 'onibus', 'buser', 'clickbus', 'rodoviaria']),
      ('transporte', 'veiculo', ['oficina', 'mecanica', 'borracharia', 'auto pecas', 'detran', 'ipva', 'licenciamento', 'lava rapido', 'localiza', 'movida', 'unidas']),

      // Moradia
      ('moradia', 'aluguel', ['aluguel', 'quintoandar', 'quinto andar', 'imobiliaria', 'financiamento imob', 'habitacao']),
      ('moradia', 'condominio', ['condominio', 'taxa condominial']),
      ('moradia', 'contas', [
        'enel', 'cemig', 'copel', 'cpfl', 'light', 'eletropaulo', 'energisa',
        'equatorial', 'neoenergia', 'celpe', 'coelba', 'sabesp', 'sanepar',
        'copasa', 'cedae', 'embasa', 'compesa', 'comgas', 'naturgy',
        'energia eletrica', 'conta de luz', 'conta de agua', 'saneamento', 'gas ',
      ]),
      ('moradia', 'internet', ['vivo', 'claro', 'tim ', ' tim', 'oi movel', 'sky ', 'starlink', 'brisanet', 'algar', 'fibra', 'internet', 'telefonia', 'recarga celular', 'banda larga']),
      ('moradia', 'manutencao', ['leroy merlin', 'telhanorte', 'dicico', 'sodimac', 'obramax', 'material de construcao', 'eletricista', 'encanador', 'chaveiro', 'reforma']),

      // Assinaturas
      ('assinaturas', 'streaming', [
        'netflix', 'spotify', 'disney', 'hbo', 'prime video', 'amazon prime',
        'globoplay', 'apple tv', 'youtube', 'crunchyroll', 'paramount',
        'deezer', 'tidal', 'star+', 'max.com',
      ]),
      ('assinaturas', 'software', [
        'apple.com/bill', 'google one', 'google storage', 'icloud', 'microsoft 365',
        'office 365', 'adobe', 'chatgpt', 'openai', 'claude', 'anthropic',
        'github', 'notion', 'canva', 'figma', 'dropbox', '1password', 'aws', 'vercel',
      ]),
      ('assinaturas', 'clubes', ['meli+', 'assinatura', 'folha de s', 'estadao', 'uol ']),

      // Saúde
      ('saude', 'farmacia', [
        'drogaria', 'drogasil', 'raia', 'pague menos', 'panvel', 'drogaria sp',
        'drogarias pacheco', 'venancio', 'nissei', 'ultrafarma', 'farmacia',
        'araujo', 'manipulacao',
      ]),
      ('saude', 'plano', ['unimed', 'bradesco saude', 'sulamerica', 'amil', 'hapvida', 'notredame', 'intermedica', 'prevent senior', 'plano de saude']),
      ('saude', 'academia', ['smartfit', 'smart fit', 'bluefit', 'bio ritmo', 'bodytech', 'gympass', 'wellhub', 'totalpass', 'crossfit', 'pilates', 'academia']),
      ('saude', 'consultas', ['clinica', 'hospital', 'laboratorio', 'fleury', 'dasa', 'lavoisier', 'sabin', 'hermes pardini', 'medico', 'dentista', 'odonto', 'psicolog', 'fisioterap', 'dr consulta', 'otica']),

      // Educação
      ('educacao', 'cursos', ['udemy', 'coursera', 'alura', 'rocketseat', 'hotmart', 'kiwify', 'eduzz', 'cultura inglesa', 'wizard', 'cna', 'fisk', 'ccaa', 'open english', 'cambly', 'curso']),
      ('educacao', 'mensalidade', ['faculdade', 'universidade', 'colegio', 'puc', 'mackenzie', 'estacio', 'unip', 'anhanguera', 'fiap', 'insper', 'fgv', 'mensalidade']),
      ('educacao', 'livros', ['saraiva', 'livraria', 'papelaria', 'kalunga', 'kindle']),

      // Compras
      ('compras', 'roupas', ['renner', 'riachuelo', 'c&a', 'zara', 'hering', 'marisa', 'centauro', 'netshoes', 'nike', 'adidas', 'havaianas', 'arezzo', 'shein', 'dafiti', 'reserva', 'vestuario', 'calcado']),
      ('compras', 'eletronicos', [
        'kabum', 'pichau', 'terabyte', 'fast shop', 'apple store', 'samsung',
        'casas bahia', 'ponto frio', 'magazine luiza', 'magalu', 'americanas',
        'mercado livre', 'mercadolivre', 'amazon', 'shopee', 'aliexpress', 'submarino',
      ]),
      ('compras', 'casa', ['tok&stok', 'tokstok', 'mobly', 'madeira madeira', 'etna', 'havan', 'casa & video', 'moveis']),
      ('compras', 'presentes', ['floricultura', 'cacau show', 'kopenhagen', 'lindt', 'vivara', 'pandora', 'joalheria', 'presente']),

      // Lazer
      ('lazer', 'cinema', ['cinemark', 'kinoplex', 'uci ', 'cinepolis', 'ingresso.com', 'sympla', 'eventim', 'ticketmaster', 'teatro', 'cinema', 'show ']),
      ('lazer', 'jogos', ['steam', 'playstation', 'psn', 'xbox', 'nintendo', 'riot', 'epic games', 'nuuvem', 'blizzard', 'ea games']),
      ('lazer', 'bares', ['choperia', 'cervejaria', 'adega', 'balada', 'boate', 'boteco', 'pub ', 'bar ']),

      // Viagem
      ('viagem', 'passagens', ['latam', 'gol linhas', 'azul linhas', 'avianca', 'tap air', 'decolar', 'smiles', 'tudoazul', 'passagem aerea']),
      ('viagem', 'hospedagem', ['airbnb', 'booking', 'hotel', 'pousada', 'resort', 'hostel', 'trivago', 'ibis', 'accor']),
      ('viagem', 'passeios', ['cvc', 'turismo', 'agencia de viagem']),

      // Cuidados pessoais
      ('cuidados', 'beleza', ['salao', 'barbearia', 'cabeleireiro', 'manicure', 'pedicure', 'estetica', 'depilacao', 'spa ']),
      ('cuidados', 'higiene', ['boticario', 'natura', 'sephora', 'eudora', 'avon', 'perfumaria', 'cosmetico']),

      // Pets
      ('pets', 'racao', ['cobasi', 'petz', 'petlove', 'racao', 'agropecuaria']),
      ('pets', 'veterinario', ['veterinari', 'clinica vet', 'hospital vet']),
      ('pets', 'petshop', ['pet shop', 'petshop', 'banho e tosa']),

      // Família
      ('familia', 'escola', ['creche', 'bercario', 'material escolar']),
      ('familia', 'brinquedos', ['ri happy', 'pbkids', 'brinquedo', 'lego']),

      // Serviços e taxas
      ('servicos', 'impostos', ['darf', 'gps ', 'das ', 'iptu', 'irpf', 'tributo', 'imposto', 'receita federal', 'sefaz', 'prefeitura']),
      ('servicos', 'seguros', ['seguro', 'porto seguro', 'tokio marine', 'mapfre', 'allianz', 'liberty', 'zurich', 'previdencia']),
      ('servicos', 'juros', ['juros', 'multa', 'mora', 'encargo', 'rotativo']),
      ('servicos', 'tarifas', ['tarifa', 'anuidade', 'cesta de servicos', 'pacote servicos', 'manutencao conta', 'iof', 'taxa bancaria', 'ted ', 'doc ']),

      // Outros
      ('outros', 'doacoes', ['doacao', 'ong ', 'igreja', 'dizimo']),
    ];

    for (final r in rules) {
      for (final kw in r.$3) {
        if (n.contains(kw)) return (r.$1, r.$2);
      }
    }
    return ('outros', 'diversos');
  }

  // ---------------------------------------------------------------- text normalization

  static String _normalize(String input) {
    final lower = input.toLowerCase();
    final buf = StringBuffer();
    for (var i = 0; i < lower.length; i++) {
      final ch = lower[i];
      buf.write(switch (ch) {
        'á' || 'à' || 'â' || 'ã' || 'ä' => 'a',
        'é' || 'è' || 'ê' || 'ë' => 'e',
        'í' || 'ì' || 'î' || 'ï' => 'i',
        'ó' || 'ò' || 'ô' || 'õ' || 'ö' => 'o',
        'ú' || 'ù' || 'û' || 'ü' => 'u',
        'ç' => 'c',
        'ñ' => 'n',
        _ => ch,
      });
    }
    return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

enum _Sign { positive, negative, unsigned }

class _ParsedMoney {
  final double value;
  final _Sign sign;
  const _ParsedMoney(this.value, this.sign);
}

class _MoneyMatch {
  final int start;
  final int end;
  final _ParsedMoney money;
  const _MoneyMatch(this.start, this.end, this.money);
}
