# Despesas Pessoais

App Android para controlar gastos pessoais. **Funciona 100% offline**: os dados ficam num banco SQLite no próprio celular, sem conta, sem nuvem, sem internet.

## O que faz

- **Lançar a partir do comprovante**: no app do banco (ou WhatsApp, galeria, e-mail) toque em
  *Compartilhar → Despesas*, ou use o botão de scanner na tela inicial (foto, print ou PDF).
  O app lê o comprovante no próprio celular (sem internet), entende valor, data, quem recebeu/pagou,
  se é Pix enviado ou recebido, sugere a categoria e lança sozinho. A imagem fica guardada no lançamento.
  Se não achar o valor ou parecer repetido, abre o formulário preenchido para você conferir.
- Lançar **gastos e receitas** com valor, descrição, data, categoria e observação
- **Saldo do mês** (receitas − gastos) e comparação com o mês anterior
- **Lançamentos recorrentes** (aluguel, assinaturas, salário): criados sozinhos todo mês
- **Compras parceladas**: informe o total e o número de parcelas, uma por mês
- **Orçamento geral e por categoria**, com alerta na tela inicial quando um limite estoura
- **Busca** em todos os meses, ignorando acentos
- Editar (toque) e excluir (arraste para a esquerda, com "Desfazer")
- Resumo: gastos, média por dia, saldo, gastos por categoria e gráfico de 6 meses
- **Backup**: exportar e importar CSV (abre no Excel/Sheets)
- **Bloqueio com digital, rosto ou PIN** do celular

Tudo em Mais (⋮): Orçamentos, Recorrentes, Bloqueio e Backup.

## Como pegar o APK

O GitHub Actions compila o APK a cada push (`.github/workflows/build-apk.yml`, na raiz do repositório):

1. Abra a aba **Actions** do repositório → execução mais recente de **Gerar APK**
2. Baixe o artefato **despesas-apk** (vem em um .zip com o `despesas.apk` dentro)
3. Passe o `despesas.apk` para o celular e instale (o Android vai pedir para permitir "instalar apps desconhecidos")

Para gerar uma Release com o APK para download direto: crie uma tag `v*` (ex.: `git tag v2.0.0 && git push origin v2.0.0`).

### Atualizações sem perder dados

O APK é sempre assinado com a mesma chave (`android/app/despesas.keystore`), então uma versão nova instala por cima da anterior e mantém os gastos. **Não desinstale o app** para atualizar: desinstalar apaga o banco. Faça um export CSV antes, por garantia.

## Compilar localmente

Requer Flutter 3.47+ e Android SDK:

```bash
cd app_despesas
flutter pub get
flutter test
flutter build apk --release
# APK em build/app/outputs/flutter-apk/app-release.apk
```
