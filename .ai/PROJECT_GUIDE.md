# Guia de arquitetura e desenvolvimento de SentinelKit

## Escopo e fontes de verdade

SentinelKit é uma biblioteca Swift Package Manager para iOS 15+ que envia erros, mensagens e crashes ao Sentinel Lab.

As fontes deste checkout são, nesta ordem:

- AGENTS.md — regras de engenharia, coordenação e validação.
- PROJECT_BRIEF.md — produto, fluxos, estados e pendências.
- README.md — requisitos públicos e comandos.
- Código e configuração existentes — comportamento efetivamente conectado.

Não trate um tipo, string, pacote ou serviço sem callsite de produção como uma
feature disponível. Não faça migrações de nomes, pastas ou arquitetura sem
escopo explícito.

## Baseline efetiva

- Plataforma e versão mínima: iOS 15. macOS 12 declarado só para `swift test` no Mac.
- Projeto/workspace: `Package.swift` na raiz (SPM). O app de exemplo fica em `Example/` (`SentinelExample.xcodeproj`, gerado por `xcodegen` a partir de `Example/project.yml`).
- Schemes ou targets: `SentinelKit` (biblioteca) e `SentinelKitTests` (Swift Testing).
- Linguagem e versão: Swift 6 (`swiftLanguageModes: [.v6]`, concorrência estrita), toolchain Swift 6.4 / Xcode 27.
- Dependências permitidas: nenhuma. Só Foundation e os frameworks da Apple (MetricKit e UIKit quando disponível).
- Requisitos de hardware: dispositivo físico apenas para validar crashes do MetricKit.

## Coordenação dos subagentes

Use os níveis de execução e os papéis definidos e detalhados no `AGENTS.md`,
executados por subagentes que o agente principal cria com a ferramenta em uso:

- Nível 0 (direto): o agente principal executa sem subagentes.
- Nível 1 (padrão): subagente no papel Developer com plano curto → revisão por
  subagente no papel Manager, somente leitura.
- Nível 2 (completo): Manager planeja → Developer implementa e valida →
  Manager revisa.

Correções voltam ao Developer e passam por re-revisão até não restarem
apontamentos `BLOCKING`. A base não fixa agentes, nomes nem modelos; registre
aqui somente preferências ou exceções do projeto.

- Nível mínimo por área ou tipo de tarefa: nível 2 para `Transport/`, `Storage/` e `Crash/` (rede, persistência e concorrência). Com plano aprovado pelo dono, o principal implementa e um Manager revisa no fim de cada etapa.

## Arquitetura

Descreva os módulos, fronteiras de responsabilidade, composição de
dependências, navegação, persistência e integrações externas.

- Entrada e composição: `Sentinel` (fachada pública, S2) compõe `Options`, `Scope`, `Transport` e `EventStore`.
- Domínio: `Model/`, com `struct` e `enum` `Encodable` e `Sendable`, um tipo por arquivo.
- Envelope: `Envelope/` com `DSN` (parse e URL do endpoint) e `EnvelopeEncoder` (cabeçalho, itens com `length` em bytes).
- Infraestrutura: `Transport/` sobre o protocolo `HTTPClient`. A implementação real é `URLSessionHTTPClient`, sobre o protocolo `URLSessionDataLoading`, para os testes não tocarem na rede.
- Testes: `Tests/SentinelKitTests/` espelha as pastas de `Sources/`. Dublês em `Tests/SentinelKitTests/Support/` e fixtures em `Tests/SentinelKitTests/Fixtures/`.

## Estado, concorrência e efeitos

- Fonte de verdade de cada estado: o escopo (usuário, tags, breadcrumbs) num `actor` (S2). Os modelos são valores imutáveis.
- Isolamento de atores e tarefas: nada de `@MainActor` no SDK, exceto ao ler `UIDevice` e no tempo de segundo plano (`BackgroundTaskRunning`, `BackgroundTime`, `UIKitBackgroundTasks`), porque `UIApplication` só pode ser usado no main actor. Nada de `Task.detached` ou `nonisolated(unsafe)`; `@unchecked Sendable` só no `CrashSnapshotStore` (documentado no brief).
- Extensões de app: o SDK não pode citar API indisponível em extensões (`UIApplication.shared` e afins), senão quebra o build de widgets e extensões que o usem. Confira com `swiftc -typecheck -application-extension` (comando em "Testes e validação").
- Cancelamento: o envio aceita cancelamento e um envelope cancelado continua em disco.
- Limites: no máximo 50 breadcrumbs e 10 envelopes em disco (o mais antigo é reciclado).
- Permissões, rede, arquivos e outros efeitos: só rede para o host do DSN, e só com consentimento quando `consent == .required`; arquivos em `Caches/SentinelKit/`; conectividade observada por `NWPathMonitor`.

## Regras de implementação

