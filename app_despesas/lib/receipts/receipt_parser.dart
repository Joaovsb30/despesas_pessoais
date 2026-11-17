import '../state/expense_store.dart';
import '../utils/money.dart';

/// O que foi possível entender de um comprovante.
class ReceiptData {
  final int? amountCents;
  final DateTime? date;
  final String? payee;
  final bool isIncome;
  final String categoryId;

  /// Tipo do comprovante: Pix, Boleto, Cartão, Transferência ou null.
  final String? kind;

  const ReceiptData({
    this.amountCents,
    this.date,
    this.payee,
    this.isIncome = false,
    required this.categoryId,
    this.kind,
  });

  /// Descrição sugerida para o lançamento.
  String get title {
    if (payee != null) return payee!;
    switch (kind) {
      case 'Pix':
        return isIncome ? 'Pix recebido' : 'Pix enviado';
      case 'Boleto':
        return 'Pagamento de boleto';
      case 'Cartão':
        return 'Compra no cartão';
      case 'Transferência':
        return isIncome ? 'Transferência recebida' : 'Transferência enviada';
    }
    return isIncome ? 'Receita' : 'Comprovante';
  }
}

/// Lê o texto (de OCR ou compartilhado) de comprovantes de bancos brasileiros:
/// Pix, TED, boleto, maquininha de cartão e cupom/NFC-e.
class ReceiptParser {
  static final _money = RegExp(r'(?:R\$\s*)?(-?\d{1,3}(?:[.\s]\d{3})*,\d{2}|-?\d+,\d{2})(?!\d)');
  static final _moneyWithSymbol = RegExp(r'R\$\s*-?\d');

  static const _months = {
    'jan': 1, 'fev': 2, 'mar': 3, 'abr': 4, 'mai': 5, 'jun': 6,
    'jul': 7, 'ago': 8, 'set': 9, 'out': 10, 'nov': 11, 'dez': 12,
  };

  /// Rótulos de valor, do mais confiável para o menos.
  static const _amountLabels = [
    ['valor pago', 'valor do pagamento', 'total pago', 'valor cobrado'],
    ['valor a pagar', 'total a pagar', 'valor total', 'total geral', 'valor da compra', 'valor da transferencia', 'valor do pix', 'valor enviado', 'valor recebido'],
    ['total', 'valor'],
  ];

  /// Linhas com estas palavras não são o valor da transação.
  static const _notAmount = [
    'saldo', 'limite', 'tarifa', 'desconto', 'troco', 'juros', 'multa', 'tributos', 'imposto',
    'icms', 'ipi', 'pis', 'cofins', 'aprox', 'lei 12.741', 'valor do documento', 'cashback',
    'qtd', 'quantidade', 'unit', 'vl. item', 'subtotal',
  ];

  static const _payeeLabels = [
    'nome do recebedor', 'nome do favorecido', 'nome do beneficiario', 'quem recebeu', 'recebedor',
    'favorecido', 'beneficiario', 'destinatario', 'destino', 'para', 'estabelecimento', 'loja',
    'pago a', 'pagamento para', 'enviado para', 'transferido para', 'nome',
  ];

  static const _payerLabels = [
    'quem pagou', 'quem enviou', 'nome do pagador', 'pagador', 'origem', 'remetente', 'enviado por', 'de',
  ];

