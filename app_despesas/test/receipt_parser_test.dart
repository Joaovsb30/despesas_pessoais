import 'package:expenses/receipts/receipt_parser.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 11, 17, 12);
ReceiptData parse(String s) => ReceiptParser.parse(s, now: now);

void main() {
  test('Pix enviado estilo Nubank (rótulo e valor em linhas separadas)', () {
    final r = parse('''
Comprovante de
transferência
15 NOV 2026 - 14:32:10
Valor
R\$ 50,00
Tipo de transferência
Pix
Destino
Nome
PADARIA PAO QUENTE LTDA
CNPJ
12.345.678/0001-90
Instituição
BANCO DO BRASIL S.A.
Origem
Nome
Joao da Silva
''');
    expect(r.amountCents, 5000);
    expect(r.date, DateTime(2026, 11, 15));
    expect(r.payee, 'Padaria Pao Quente');
    expect(r.isIncome, isFalse);
    expect(r.kind, 'Pix');
    expect(r.categoryId, 'alimentacao');
    expect(r.title, 'Padaria Pao Quente');
  });

  test('Pix estilo Itaú (rótulo: valor na mesma linha)', () {
    final r = parse('''
Comprovante de transferência
Pix enviado
valor: R\$ 1.234,56
data da transferência: 10/11/2026
tipo de pagamento: Pix
dados do recebedor
nome: Imobiliaria Central
CPF/CNPJ: 12.345.678/0001-90
dados do pagador
nome: Maria Souza
''');
    expect(r.amountCents, 123456);
    expect(r.date, DateTime(2026, 11, 10));
    expect(r.payee, 'Imobiliaria Central');
    expect(r.categoryId, 'moradia');
    expect(r.isIncome, isFalse);
  });

  test('Pix recebido usa quem pagou e vira receita', () {
    final r = parse('''
Pix recebido
R\$ 300,00
Sábado, 15/11/2026 às 09:12
Quem pagou
Carlos Pereira
CPF ***.123.456-**
Quem recebeu
Maria Souza
''');
    expect(r.isIncome, isTrue);
    expect(r.amountCents, 30000);
    expect(r.payee, 'Carlos Pereira');
    expect(r.categoryId, 'outras_receitas');
    expect(r.date, DateTime(2026, 11, 15));
  });

  test('Boleto: usa valor pago (não o do documento) e data do pagamento (não o vencimento)', () {
    final r = parse('''
Comprovante de pagamento de boleto
Beneficiário: CEMIG DISTRIBUICAO S.A.
Código de barras 83640000001 2 21500138001 9
Data de vencimento 10/11/2026
Valor do documento R\$ 120,00
Juros/Multa R\$ 1,50
Valor pago R\$ 121,50
Data do pagamento 12/11/2026
''');
    expect(r.amountCents, 12150);
    expect(r.date, DateTime(2026, 11, 12));
    expect(r.kind, 'Boleto');
    expect(r.payee, 'Cemig Distribuicao');
    expect(r.categoryId, 'contas');
  });

  test('Maquininha de cartão', () {
    final r = parse('''
DROGARIA SAO PAULO
CNPJ 61.412.110/0001-55
VIA CLIENTE
CREDITO A VISTA
************1234
VALOR: R\$ 45,90
16/11/26 18:22 AUT 123456
''');
    expect(r.amountCents, 4590);
    expect(r.date, DateTime(2026, 11, 16));
    expect(r.payee, 'Drogaria Sao Paulo');
    expect(r.categoryId, 'saude');
    expect(r.kind, 'Cartão');
  });

  test('Cupom fiscal (NFC-e): total, ignorando tributos e troco', () {
    final r = parse('''
SUPERMERCADO BOM PRECO LTDA
Documento Auxiliar da Nota Fiscal de Consumidor Eletrônica
001 ARROZ 5KG 1 UN x 27,90 27,90
002 FEIJAO 1KG 2 UN x 8,50 17,00
Qtd. total de itens 3
Valor total R\$ 44,90
Desconto R\$ 0,00
Valor a pagar R\$ 44,90
Dinheiro 50,00
Troco R\$ 5,10
Valor aprox. tributos R\$ 8,12
Emissão: 14/11/2026 10:05:33
''');
    expect(r.amountCents, 4490);
    expect(r.date, DateTime(2026, 11, 14));
    expect(r.payee, 'Supermercado Bom Preco');
    expect(r.categoryId, 'mercado');
  });

  test('texto compartilhado sem rótulos pega o primeiro valor com R\$', () {
    final r = parse('Você enviou um Pix de R\$ 25,00 para Uber do Brasil em 16/11/2026');
    expect(r.amountCents, 2500);
    expect(r.date, DateTime(2026, 11, 16));
    expect(r.isIncome, isFalse);
    expect(r.payee, 'Uber do Brasil');
    expect(r.categoryId, 'transporte');
  });

  test('texto corrido de Pix recebido', () {
    final r = parse('Pix recebido de R\$ 150,00 em 16/11/2026. Quem pagou: Ana Lima');
    expect(r.isIncome, isTrue);
    expect(r.payee, 'Ana Lima');
    final r2 = parse('Você recebeu R\$ 80,00. Pix recebido de João Souza em 15/11/2026');
    expect(r2.payee, 'João Souza');
    expect(r2.amountCents, 8000);
  });

  test('sem valor reconhecível', () {
    final r = parse('foto qualquer\nsem números');
    expect(r.amountCents, isNull);
    expect(r.date, isNull);
    expect(r.title, 'Comprovante');
  });

  test('ignora datas inválidas e no futuro', () {
    final r = parse('Valor R\$ 10,00\n31/02/2026\n01/01/2030\n05/11/2026');
    expect(r.date, DateTime(2026, 11, 5));
  });
}
