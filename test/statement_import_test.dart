import 'dart:typed_data';

import 'package:finance_app/main.dart';
import 'package:finance_app/statement_parser.dart';
import 'package:finance_app/store.dart';
import 'package:finance_app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  group('StatementParser - Bancos Brasileiros e filtro de saldo', () {
    test('Nubank PDF/texto: ignora saldos/totais e enriquece descrição', () {
      const nubank = '''
Nu Pagamentos S.A. - Extrato de conta
Período: 01/05/2026 a 31/05/2026
Saldo inicial   2.000,00

05 MAI 2026
Total de entradas   + 5.000,00
Transferência recebida pelo Pix   5.000,00
EMPRESA TECH LTDA - 12.345.678/0001-99
Total de saídas   - 224,30
Compra no débito   185,40
SUPERMERCADO EXTRA
Compra no débito   38,90
UBER *TRIP
Saldo do dia   6.775,70

Saldo final do período   6.775,70
''';
      final res = StatementParser.parseText(nubank);
      expect(res.detectedBank, 'Nubank');
      expect(res.ignoredBalanceLines, greaterThanOrEqualTo(5));
      expect(res.items.length, 3);

      expect(res.items[0].date, DateTime(2026, 5, 5));
      expect(res.items[0].kind, Kind.income);
      expect(res.items[0].amount, closeTo(5000.0, 0.01));
      expect(res.items[0].title, contains('Empresa Tech'));

      expect(res.items[1].kind, Kind.expense);
      expect(res.items[1].amount, closeTo(185.40, 0.01));
      expect(res.items[1].categoryId, 'alimentacao');
      expect(res.items[1].subId, 'mercado');

      expect(res.items[2].kind, Kind.expense);
      expect(res.items[2].amount, closeTo(38.90, 0.01));
      expect(res.items[2].categoryId, 'transporte');
      expect(res.items[2].subId, 'apps');
    });

    test('Banco Inter: remove saldo corrente na mesma linha e linha de saldo do dia', () {
      const inter = '''
Banco Inter S.A. - Extrato de Conta Corrente
10/05/2026   Pix enviado - IFOOD RESTAURANTES   -R\$ 64,90   R\$ 2.435,10
10/05/2026   Saldo do dia   R\$ 2.435,10
11/05/2026   Pix recebido - Salário Mensal   +R\$ 4.200,00   R\$ 6.635,10
12/05/2026   Pagamento boleto ENEL ENERGIA   -R\$ 210,45   R\$ 6.424,65
''';
      final res = StatementParser.parseText(inter);
      expect(res.detectedBank, 'Banco Inter');
      expect(res.ignoredBalanceLines, greaterThanOrEqualTo(1));
      expect(res.items.length, 3);

      expect(res.items[0].amount, closeTo(64.90, 0.01));
      expect(res.items[0].kind, Kind.expense);
      expect(res.items[0].categoryId, 'alimentacao');
      expect(res.items[0].subId, 'delivery');

      expect(res.items[1].amount, closeTo(4200.00, 0.01));
      expect(res.items[1].kind, Kind.income);
      expect(res.items[1].categoryId, 'salario');

      expect(res.items[2].amount, closeTo(210.45, 0.01));
      expect(res.items[2].kind, Kind.expense);
      expect(res.items[2].categoryId, 'moradia');
      expect(res.items[2].subId, 'contas');
    });

    test('Itaú: sinal negativo à direita e ignora SDO CTA / SALDO DO DIA', () {
      const itau = '''
Itaú Unibanco S.A.
Período: 01/04/2026 a 30/04/2026
01/04   SALDO ANTERIOR   3.500,00
02/04   COMPRA DEBITO DROGASIL   89,90-
02/04   SALDO DO DIA   3.410,10
03/04   SDO CTA/APL AUTOMATICAS   3.410,10
04/04   PIX RECEBIDO FREELANCE PROJETO   1.200,00
04/04   SALDO EM CONTA   4.610,10
''';
      final res = StatementParser.parseText(itau);
      expect(res.detectedBank, 'Itaú');
      expect(res.ignoredBalanceLines, 4);
      expect(res.items.length, 2);

      expect(res.items[0].date, DateTime(2026, 4, 2));
      expect(res.items[0].amount, closeTo(89.90, 0.01));
      expect(res.items[0].kind, Kind.expense);
      expect(res.items[0].categoryId, 'saude');
      expect(res.items[0].subId, 'farmacia');

      expect(res.items[1].date, DateTime(2026, 4, 4));
      expect(res.items[1].amount, closeTo(1200.00, 0.01));
      expect(res.items[1].kind, Kind.income);
      expect(res.items[1].categoryId, 'freela');
    });

    test('Bradesco, Banco do Brasil e Caixa: D/C, (-)/(+), S A L D O e coluna de saldo', () {
      const bbCaixaBradesco = '''
Banco do Brasil S.A.
05/05/2026   Saldo Anterior   1.000,00 C
06/05/2026   000456   COMPRA POSTO SHELL   180,00 (-)   820,00 C
06/05/2026   S A L D O   820,00 C
07/05/2026   000789   DEPOSITO DINHEIRO   500,00 (+)   1.320,00 C
08/05/2026   001122   NETFLIX.COM   55,90 D   1.264,10 C
08/05/2026   SALDO EM 08/05/2026   1.264,10 C
''';
      final res = StatementParser.parseText(bbCaixaBradesco);
      expect(res.detectedBank, 'Banco do Brasil');
      expect(res.ignoredBalanceLines, 3);
      expect(res.items.length, 3);

      expect(res.items[0].amount, closeTo(180.0, 0.01));
      expect(res.items[0].kind, Kind.expense);
      expect(res.items[0].categoryId, 'transporte');
      expect(res.items[0].subId, 'combustivel');

      expect(res.items[1].amount, closeTo(500.0, 0.01));
      expect(res.items[1].kind, Kind.income);

      expect(res.items[2].amount, closeTo(55.90, 0.01));
      expect(res.items[2].kind, Kind.expense);
      expect(res.items[2].categoryId, 'assinaturas');
      expect(res.items[2].subId, 'streaming');
    });

    test('CSV (Banco Inter / Bradesco) com cabeçalho de metadados e coluna Saldo ignorada', () {
      const csv = '''
Extrato Conta Corrente;Banco Inter
Conta;1234567-8
Saldo;4520,50

Data Lançamento;Histórico;Descrição;Valor;Saldo
10/05/2026;Pix enviado;SmartFit Academia;-119,90;4400,60
10/05/2026;Saldo do dia;;4400,60;4400,60
11/05/2026;Pix recebido;Dividendos FII;240,00;4640,60
''';
      final res = StatementParser.parseCsv(csv);
      expect(res.detectedBank, 'Banco Inter');
      expect(res.items.length, 2);
      expect(res.ignoredBalanceLines, greaterThanOrEqualTo(2));

      expect(res.items[0].amount, closeTo(119.90, 0.01));
      expect(res.items[0].kind, Kind.expense);
      expect(res.items[0].categoryId, 'saude');
      expect(res.items[0].subId, 'academia');

      expect(res.items[1].amount, closeTo(240.00, 0.01));
      expect(res.items[1].kind, Kind.income);
      expect(res.items[1].categoryId, 'invest');
      expect(res.items[1].subId, 'dividendos');
    });

    test('CSV fatura de cartão Nubank (positivo = despesa, negativo = estorno)', () {
      const nubankCardCsv = '''
date,title,amount
2026-05-10,Amazon Marketplace 02/06,150.00
2026-05-11,Estorno Loja X,-45.00
''';
      final res = StatementParser.parseCsv(nubankCardCsv, fileName: 'nubank_fatura.csv');
      expect(res.detectedBank, 'Nubank');
      expect(res.looksLikeCard, isTrue);
      expect(res.items.length, 2);

      expect(res.items[0].kind, Kind.expense);
      expect(res.items[0].amount, closeTo(150.0, 0.01));
      expect(res.items[0].installmentLabel, '2/6');
      expect(res.items[0].categoryId, 'compras');

      expect(res.items[1].kind, Kind.income);
      expect(res.items[1].amount, closeTo(45.0, 0.01));
      expect(res.items[1].categoryId, 'outras_rec');
      expect(res.items[1].subId, 'reembolsos');
    });

    test('OFX: extrai STMTTRN, detecta banco por COMPE e ignora LEDGERBAL', () {
      const ofx = '''
<OFX>
<BANKMSGSRSV1>
<STMTTRNRS>
<STMTRS>
<BANKACCTFROM>
<BANKID>0341
<ACCTID>12345
</BANKACCTFROM>
<BANKTRANLIST>
<STMTTRN>
<TRNTYPE>DEBIT
<DTPOSTED>20260515120000[-3:BRT]
<TRNAMT>-95.50
<MEMO>COBASI PET SHOP
</STMTTRN>
<STMTTRN>
<TRNTYPE>CREDIT
<DTPOSTED>20260516120000[-3:BRT]
<TRNAMT>320.00
<MEMO>RENDIMENTO CDB
</STMTTRN>
</BANKTRANLIST>
<LEDGERBAL>
<BALAMT>5200.00
<DTASOF>20260516
</LEDGERBAL>
</STMTRS>
</STMTTRNRS>
</BANKMSGSRSV1>
</OFX>
''';
      final res = StatementParser.parseOfx(ofx);
      expect(res.detectedBank, 'Itaú');
      expect(res.ignoredBalanceLines, 1);
      expect(res.items.length, 2);
      expect(res.items[0].categoryId, 'pets');
      expect(res.items[0].amount, closeTo(95.50, 0.01));
      expect(res.items[1].categoryId, 'invest');
      expect(res.items[1].kind, Kind.income);
    });

    test('PDF binário real: extrai tabela multi-coluna e descarta coluna Saldo', () async {
      final doc = PdfDocument();
      final page = doc.pages.add();
      final font = PdfStandardFont(PdfFontFamily.helvetica, 11);
      final g = page.graphics;

      g.drawString('Banco Santander Brasil - Extrato Mensal', font, bounds: const Rect.fromLTWH(20, 20, 450, 20));
      g.drawString('Data', font, bounds: const Rect.fromLTWH(20, 60, 80, 18));
      g.drawString('Descricao', font, bounds: const Rect.fromLTWH(110, 60, 200, 18));
      g.drawString('Valor', font, bounds: const Rect.fromLTWH(320, 60, 80, 18));
      g.drawString('Saldo', font, bounds: const Rect.fromLTWH(420, 60, 90, 18));

      // Row 1: Saldo anterior (must be ignored)
      g.drawString('01/05/2026', font, bounds: const Rect.fromLTWH(20, 90, 80, 18));
      g.drawString('SALDO ANTERIOR', font, bounds: const Rect.fromLTWH(110, 90, 200, 18));
      g.drawString('3.000,00', font, bounds: const Rect.fromLTWH(420, 90, 90, 18));

      // Row 2: Expense + running balance
      g.drawString('05/05/2026', font, bounds: const Rect.fromLTWH(20, 115, 80, 18));
      g.drawString('CARREFOUR HIPERMERCADO', font, bounds: const Rect.fromLTWH(110, 115, 200, 18));
      g.drawString('-342,80', font, bounds: const Rect.fromLTWH(320, 115, 80, 18));
      g.drawString('2.657,20', font, bounds: const Rect.fromLTWH(420, 115, 90, 18));

      // Row 3: Daily balance (must be ignored)
      g.drawString('05/05/2026', font, bounds: const Rect.fromLTWH(20, 140, 80, 18));
      g.drawString('SALDO EM CONTA', font, bounds: const Rect.fromLTWH(110, 140, 200, 18));
      g.drawString('2.657,20', font, bounds: const Rect.fromLTWH(420, 140, 90, 18));

      // Row 4: Income + running balance
      g.drawString('06/05/2026', font, bounds: const Rect.fromLTWH(20, 165, 80, 18));
      g.drawString('PIX RECEBIDO CLIENTE', font, bounds: const Rect.fromLTWH(110, 165, 200, 18));
      g.drawString('+950,00', font, bounds: const Rect.fromLTWH(320, 165, 80, 18));
      g.drawString('3.607,20', font, bounds: const Rect.fromLTWH(420, 165, 90, 18));

      final bytes = Uint8List.fromList(await doc.save());
      doc.dispose();

      final res = StatementParser.parseBytes(bytes, fileName: 'extrato_santander.pdf');
      expect(res.format, StatementFormat.pdf);
      expect(res.detectedBank, 'Santander');
      expect(res.ignoredBalanceLines, greaterThanOrEqualTo(2));
      expect(res.items.length, 2);

      expect(res.items[0].amount, closeTo(342.80, 0.01));
      expect(res.items[0].kind, Kind.expense);
      expect(res.items[0].categoryId, 'alimentacao');
      expect(res.items[0].subId, 'mercado');

      expect(res.items[1].amount, closeTo(950.00, 0.01));
      expect(res.items[1].kind, Kind.income);
    });
  });

  group('StatementImportScreen e confirmação antes de gravar', () {
    testWidgets('fluxo completo: analisa, revisa sem gravar e só salva ao confirmar', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 3;
      addTearDown(() {
        tester.view.reset();
        setDarkMode(false);
      });

      final store = Store.i..startOffline();
      final targetMonth = DateTime(2035, 8);
      final beforeCount = store.monthItemsFor(targetMonth).length;

      await tester.pumpWidget(const FinanceApp());
      await tester.pump(const Duration(seconds: 2));

      // Open from Transações tab upload button
      await tester.tap(find.text('Transações'));
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.byIcon(Icons.upload_file_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Importar extrato'), findsOneWidget);

      // Paste statement containing a daily balance line + 2 real transactions
      const sample = '''
Banco Inter S.A.
10/08/2035   SUPERMERCADO TESTE IMP   -150,00   2.850,00
10/08/2035   SALDO EM CONTA   2.850,00
11/08/2035   PIX RECEBIDO BONUS   +400,00   3.250,00
''';
      await tester.enterText(find.byType(TextField), sample);
      await tester.pump();
      await tester.ensureVisible(find.text('Analisar texto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Analisar texto'));
      await tester.pumpAndSettle();

      // Now on Confirmation Screen
      expect(find.text('Confirmar importação'), findsOneWidget);
      expect(find.text('1 saldo ignorado'), findsOneWidget);
      expect(find.text('2 de 2 selecionados'), findsOneWidget);

      // Nothing saved yet!
      expect(store.monthItemsFor(targetMonth).length, beforeCount);

      // Tap Confirm & Save
      await tester.tap(find.text('Confirmar e salvar 2 lançamentos'));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      // Now both transactions are saved in the Store (and the daily balance is NOT!)
      final after = store.monthItemsFor(targetMonth);
      expect(after.length, beforeCount + 2);
      expect(after.any((t) => t.amount == 2850.0), isFalse);
      expect(after.any((t) => t.amount == 150.0 && t.kind == Kind.expense), isTrue);
      expect(after.any((t) => t.amount == 400.0 && t.kind == Kind.income), isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}
