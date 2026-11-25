# SentinelKit — Brief do produto

## Identidade do produto

- Nome: SentinelKit (repositório `sentinel-ios`).
- Plataforma: biblioteca Swift Package Manager para iOS 15+. macOS 12 é declarado só para rodar `swift test` no Mac.
- Problema que resolve: enviar erros, mensagens e crashes de apps iOS para o [Sentinel Lab](https://sentinel.adrianosouzacosta.com.br) com o mínimo de código e de dependências.
- Público principal: desenvolvedores iOS (e agentes de IA) integrando um app ao Sentinel Lab.
- Proposta de valor: uma linha para iniciar e uma para capturar. Só Swift, sem Objective-C, sem dependências, tudo testado.

## Experiência principal

### Fluxos

- Fluxo de entrada: o app chama `Sentinel.start(dsn:)` uma vez, no início.
- Fluxo principal: o app chama `Sentinel.capture(error)` ou `Sentinel.capture(message:level:)`. O SDK monta o evento com contexto e breadcrumbs, empacota num envelope e envia para `POST /api/{id}/envelope/` do Sentinel.
- Fluxos alternativos:
  - sem rede: o envelope fica em disco e é reenviado depois;
  - crash: o relato é gravado e enviado na abertura seguinte (`NSException`) ou entregue pelo MetricKit (crashes nativos).

### Estados

- **Não iniciado:** chamadas de captura são ignoradas sem travar o app.
- **Iniciado:** captura e envio normais.
- **Sem rede ou 5xx/503:** guarda em disco e tenta de novo sozinho com espera crescente (30 s até 1 h), além das tentativas na abertura, na volta da rede e no ciclo de vida.
- **429:** respeita o `Retry-After` antes de enviar outra vez.
- **400, 401 ou 413:** descarta o envelope, porque reenviar não ajudaria, e registra o código no log do sistema.
- **DSN inválido:** `start` não lança erro (a API é síncrona); o SDK fica desligado e registra o motivo no log do sistema. Decisões de consentimento continuam valendo.

## Recursos e limites

- Recursos disponíveis:
  - S1: modelo do evento, DSN, codificação do envelope e transporte;
  - S2: fachada `Sentinel` (`start`, `capture`, `addBreadcrumb`, `setCustom`, `grantConsent`, `revokeConsent` e `flush`), fila ordenada de comandos, contextos de app, sistema e aparelho, stack trace resolvido no aparelho, fila offline de 10, envio em segundo plano com backoff, retomada quando a rede volta e no ciclo de vida do app, e `PrivacyInfo.xcprivacy`.
  - S3: crashes por `NSException` (handler gravando em disco de forma síncrona, com breadcrumbs, encadeando o handler anterior) e pelo MetricKit (`MXCrashDiagnostic` com `debug_meta` e UUIDs), deduplicados dentro da janela do payload;
  - S4: tempo extra de segundo plano para o envio ao sair do app (`LifecycleObserver` + `BackgroundTime`, com `UIApplication` resolvido em tempo de execução para o SDK continuar utilizável em extensões), app de exemplo em `Example/` com testes do view model, teste opcional contra um servidor real (`LiveServer`) e versão 0.1.0.
- Limites conhecidos do servidor, que o SDK respeita:
  - `message` em texto simples;
  - `timestamp` em ISO-8601, porque fora de ±24h o servidor troca pela hora de chegada;
  - uma única `event` por envelope;
  - JSON dos eventos até 5 MiB;
  - só `gzip` como compressão;
  - breadcrumbs em array, no máximo 50;
  - frames acima de 100 são cortados no meio.
- O servidor não simboliza frames. O SDK envia `function`, `package` e `filename` resolvidos no aparelho, além de `instruction_addr`, `image_addr` e `debug_meta`, para uma simbolização futura.

## Privacidade (GDPR) e uso offline

Regras definidas pelo dono em 25/11/2026:

- **Consentimento por padrão:**
  - `Options.consent` começa em `.required`: o SDK não envia nada até o app chamar `Sentinel.grantConsent()`, depois de informar o usuário;
  - enquanto não houver decisão, os eventos ficam só no aparelho, dentro do limite da fila, e saem quando o consentimento chegar;
  - `Sentinel.revokeConsent()` apaga o que está guardado e para a captura;
  - a decisão fica salva e vale nas próximas aberturas;
  - apps com outra base legal (interesse legítimo) usam `.notRequired`.
- **Nada que identifique a pessoa é coletado automaticamente:**
  - o evento não tem campo de usuário;
  - nada de nome do aparelho, IP, IDFA ou IDFV;
  - o servidor também remove `user.ip_address`.
- **Dados de identificação só de propósito:** o app pode mandar o que quiser, como parâmetro personalizado (`Sentinel.setCustom("plan", "pro")`, enviado como tag). A documentação recomenda não usar e-mail ou nome.
- **Breadcrumbs e mensagens são texto do app:** o README orienta a não colocar dados pessoais neles.
- **Manifesto de privacidade da Apple:**
  - o pacote inclui `PrivacyInfo.xcprivacy` declarando dados de crash e outros diagnósticos, não ligados à identidade e sem rastreamento;
  - inclui também o motivo da única "required reason API" usada: `UserDefaults` (`CA92.1`).
- **Declarações para a Apple** (análise de 25/11/2026, a pedido do dono):
  - o SDK não precisa de permissão, chave no `Info.plist`, Background Modes, entitlements nem App Intents;
  - a única "required reason API" usada é `UserDefaults` (`CA92.1`). O SDK não usa data de arquivo, espaço em disco, tempo desde o boot nem `mach_absolute_time`, e `sysctl` lê só `kern.osversion` e `hw.machine`;
  - o app declara na ficha da App Store "Crash Data" e "Other Diagnostic Data" (não ligados), ou ligados se usar `setCustom` com identificador;
  - em desenvolvimento com DSN `http://`: `NSAllowsLocalNetworking`, e `NSLocalNetworkUsageDescription` em aparelho físico;
  - regra: qualquer API nova do SDK que esteja na lista da Apple precisa entrar no `PrivacyInfo.xcprivacy` na mesma mudança.
- **Offline:**
  - a fila em disco guarda no máximo **10 envelopes**; ao passar disso, recicla o mais antigo;
  - é enviada ao abrir o app, quando a rede volta (`NWPathMonitor`) e depois de cada captura;
  - cada envelope aceito pelo servidor é apagado.

## Dados e persistência

- Modelos: `Event`, `ExceptionValue`, `Mechanism`, `StackFrame`, `Breadcrumb`, `Contexts`, `DebugImage`, `SDKInfo`, `Envelope`. Não há modelo de usuário, de propósito.
- Fonte primária dos dados: o próprio app, no momento da captura.
- Armazenamento local (S2): um arquivo por envelope em `Caches/SentinelKit/` (no máximo 10, reciclando o mais antigo), apagado depois de aceito pelo servidor. A decisão de consentimento fica em `UserDefaults`, porque não é segredo.
- Serviços externos: somente o endpoint de ingestão do Sentinel definido pelo DSN.
- O DSN é a chave **pública** do projeto: pode ficar no código ou no Info.plist. Tokens `wst_` nunca entram no app.

## Validação

- Validações concluídas (S1, 25/11/2026):
  - `swift test` com 33 testes, incluindo os de `URLSession` real via `URLProtocol` de stub;
  - `xcodebuild test` no simulador iPhone 17 com iOS 27.2: TEST SUCCEEDED;
  - `scripts/lint-swift.sh` sem nenhuma violação, e `swift build` sem avisos;
  - a fixture `handled-error.envelope` foi aceita pelo Sentinel local (`wrangler dev`): 200, issue "PaymentError: Card declined" com culprit `CheckoutViewModel.swift in CheckoutViewModel.pay() at line 42`.
- Validações concluídas (S2, 25/11/2026):
  - `swift test` e `xcodebuild test` (iPhone 17, iOS 27.2) com 75 testes em 15 suítes, incluindo os de concorrência (revogar durante um envio, flush que não trava a fila, consentimento antes do `start`);
  - lint sem nenhuma violação, e build sem avisos no Mac e no simulador;
  - `plutil -lint` do `PrivacyInfo.xcprivacy` sem erros.
- Validações concluídas (S3, 25/11/2026):
  - `swift test` e `xcodebuild test` (iPhone 17, iOS 27.2) com 100 testes em 18 suítes, todos com relógio fixo onde há comparação de datas;
  - testes do escritor de crash (gravação síncrona, limite de 10, consentimento revogado, marcador com hora e expiração) e do handler (grava e chama o handler anterior);
  - testes do motor com MetricKit: consentimento revogado, consentimento ainda não decidido, deduplicação em um payload posterior;
  - testes do parser do MetricKit com payloads de exemplo montados a partir da estrutura documentada pela Apple (falha de segmentação, trap do Swift, exceção Objective-C e abort duplicado).
- Validações concluídas (S4, 25/11/2026), no simulador iPhone 17 (iOS 27.2) contra o `wrangler dev` local:
  - app de exemplo iniciando pelo DSN salvo no `init()`;
  - consentimento: com `.required` e nada decidido, erro e mensagem ficaram na fila em disco (2 envelopes) e nada chegou ao servidor; ao conceder, os dois chegaram e a fila esvaziou;
  - o erro chegou com a tag `plan=pro`, o breadcrumb, contextos de app, sistema e aparelho, 51 frames com o do app marcado como `in_app`, culprit `PlaygroundViewModel.captureError()` e sem campo de usuário;
  - `NSException` real: o handler gravou o envelope e o marcador antes de o app cair; na abertura seguinte a issue `NSRangeException` chegou como `fatal`, `mechanism` `NSException` não tratado, com breadcrumb, tag, release e environment;
  - revogar apagou a fila e o marcador, a captura seguinte não foi gravada nem enviada, e a decisão ficou salva em `UserDefaults`;
  - ao ir para a tela inicial, o log do UIKit mostrou a tarefa `SentinelKit.flush` criada e encerrada ~150 ms depois, com o envio concluído;
  - o SDK inteiro compila com `-application-extension` (seguro para widgets e extensões);
  - testes novos: `BackgroundTime` (fim único, expiração, sem tempo concedido) e `LifecycleObserver` (tempo pedido antes do envio e liberado só depois, pedidos sobrepostos, volta ao primeiro plano); 5 testes do view model do app de exemplo;
  - `swift test --filter LiveServer` com `URLSession` real: evento aceito e encontrado pela `/api/0`;
  - no sentinel-lab, `sentinelkit-contract.test.ts` ingere a fixture do contrato e confere título, nível, plataforma e culprit.
- Validações pendentes:
  - um relatório real do MetricKit: só em iPhone físico (ou *Simulate MetricKit Payloads* no Xcode com aparelho conectado). Os payloads de teste seguem a estrutura documentada, mas não vieram de um aparelho. Conferir na S4: a ordem dos frames (raiz = frame que caiu) e o `image_addr` (endereço − `offsetIntoBinaryTextSegment`) contra o endereço de carga no `.ips` do mesmo crash; e se a janela `timeStampBegin`…`timeStampEnd` de um diagnóstico entregue logo na abertura seguinte contém a hora do crash (senão a deduplicação falha e a exceção aparece duas vezes — nunca some);
  - retomada pelo `NWPathMonitor` com a rede caindo e voltando de verdade (coberta só por testes com rede falsa);
  - envio em segundo plano com o servidor demorando mais que o tempo concedido (a expiração encerra a tarefa; o envelope fica em disco para a próxima abertura);
  - rodar os testes num runtime iOS 15, que não está instalado (hoje o mínimo é garantido só pelo compilador);
  - envio real contra produção (sentinel.adrianosouzacosta.com.br), depois da publicação da 0.1.0.
- Condições: crashes nativos pelo MetricKit só chegam em dispositivo físico, então o simulador não comprova esse caminho.

## Mapa de fontes

- `Sources/SentinelKit/Public/`: `Sentinel` (fachada), `Options`, `ConsentPolicy`, `Level`. Só esses são públicos.
- `Sources/SentinelKit/Platform/`: `SentinelHub` (fila ordenada de comandos e observação de rede e ciclo de vida), `ConnectivityMonitor` (`NWPathMonitor`), `LifecycleObserver` e `LifecycleEvents` (envio ao ir para o segundo plano e ao voltar), `BackgroundTime`, `BackgroundTaskRunning`, `BackgroundTaskID` e `UIKitBackgroundTasks` (tempo extra de segundo plano; o último só no iOS), `SentinelCommand` e `Log`.
- `Sources/SentinelKit/Capture/`: `SentinelClient` (motor), `EventBuilder`, `Scope`, `ErrorDescriptor`, `StackTraceBuilder`, `SymbolDemangler`, `ContextProvider` e `AppInfo`.
- `Sources/SentinelKit/Storage/`: `EventStore` (fila de 10 em `Caches/SentinelKit/`), `ConsentStore` e `UserDefaultsConsentStore`.
- `Sources/SentinelKit/Delivery/`: `DeliveryState` (rate limit e backoff de 30 s até 1 h).
- `Sources/SentinelKit/Envelope/`: `DSN`, `Envelope`, `EnvelopeEncoder`.
- `Sources/SentinelKit/Model/`: tipos do evento e contextos.
- `Sources/SentinelKit/Transport/`: `HTTPClient`, `URLSessionHTTPClient`, `Transport`, `TransportResult`, `RetryAfter`.
- `Sources/SentinelKit/Crash/`: `ExceptionCrashHandler`, `CrashWriter`, `CrashSnapshot`, `CrashSnapshotStore` (a única ponte com lock, documentada), `MetricKitCrashParser`, `MetricKitPayload`, `MetricKitDelivery`, `MetricKitParseResult` e `MachException`.
- `Sources/SentinelKit/Platform/MetricKitCrashSource.swift` (assinante do `MXMetricManager`, só no iOS).
- `Sources/SentinelKit/Resources/PrivacyInfo.xcprivacy`.
- `Example/`: app SwiftUI de exemplo (iOS 17+, MVVM com `@Observable`), gerado pelo XcodeGen a partir de `project.yml` com pastas sincronizadas; o `.xcodeproj` gerado também é versionado. O view model fala com o SDK por `SentinelService` (`LiveSentinelService` no app, `PreviewSentinelService` nas previews) e guarda o DSN por `DSNStorage`; os testes ficam em `Example/Tests`.
- `Tests/SentinelKitTests/Integration/LiveServerTests.swift`: teste opcional contra um servidor real, ligado por `SENTINEL_DSN`.

## Pendências e decisões

- Decisão: o formato de envio é o envelope do Sentry porque o servidor do Sentinel já o entende. Não há código nem serviço do Sentry no SDK.
- Decisão: nenhum handler de sinal próprio. Crashes nativos vêm pelo MetricKit.
- Risco: um crash entregue pelo MetricKit mais de 24h depois chega com a hora de recebimento.
- Decisão (revisão da S1): a API pública é só a fachada `Sentinel` e o que ela expõe. Na S1, só `Level` é público.
- Resolvido na S2: um único `SentinelClient` (e portanto um único `Transport` e uma única `URLSession`) por app, criado no `start`.
- Decisão (S2): nenhum comando espera a rede. A captura só grava em disco; `flush`, consentimento e retomada só disparam o envio.
- Decisão (S2, revisão): o consentimento é lido de forma síncrona no `start` e conferido antes de cada envelope; revogar cancela o envio em andamento. Decisões tomadas antes do `start` são salvas, e revogar limpa a fila mesmo sem o SDK iniciado.
- Decisão (S3, revisada): o handler grava um marcador com a hora do crash. O primeiro diagnóstico do MetricKit que pareça uma exceção (com `objectiveCexceptionReason` ou `EXC_CRASH`/`SIGABRT`) dentro da janela do payload é tratado como cópia e ignorado, e o marcador é removido. Sem marcador, o MetricKit reporta a exceção com `exceptionName` e `composedMessage`. O marcador expira em 7 dias e é apagado ao revogar o consentimento.
- Decisão (S3): crashes do MetricKit usam sempre `bundle@versão+build` da build que caiu, mesmo quando o app define `options.release`, porque o valor personalizado descreve a build atual. Sistema e modelo do aparelho também vêm do diagnóstico.
- Decisão (S3): `mechanism.type` é `mach` quando o diagnóstico traz tipo de exceção Mach e `signal` quando só traz o sinal (como no plano).
- Decisão (S3): o `CrashSnapshotStore` usa `NSLock` com `@unchecked Sendable` porque o handler é uma função C síncrona que não pode esperar um actor; é a única exceção e a invariante está documentada no tipo.
- Decisão (S4): o app de exemplo exige iOS 17 (para `@Observable` e previews modernas); o SDK continua em iOS 15.
- Decisão (S4, desvio do plano): o teste contra servidor real ficou numa suíte `LiveServer` do próprio alvo de testes, ligada por `SENTINEL_DSN`, e não num alvo separado; ele passa pelo `Transport` com `URLSession` real. A fachada com disco e rede reais foi comprovada pelo teste ponta a ponta no simulador.
- Decisão (S4, revisão): cada ida ao segundo plano pede o próprio tempo extra, de forma síncrona dentro da notificação; a expiração encerra a tarefa mas não cancela o envio (o envelope continua em disco).
- Próximo passo: publicar a 0.1.0 (tag e release no GitHub) e trocar o guia do Connect no sentinel-lab para "Up to Next Major" a partir de 0.1.0. Depois: portes para Android e React Native.
