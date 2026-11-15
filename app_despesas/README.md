# Despesas Pessoais

App Android para controlar gastos pessoais. **Funciona 100% offline**: os dados ficam num banco SQLite no próprio celular, sem conta, sem nuvem, sem internet.

## O que faz

- Lançar gastos com valor, descrição, data, categoria e observação
- Editar (toque no gasto) e excluir (arraste para a esquerda, com "Desfazer")
- Navegar mês a mês, com total do mês e comparação com o mês anterior
- Orçamento mensal com barra de progresso (menu ⋮ → Orçamento mensal)
- Tela de resumo: total, média por dia, gastos por categoria e gráfico dos últimos 6 meses
- Exportar tudo em CSV para backup ou abrir no Excel/Sheets (menu ⋮ → Exportar CSV)

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