  static ReceiptData parse(String raw, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final lines = raw
        .split(RegExp(r'\r?\n'))
        .map((l) => l.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final norm = lines.map(ExpenseStore.normalize).toList();
    final all = norm.join('\n');

    final kind = _kind(all);
    final isIncome = _isIncome(all);
    final storeReceipt = kind == 'Cartão' ||
        const ['cnpj', 'cupom', 'nota fiscal', 'documento auxiliar', 'nfc-e'].any(all.contains);
    final payee = _payee(lines, norm, isIncome) ?? (storeReceipt ? _merchantHeader(lines, norm) : null);

    return ReceiptData(
      amountCents: _amount(lines, norm),
      date: _date(lines, norm, today),
      payee: payee,
      isIncome: isIncome,
      categoryId: guessCategory('$all\n${payee ?? ''}', isIncome: isIncome, kind: kind),
      kind: kind,
    );
  }

  // ------------------------------------------------------------------ tipo

  static String? _kind(String all) {
    if (RegExp(r'\bpix\b').hasMatch(all)) return 'Pix';
    if (all.contains('boleto') || all.contains('codigo de barras') || all.contains('linha digitavel')) {
      return 'Boleto';
    }
    if (RegExp(r'\b(ted|doc)\b').hasMatch(all) || all.contains('transferencia')) return 'Transferência';
    if (RegExp(r'\b(credito|debito)\b').hasMatch(all) &&
        (all.contains('via cliente') || all.contains('cartao') || all.contains('aut') || all.contains('nsu'))) {
      return 'Cartão';
    }
    return null;
  }

  static bool _isIncome(String all) {
    const incoming = [
      'pix recebido', 'voce recebeu', 'transferencia recebida', 'recebimento de pix', 'credito em conta',
      'quem pagou', 'quem enviou', 'deposito recebido', 'ted recebida', 'pagamento recebido',
    ];
    const outgoing = ['pix enviado', 'voce enviou', 'transferencia enviada', 'quem recebeu', 'pagamento efetuado', 'voce pagou'];
    final inc = incoming.where(all.contains).length;
    final out = outgoing.where(all.contains).length;
    return inc > out;
  }

  // ------------------------------------------------------------------ valor

  static List<int> _amountsIn(String line) {
    final out = <int>[];
    for (final m in _money.allMatches(line)) {
      final cents = parseMoney(m.group(1)!.replaceAll(' ', '.'));
      if (cents != null && cents > 0) out.add(cents);
    }
    return out;
  }

  static bool _hasLabel(String normLine, String label) =>
      RegExp('(^|[^a-z])${RegExp.escape(label)}(?![a-z])').hasMatch(normLine);

  static int? _amount(List<String> lines, List<String> norm) {
    bool excluded(int i) => _notAmount.any((w) => norm[i].contains(w));

    for (final group in _amountLabels) {
      for (var i = 0; i < lines.length; i++) {
        if (excluded(i) || !group.any((l) => _hasLabel(norm[i], l))) continue;
        final same = _amountsIn(lines[i]);
        if (same.isNotEmpty) return same.last;
        // Rótulo sozinho na linha ("Valor") e o número logo abaixo
        for (var j = i + 1; j < lines.length && j <= i + 2; j++) {
          if (excluded(j)) break;
          final next = _amountsIn(lines[j]);
          if (next.isNotEmpty) return next.first;
        }
      }
    }
    // Sem rótulo: o primeiro valor com "R$" que não seja saldo/tarifa etc.
    for (var i = 0; i < lines.length; i++) {
      if (excluded(i) || !_moneyWithSymbol.hasMatch(lines[i])) continue;
      final found = _amountsIn(lines[i]);
      if (found.isNotEmpty) return found.first;
    }
    return null;
  }

  // ------------------------------------------------------------------ data

  static List<DateTime> _datesIn(String normLine, DateTime today) {
    final out = <DateTime>[];
    for (final m in RegExp(r'(\d{1,2})[/.-](\d{1,2})[/.-](\d{4}|\d{2})(?!\d)').allMatches(normLine)) {
      var y = int.parse(m.group(3)!);
      if (y < 100) y += 2000;
      out.add(_safeDate(y, int.parse(m.group(2)!), int.parse(m.group(1)!)));
    }
    for (final m in RegExp(r'(\d{4})-(\d{2})-(\d{2})').allMatches(normLine)) {
      out.add(_safeDate(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!)));
    }
    for (final m in RegExp(r'(\d{1,2})(?: de)? ([a-z]{3})[a-z]*\.?(?: de)?,? (\d{4})').allMatches(normLine)) {
      final month = _months[m.group(2)];
      if (month != null) out.add(_safeDate(int.parse(m.group(3)!), month, int.parse(m.group(1)!)));
    }
    return out.where((d) => d.year > 2000 && !d.isAfter(today.add(const Duration(days: 1)))).toList();
  }

  static DateTime _safeDate(int y, int m, int d) {
    if (m < 1 || m > 12 || d < 1 || d > 31) return DateTime(0);
    final date = DateTime(y, m, d);
    return date.month == m ? date : DateTime(0); // 31/02 etc.
  }

  static DateTime? _date(List<String> lines, List<String> norm, DateTime today) {
    const preferred = ['data do pagamento', 'pago em', 'realizad', 'efetuad', 'data da transferencia', 'data da transacao', 'data'];
    const avoid = ['vencimento', 'validade', 'emissao do boleto', 'nascimento'];
    for (final label in preferred) {
      for (var i = 0; i < norm.length; i++) {
        if (!norm[i].contains(label) || avoid.any(norm[i].contains)) continue;
        for (var j = i; j < norm.length && j <= i + 1; j++) {
          final found = _datesIn(norm[j], today);
          if (found.isNotEmpty) return found.first;
        }
      }
    }
    for (var i = 0; i < norm.length; i++) {
      if (avoid.any(norm[i].contains)) continue;
      final found = _datesIn(norm[i], today);
      if (found.isNotEmpty) return found.first;
    }
    return null;
  }

