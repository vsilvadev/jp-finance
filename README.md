# 🇯🇵 Japão — gastos da viagem

Um app simples para acompanhar o dinheiro da sua viagem ao Japão: quanto foi colocado no orçamento, quanto já saiu e o que ainda resta em cada categoria. Feito para abrir rápido no celular e registrar gastos sem transformar a viagem em uma planilha.

Sem conta, sem backend e sem sincronização: os dados ficam no armazenamento local do aplicativo ou do navegador que você está usando.

## O que dá para fazer

O app tem três abas, com o botão **Novo gasto** sempre à mão:

| Aba | Para que serve |
| --- | --- |
| **Início** | Ver o total colocado, o saldo disponível e as categorias. Expanda uma categoria para conferir os três gastos mais recentes ou abra-a para ver todos. |
| **Conversão** | Converter JPY ↔ BRL usando uma cotação de referência diária, ou informar uma cotação manual. |
| **Você** | Conferir os cinco gastos recentes, exportar relatórios e fazer backup ou restauração dos dados. |

Também é possível criar categorias, definir e ajustar seus orçamentos, adicionar dinheiro ao orçamento da viagem, editar ou excluir gastos e apagar todos os dados locais pelo botão de lixeira.

### Regras do orçamento

- Todos os valores são guardados como números inteiros em ienes.
- O **total colocado** é a soma das entradas de dinheiro registradas.
- O **saldo da viagem** é calculado como total colocado menos todos os gastos.
- O valor gasto, o disponível e o percentual de cada categoria são calculados a partir do orçamento e dos gastos registrados.
- A soma dos orçamentos das categorias não pode passar do total colocado. Pode haver dinheiro sem categoria.
- Não é possível registrar um gasto maior que o orçamento restante da categoria.

### Relatórios e backup

- Exporte um PDF completo da viagem ou um relatório de uma categoria.
- Exporte um backup completo em JSON e importe-o para restaurar os dados. A importação substitui os dados locais após confirmação.
- O botão de lixeira apaga os dados locais após confirmação. Faça um backup antes de usar essa opção.

## Privacidade e armazenamento

O app não envia seus gastos, categorias ou orçamento para um servidor. Na versão Web, eles ficam no armazenamento do navegador para aquela origem e perfil. Por isso, outro aparelho ou navegador começa com seus próprios dados; limpar os dados do site ou do navegador pode apagar o banco. Use o backup JSON para manter uma cópia fora do dispositivo.

A aba Conversão consulta a API pública [Frankfurter](https://frankfurter.dev/) para obter uma taxa de referência JPY/BRL e a data da cotação. Essa consulta envia apenas o pedido da taxa; seus dados financeiros permanecem locais. A cotação de referência pode diferir da taxa cobrada por bancos, cartões e casas de câmbio. Sem internet, você ainda pode informar uma cotação manual.

## Começar a desenvolver

### Requisitos

- [Flutter](https://docs.flutter.dev/get-started/install) na versão indicada em `.fvmrc` (**3.47.6** neste projeto).
- [FVM](https://fvm.app/) para instalar e usar a versão correta do Flutter.
- Um navegador atualizado para executar a versão Web.

Na raiz do projeto, rode:

```powershell
fvm install
fvm flutter pub get
fvm flutter analyze
```

Para executar no navegador sem pedir ao Flutter para iniciar o Chrome/Edge:

```powershell
fvm flutter run -d web-server
```

Abra no navegador o endereço local exibido no terminal. Para executar como aplicativo Windows, com as ferramentas de compilação do Visual Studio instaladas:

```powershell
fvm flutter run -d windows
```

## Compilar para Web

Para testar um build local, use a base `/`. Para hospedar em um repositório de projeto do GitHub Pages, troque `NOME-DO-REPOSITORIO` pelo nome exato do repositório:

```powershell
fvm flutter build web --release --base-href "/NOME-DO-REPOSITORIO/"
fvm dart run tool/create_web_manifest.dart build/web
```

No repositório especial `USUARIO.github.io`, use `--base-href "/"`. O primeiro comando gera os arquivos estáticos em `build/web`; o segundo prepara o manifesto para ativar o suporte offline do service worker nesse build. Publique o conteúdo de `build/web` no GitHub Pages.

Para publicação automática pelo GitHub Actions, o repositório precisa incluir `.github/workflows/deploy.yml` e o Pages deve estar configurado para usar **GitHub Actions** em **Settings → Pages**. O workflow pode compilar e publicar o site a cada push para a branch configurada. Sem esse workflow no repositório, faça a publicação por outro método configurado no GitHub.

Para usar offline, abra o site e conclua um carregamento online antes da viagem. O navegador precisa guardar o app e o banco local. O modo privado, a limpeza dos dados do site e as políticas de armazenamento do navegador podem afetar a persistência. No iPhone, é possível abrir pelo Safari e usar **Compartilhar → Adicionar à Tela de Início**.

## Como o projeto está organizado

```text
lib/
├── app/             # configuração do app, navegação e estado compartilhado
├── core/            # banco local e tema
└── features/
    ├── budget/      # início e visão geral do orçamento
    ├── categories/  # categorias e orçamentos
    ├── conversion/  # conversor JPY/BRL
    ├── expenses/    # cadastro e consulta de gastos
    └── reports/     # PDF e backup JSON
```

O app usa Flutter/Dart, Material 3, GoRouter e Drift sobre SQLite. Na Web, o Drift usa SQLite compilado para WebAssembly e armazenamento do navegador. As principais tabelas guardam entradas de dinheiro, categorias e gastos; os saldos são derivados desses registros.

## Notas

- O app é dedicado a uma única viagem ao Japão; não inclui usuários, sincronização ou múltiplas viagens.
- Os recursos necessários para o banco Web, como `web/sqlite3.wasm` e `web/drift_worker.js`, fazem parte do runtime. Ao atualizar dependências relacionadas ao Drift/SQLite, confira também a compatibilidade desses arquivos.
- O backup JSON é a forma de transferir dados entre navegadores ou dispositivos; o banco local não sincroniza automaticamente.
