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
- **Sem rede ou 5xx/503:** guarda em disco e tenta de novo com espera crescente.
- **429:** respeita o `Retry-After` antes de enviar outra vez.
- **400, 401 ou 413:** descarta o envelope, porque reenviar não ajudaria, e registra o motivo.
- **DSN inválido:** `start` falha com erro tipado e o SDK fica desligado.

## Recursos e limites

- Recursos disponíveis: modelo do evento, DSN, codificação do envelope e transporte (etapa S1).
- Recursos planejados, ainda não conectados:
  - S2: API pública, contextos, stack trace no aparelho e fila offline;
  - S3: crashes (`NSException` e MetricKit);
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
  - o pacote inclui `PrivacyInfo.xcprivacy` declarando dados de diagnóstico (crash e desempenho), não ligados à identidade e sem rastreamento;
  - inclui também os motivos das "required reason APIs" que o SDK usar (data de arquivos, espaço em disco, `UserDefaults`).
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
- Validações pendentes:
  - rodar os testes num runtime iOS 15, que não está instalado (hoje o mínimo é garantido só pelo compilador), antes da S4;
  - S4: envio real contra o `wrangler dev` e contra produção.
- Condições: crashes nativos pelo MetricKit só chegam em dispositivo físico, então o simulador não comprova esse caminho.

## Mapa de fontes

- `Sources/SentinelKit/Envelope/`: `DSN`, `Envelope`, `EnvelopeEncoder`.
- `Sources/SentinelKit/Model/`: tipos do evento.
- `Sources/SentinelKit/Transport/`: `HTTPClient`, `URLSessionHTTPClient`, `Transport`, `TransportResult`, `RetryAfter`.

## Pendências e decisões

- Decisão: o formato de envio é o envelope do Sentry porque o servidor do Sentinel já o entende. Não há código nem serviço do Sentry no SDK.
- Decisão: nenhum handler de sinal próprio. Crashes nativos vêm pelo MetricKit.
- Risco: um crash entregue pelo MetricKit mais de 24h depois chega com a hora de recebimento.
- Decisão (revisão da S1): a API pública é só a fachada `Sentinel` e o que ela expõe. Na S1, só `Level` é público.
- Pendência (S2): criar um único `Transport` e reutilizá-lo, porque cada `URLSessionHTTPClient()` padrão cria uma `URLSession` nova.
- Próximo passo: S2.