  // ------------------------------------------------------------------ quem

  static bool _looksLikeName(String line, String normLine) {
    if (line.length < 3 || line.length > 60) return false;
    final letters = RegExp(r'[A-Za-zÀ-ÿ]').allMatches(line).length;
    if (letters < 3 || letters < line.replaceAll(' ', '').length * 0.6) return false;
    const notNames = [
      'cpf', 'cnpj', 'instituicao', 'banco', 'agencia', 'conta', 'chave', 'tipo', 'valor', 'data', 'id ',
      'autenticacao', 'comprovante', 'pix', 'transferencia', 'pagamento', 'r\$', 'horario', 'hora',
    ];
    return !notNames.any((w) => normLine.startsWith(w));
  }

  static String? _labeled(List<String> lines, List<String> norm, List<String> labels, {bool section = false}) {
    for (final label in labels) {
      for (var i = 0; i < lines.length; i++) {
        final n = norm[i];
        final idx = n.indexOf(label);
        if (idx != 0) continue;
        final rest = n.substring(label.length);
        // "Nome: Fulano" na mesma linha
        if (rest.startsWith(':') || rest.startsWith(' -') || (label.length > 4 && rest.startsWith(' '))) {
          final value = lines[i].substring(lines[i].length - rest.length).replaceFirst(RegExp(r'^[\s:\-]+'), '').trim();
          if (_looksLikeName(value, ExpenseStore.normalize(value))) return _clean(value);
        }
        if (rest.trim().isNotEmpty && rest.trim() != ':') continue;
        // Rótulo sozinho: o nome vem nas próximas linhas (pulando "Nome")
        for (var j = i + 1; j < lines.length && j <= i + 3; j++) {
          if (norm[j] == 'nome' || norm[j] == 'nome:') continue;
          if (_looksLikeName(lines[j], norm[j])) return _clean(lines[j]);
          if (!section) break;
        }
      }
    }
    return null;
  }

  static const _nameChars = r"[A-Za-zÀ-ÿ][A-Za-zÀ-ÿ0-9 .&'\-]{1,48}?";
  static const _nameEnd = r"(?=\s+(?:em|no|na|via|com|as|às|dia|valor|cpf|cnpj)\b|[,;.!]\s|[,;.!]?$|\s+-\s)";

  /// Texto corrido (ex.: compartilhado como mensagem): "Quem pagou: Ana", "para Uber", "recebido de Ana".
  static String? _inline(List<String> lines, bool isIncome) {
    final labels = isIncome
        ? ['quem pagou', 'quem enviou', 'pagador', 'remetente', 'origem', 'enviado por']
        : ['quem recebeu', 'recebedor', 'favorecido', 'beneficiário', 'beneficiario', 'destino', 'destinatário', 'estabelecimento'];
    final patterns = [
      for (final l in labels) RegExp('${RegExp.escape(l)}\\s*:\\s*($_nameChars)$_nameEnd', caseSensitive: false),
      if (isIncome) RegExp('recebid[oa] de\\s+(?!R\\\$)($_nameChars)$_nameEnd', caseSensitive: false)
      else RegExp('\\bpara\\s+(?!R\\\$|voc[eê]\\b|o\\s|a\\s)($_nameChars)$_nameEnd', caseSensitive: false),
    ];
    for (final re in patterns) {
      for (final line in lines) {
        final m = re.firstMatch(line);
        if (m != null) {
          final name = m.group(1)!.trim();
          if (_looksLikeName(name, ExpenseStore.normalize(name))) return _clean(name);
        }
      }
    }
    return null;
  }

  static String? _payee(List<String> lines, List<String> norm, bool isIncome) {
    if (isIncome) {
      return _labeled(lines, norm, _payerLabels, section: true) ?? _inline(lines, true);
    }
    // "Nome" sozinho também aparece no bloco de quem pagou; procurar dentro da seção de destino primeiro.
    final destStart = norm.indexWhere((n) => const ['destino', 'quem recebeu', 'recebedor', 'favorecido', 'beneficiario', 'dados do recebedor', 'para'].any((l) => n == l || n.startsWith('$l:') || n == 'dados do $l'));
    if (destStart >= 0) {
      final found = _labeled(lines.sublist(destStart), norm.sublist(destStart), _payeeLabels, section: true);
      if (found != null) return found;
    }
    return _labeled(lines, norm, _payeeLabels.where((l) => l != 'nome').toList(), section: true) ??
        _inline(lines, false);
  }