- Injete serviços e protocolos nas fronteiras de comportamento.
- Use dublês nos testes e nas previews.
- Preserve cancelamento, isolamento e tratamento de erros.
- Não adicione dependências sem aprovação explícita.
- Mantenha segredos fora do repositório.
- Preserve alterações locais não relacionadas.

## Estilo e formatação Swift

- Convenção geral: [Google Swift Style Guide](https://google.github.io/swift/),
  com a exceção declarada de 4 espaços e 120 colunas, aplicada a todo código Swift, incluindo testes.
- Cadeias de modificadores SwiftUI: cada modificador em sua própria linha,
  conforme os exemplos da Apple em
  [Configuring Views](https://developer.apple.com/documentation/swiftui/configuring-views).
- `MARK:` obrigatório e espaçamento entre blocos conforme `SWIFT_REFERENCE.md`.
- Bootstrap/update sincronizam `.swiftlint.yml`, `.swiftformat`, `scripts/lint-swift.sh` e `scripts/fix-swift-spacing.pl` com manifesto e proteção de conflitos.
- Baseline desta base: SwiftLint 0.63.2 e SwiftFormat 0.63.0; confirme a instalação no consumidor e no CI.
- `scripts/lint-swift.sh` é o gate executável local/CI, verifica versões e cobre somente fontes, testes e `Package.swift` nos caminhos do consumidor. Conecte esse comando ao job obrigatório de CI do projeto.
- A base não distribui workflow de CI; chame `scripts/install-swift-tools.sh` e `scripts/lint-swift.sh` no CI do projeto (por exemplo, `ci_scripts/ci_post_clone.sh` no Xcode Cloud).
- Formate desde a criação: `scripts/lint-swift.sh --fix`; rascunhe MARKs ausentes com `scripts/lint-swift.sh --add-marks` e revise os nomes.
- Ferramentas: `scripts/lint-swift.sh` baixa sozinho as versões fixas (com SHA-256 conferido) para o cache por usuário `~/Library/Caches/swift-quality-tools` quando não as encontra no `PATH` ou no Homebrew; `scripts/install-swift-tools.sh` faz o mesmo antecipadamente (CI, Xcode Cloud, trabalho offline).
- Fase de build do Xcode (target sem sandbox de scripts): `scripts/lint-swift.sh --format-only`.
- Exceções locais justificadas: nenhuma.

## Previews SwiftUI

- Toda `View` criada deve ter `#Preview` para cada estado de apresentação
  suportado, incluindo os estados de carregamento, vazio, erro e sucesso quando
  fizerem parte do contrato da tela.
- Use `@Previewable` em cada propriedade dinâmica local necessária para
  configurar esses estados dentro do corpo de `#Preview`. Esse macro só é
  válido nesse corpo e não substitui a declaração dos previews para cada estado.
- Injete dados e dependências determinísticos; não conecte previews a serviços
  reais, rede, autenticação ou arquivos mutáveis do usuário.
- Convenção confirmada com a documentação da Apple:
  [Previewable](<https://developer.apple.com/documentation/swiftui/previewable()>).

## Testes e validação

Registre comandos e resultados reais. Separe compilação e Simulator de
validação em dispositivo físico e de serviços externos.

- Testes unitários: `swift test`.
- Teste contra servidor real: `SENTINEL_DSN=… SENTINEL_API_TOKEN=… swift test --filter LiveServer`, contra o `wrangler dev` do sentinel-lab (pulado sem `SENTINEL_DSN`).
- App de exemplo (build e testes do view model): `xcodebuild test -project Example/SentinelExample.xcodeproj -scheme SentinelExample -destination 'platform=iOS Simulator,name=iPhone 17'`.
- Segurança em extensões: `xcrun -sdk iphonesimulator swiftc -typecheck -parse-as-library -module-name SentinelKit -swift-version 6 -application-extension -target arm64-apple-ios15.0-simulator $(find Sources -name '*.swift')` deve terminar sem erros.
- Build e simulador: `xcodebuild test -scheme SentinelKit -destination 'platform=iOS Simulator,name=iPhone 17'`.
- Lint: `scripts/lint-swift.sh --fix` e depois `scripts/lint-swift.sh`.
- Dispositivo físico: crashes do MetricKit (S3).
- Serviços live: produção em https://sentinel.adrianosouzacosta.com.br.
- Validações ainda não executadas: MetricKit em iPhone físico, runtime iOS 15 e envio contra produção (detalhes no brief).

## Entrega

- Checklist de aceitação: testes, lint e build no simulador passando, e revisão do Manager `APPROVED`.
- Arquivos de documentação a atualizar: `README.md`, `.ai/PROJECT_BRIEF.md` (recursos e validações) e `CHANGELOG.md`.
- Artefatos temporários a limpar: DerivedData temporário de `xcodebuild` criado pela tarefa.
- Estado de commit esperado: um commit por etapa, aprovado pelo dono, em `main`.
- Riscos conhecidos: os do brief.
