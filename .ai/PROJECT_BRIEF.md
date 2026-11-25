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
- Recursos planejados, ainda não conectados:
  - S3: crashes (`NSException` e MetricKit) e `debug_meta` com os UUIDs das imagens;
  - S4: app de exemplo, teste ponta a ponta e versão 0.1.0.
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
- Validações pendentes:
  - envio real pela fachada (`Sentinel.start` com `URLSession` e disco reais) contra o Sentinel: fica para o teste ponta a ponta da S4;
  - retomada por `NWPathMonitor` e pelas notificações de ciclo de vida: só comprovável rodando um app (S4);
  - envio ao ir para o segundo plano: hoje roda sem `beginBackgroundTask`, então o sistema pode suspender a requisição; verificar na S4 e, se preciso, pedir esse tempo extra;
  - rodar os testes num runtime iOS 15, que não está instalado (hoje o mínimo é garantido só pelo compilador), antes da S4;
  - S4: envio real contra o `wrangler dev` e contra produção.
- Condições: crashes nativos pelo MetricKit só chegam em dispositivo físico, então o simulador não comprova esse caminho.

## Mapa de fontes

- `Sources/SentinelKit/Public/`: `Sentinel` (fachada), `Options`, `ConsentPolicy`, `Level`. Só esses são públicos.
- `Sources/SentinelKit/Platform/`: `SentinelHub` (fila ordenada de comandos e observação de rede e ciclo de vida), `ConnectivityMonitor` (`NWPathMonitor`), `SentinelCommand` e `Log`.
- `Sources/SentinelKit/Capture/`: `SentinelClient` (motor), `EventBuilder`, `Scope`, `ErrorDescriptor`, `StackTraceBuilder`, `SymbolDemangler`, `ContextProvider` e `AppInfo`.
- `Sources/SentinelKit/Storage/`: `EventStore` (fila de 10 em `Caches/SentinelKit/`), `ConsentStore` e `UserDefaultsConsentStore`.
- `Sources/SentinelKit/Delivery/`: `DeliveryState` (rate limit e backoff de 30 s até 1 h).
- `Sources/SentinelKit/Envelope/`: `DSN`, `Envelope`, `EnvelopeEncoder`.
- `Sources/SentinelKit/Model/`: tipos do evento e contextos.
- `Sources/SentinelKit/Transport/`: `HTTPClient`, `URLSessionHTTPClient`, `Transport`, `TransportResult`, `RetryAfter`.
- `Sources/SentinelKit/Resources/PrivacyInfo.xcprivacy`.

## Pendências e decisões

- Decisão: o formato de envio é o envelope do Sentry porque o servidor do Sentinel já o entende. Não há código nem serviço do Sentry no SDK.
- Decisão: nenhum handler de sinal próprio. Crashes nativos vêm pelo MetricKit.
- Risco: um crash entregue pelo MetricKit mais de 24h depois chega com a hora de recebimento.
- Decisão (revisão da S1): a API pública é só a fachada `Sentinel` e o que ela expõe. Na S1, só `Level` é público.
- Resolvido na S2: um único `SentinelClient` (e portanto um único `Transport` e uma única `URLSession`) por app, criado no `start`.
- Decisão (S2): nenhum comando espera a rede. A captura só grava em disco; `flush`, consentimento e retomada só disparam o envio.
- Decisão (S2, revisão): o consentimento é lido de forma síncrona no `start` e conferido antes de cada envelope; revogar cancela o envio em andamento. Decisões tomadas antes do `start` são salvas, e revogar limpa a fila mesmo sem o SDK iniciado.
- Próximo passo: S3.