  /// Cupom fiscal / maquininha: o nome da loja costuma ser a primeira linha com letras.
  static String? _merchantHeader(List<String> lines, List<String> norm) {
    for (var i = 0; i < lines.length && i < 4; i++) {
      if (const ['comprovante', 'via cliente', 'documento auxiliar', 'cupom', 'nfc-e', 'danfe'].any(norm[i].contains)) continue;
      if (_looksLikeName(lines[i], norm[i])) return _clean(lines[i]);
    }
    return null;
  }

  static String _clean(String name) {
    var s = name.replaceAll(RegExp(r'\s+(ltda|eireli|me|s\.?a\.?|epp)\.?$', caseSensitive: false), '').trim();
    // NOMES EM CAIXA ALTA -> Nomes Em Caixa Alta
    if (s == s.toUpperCase()) {
      s = s.toLowerCase().split(' ').map((w) {
        if (w.length <= 2 && const ['de', 'da', 'do', 'e'].contains(w)) return w;
        return w.isEmpty ? w : w[0].toUpperCase() + w.substring(1);
      }).join(' ');
    }
    return s;
  }

  // ------------------------------------------------------------------ categoria

  static const _categoryWords = {
    'mercado': ['mercado', 'supermerc', 'atacad', 'assai', 'carrefour', 'hortifruti', 'sacolao', 'pao de acucar', 'extra hiper', 'big bompreco', 'sams club', 'dia brasil'],
    'alimentacao': ['restaurante', 'lanchonete', 'padaria', 'panificadora', 'ifood', 'pizz', 'burger', 'mcdonald', 'bk brasil', 'subway', 'acai', 'sorvet', 'cafe', 'bar e', 'churrasc', 'lanches', 'rappi', 'confeitaria', 'pastelaria'],
    'transporte': ['posto', 'combust', 'gasolina', 'uber', '99 tecnologia', '99app', 'estacionamento', 'shell', 'ipiranga', 'petrobras', 'br distribuidora', 'pedagio', 'sem parar', 'conectcar', 'metro', 'bilhete unico', 'veloe'],
    'saude': ['farmacia', 'drogaria', 'droga raia', 'drogasil', 'pague menos', 'panvel', 'hospital', 'clinica', 'laboratorio', 'odonto', 'unimed', 'hapvida', 'amil', 'medic'],
    'contas': ['energia', 'enel', 'cemig', 'copel', 'light s', 'coelba', 'celpe', 'equatorial', 'neoenergia', 'sabesp', 'saneamento', 'agua e esgoto', 'compesa', 'cedae', 'claro', 'vivo', 'telefonica', 'tim s', 'oi s', 'internet', 'telecom', 'gas natural', 'comgas', 'seguro'],
    'moradia': ['aluguel', 'condominio', 'imobiliaria', 'iptu'],
    'educacao': ['escola', 'colegio', 'faculdade', 'universidade', 'curso', 'livraria', 'udemy', 'alura'],
    'assinaturas': ['netflix', 'spotify', 'amazon prime', 'disney', 'hbo', 'max.com', 'youtube premium', 'globoplay', 'deezer', 'apple.com', 'google one', 'icloud'],
    'lazer': ['cinema', 'cinemark', 'ingresso', 'sympla', 'teatro', 'show', 'parque', 'steam', 'playstation', 'xbox'],
    'compras': ['magazine', 'magalu', 'americanas', 'mercado livre', 'mercadolivre', 'shopee', 'amazon', 'renner', 'riachuelo', 'c&a', 'cea modas', 'shein', 'casas bahia', 'kabum', 'aliexpress', 'leroy'],
  };

  static String guessCategory(String text, {required bool isIncome, String? kind}) {
    final t = ExpenseStore.normalize(text);
    if (isIncome) {
      if (t.contains('salario') || t.contains('folha de pagamento') || t.contains('vencimentos')) return 'salario';
      if (t.contains('rendimento') || t.contains('dividendo') || t.contains('resgate')) return 'investimentos';
      return 'outras_receitas';
    }
    for (final e in _categoryWords.entries) {
      if (e.value.any(t.contains)) return e.key;
    }
    return kind == 'Boleto' ? 'contas' : 'outros';
  }
}
