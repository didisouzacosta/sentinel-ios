# SentinelKit

Envia erros, mensagens e crashes do seu app iOS para o [Sentinel Lab](https://sentinel.adrianosouzacosta.com.br).
Só Swift, sem dependências, iOS 15+.

## Requisitos

| | |
|---|---|
| Plataforma | iOS 15 ou superior |
| Swift | 6.0 ou superior (`swift-tools-version: 6.0`): Xcode 16 ou mais novo |
| Modo de linguagem | O pacote compila em Swift 6 com concorrência estrita. O seu app pode continuar no modo Swift 5, desde que use um compilador Swift 6 (Xcode 16+). |
| Dependências | Nenhuma. Só Swift, sem Objective-C. |

> **Versão atual:** 0.1.0 (veja o [CHANGELOG](CHANGELOG.md)). A API pode mudar até a 1.0; mudanças entram no
> CHANGELOG.

## 1. Pegue o DSN do projeto

No Sentinel, abra o projeto e vá em **Settings → Client keys (DSN)**. Ele tem esta forma:

```
https://<chave pública>@sentinel.adrianosouzacosta.com.br/<id do projeto>
```

O DSN é **público**: ele só permite enviar eventos para aquele projeto, então pode ficar no código. Não use um token
`wst_` (de API) no app.

## 2. Adicione o pacote

No Xcode: **File → Add Package Dependencies…**, cole a URL abaixo e escolha "Up to Next Major Version".

```
https://github.com/didisouzacosta/sentinel-ios
```

Ou no `Package.swift`:

```swift
.package(url: "https://github.com/didisouzacosta/sentinel-ios", from: "0.1.0")
// e no target: .product(name: "SentinelKit", package: "sentinel-ios")
```

## 3. Inicie e capture

```swift
import SentinelKit
import SwiftUI

@main
struct ShopApp: App {
    init() {
        Sentinel.start(dsn: "https://<chave>@sentinel.adrianosouzacosta.com.br/<id>")
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

// Em qualquer lugar:
Sentinel.capture(error)
Sentinel.capture(message: "Checkout aberto", level: .info)
Sentinel.addBreadcrumb(category: "ui", message: "Tocou em Pagar")
Sentinel.setCustom("plan", "pro")   // parâmetro personalizado, opcional
```

Por padrão o SDK **só envia depois do consentimento** (veja "Privacidade"):

```swift
// Depois de informar o usuário (tela de onboarding, ajustes, etc.):
Sentinel.grantConsent()
```

## 4. Confira

Rode o app, chame `Sentinel.grantConsent()`, dispare `Sentinel.capture(message: "Teste do SentinelKit")` e abra
**Issues** no Sentinel. O evento aparece em segundos.

## App de exemplo

`Example/SentinelExample.xcodeproj` é um app SwiftUI (iOS 17+) que usa o pacote local e tem um botão para cada
recurso: consentimento, breadcrumb, parâmetro personalizado, erro, mensagem, envio da fila e os dois tipos de crash.

1. Abra o projeto no Xcode e rode no simulador.
2. Cole o DSN no campo e toque em **Start SentinelKit**. Ele fica salvo e, nas próximas aberturas, o SDK já inicia
   no `init()` do app (é assim que o crash da abertura anterior é enviado). **Forget DSN** apaga o DSN salvo; feche e
   abra o app para informar outro.
3. Toque em **Grant consent** e depois em **Capture error**: a issue aparece no Sentinel.
4. **Crash: NSException** derruba o app; abra-o de novo e o crash chega ao Sentinel. **Crash: fatalError** só é
   reportado pelo MetricKit, num iPhone de verdade.

Para um Sentinel local (`wrangler dev`), use `http://<chave>@127.0.0.1:8787/<id>`: o app de exemplo já libera
`NSAllowsLocalNetworking`. O projeto é gerado pelo [XcodeGen](https://github.com/yonaskolb/XcodeGen) a partir de
`Example/project.yml`; depois de mudar esse arquivo, rode `xcodegen` dentro de `Example/`. O app fala com o SDK por um
protocolo (`SentinelService`), então as previews e os testes do view model nunca chegam ao SDK de verdade.

## Privacidade (GDPR)

- **Consentimento:**
  - por padrão (`consent = .required`), nada sai do aparelho até você chamar `Sentinel.grantConsent()`. Até lá os eventos esperam no aparelho;
  - `Sentinel.revokeConsent()` apaga o que está guardado e para a captura;
  - a escolha fica salva entre aberturas;
  - se o seu app usa outra base legal, inicie com `options.consent = .notRequired`.
- **Sem dados pessoais automáticos:**
  - não há campo de usuário;
  - o SDK não coleta nome do aparelho, IP, IDFA nem IDFV;
  - nos binários do `debug_meta` de erros e exceções, o caminho (`code_file`) dos que ficam dentro do app vai relativo à pasta que contém o `.app` (`MeuApp.app/MeuApp`), sem o caminho de instalação; bibliotecas do sistema vão com o caminho do sistema. Numa extensão de app, o pacote principal é o `.appex`: só os binários dentro do próprio `.appex` vão com caminho relativo, e os do app que a contém vão com o caminho completo.
- **Identificar alguém é opção sua:** use `Sentinel.setCustom("chave", "valor")`, de preferência com um identificador interno e não com e-mail ou nome. Também não coloque dados pessoais em mensagens e breadcrumbs.
  Se você enviar um identificador do usuário, os dados passam a ser "ligados à identidade": declare isso no manifesto de privacidade e na ficha de privacidade do **seu** app.
- **Manifesto da Apple:** o pacote traz `PrivacyInfo.xcprivacy` declarando dados de diagnóstico, não ligados à identidade e sem rastreamento.

## Crashes

Não há nada a configurar: `Sentinel.start` liga a captura.

| Tipo | Como chega | O que traz |
|---|---|---|
| Exceção Objective-C não tratada (`NSException`, por exemplo índice fora do array em código Foundation) | Gravada no aparelho no momento do crash e enviada na abertura seguinte. O handler que o app já tinha continua sendo chamado. | Tipo e motivo da exceção, stack com nomes de função, endereços e o UUID de cada binário (`debug_meta`), breadcrumbs e parâmetros personalizados. |
| Crash nativo: `fatalError`, force unwrap de `nil`, índice fora do array em Swift, acesso inválido à memória | O iOS entrega o relatório pelo MetricKit numa abertura seguinte. | Exceção e sinal (`EXC_BAD_ACCESS`/`SIGSEGV`, `EXC_BREAKPOINT`/`SIGTRAP`…), endereços e o UUID de cada binário (`debug_meta`), prontos para simbolização. Breadcrumbs da sessão que caiu não estão disponíveis. |

- **Duplicatas:** quando o SDK grava uma exceção, ele anota a hora. O relatório do MetricKit da mesma janela é reconhecido e ignorado uma vez, e a anotação expira em 7 dias. Se o handler não chegou a gravar (crash antes do `Sentinel.start`, por exemplo), o MetricKit reporta a exceção com nome e mensagem.
- **Binários (`debug_meta`):** os erros capturados com `Sentinel.capture(_:)` e as exceções levam, para cada binário citado pelos frames, o UUID, o endereço de carga, o tamanho e a arquitetura; os crashes nativos (MetricKit) levam o UUID e o endereço de carga. Isso serve para que um servidor Sentinel com o dSYM daquela build possa casar os binários.
- **Nomes de função:** nos erros e nas exceções, vêm do próprio aparelho e podem ser aproximados em builds de release sem símbolos. Nos crashes nativos ainda não há nomes: o Sentinel ainda não simboliza, então esses frames mostram binário e endereço.
- **Handler anterior:** o SDK chama o handler de exceções que já estava instalado antes do `Sentinel.start`. Um handler instalado depois substitui o do SDK.
- **Onde testar:** o MetricKit só entrega relatórios num iPhone de verdade, não no simulador. Com o aparelho conectado, *Debug → Simulate MetricKit Payloads* no Xcode gera um de teste.
- **Dados do crash nativo:** a versão do app, do sistema e o modelo do aparelho são os do momento do crash, não os da abertura atual.

## Offline

- **Fila:** sem rede, os eventos e crashes ficam numa fila no aparelho com no máximo **10**; a partir daí o mais antigo é reciclado.
- **Envio:** a fila é enviada ao abrir o app, quando a rede volta, quando o app vai para o segundo plano ou volta dele, e depois de cada nova captura. Cada evento aceito pelo Sentinel é apagado do aparelho.
- **Falhas:** sem resposta do servidor, o SDK espera 30 s, depois 60 s e assim por diante, até 1 hora, e tenta de novo sozinho. Se o Sentinel pedir para esperar (`Retry-After`), ele respeita esse prazo.

## Declarações para a Apple

O SDK não pede permissão nem chave nova no `Info.plist` do seu app.

| Item | O que fazer |
|---|---|
| Manifesto de privacidade | Nada: o `PrivacyInfo.xcprivacy` do SentinelKit entra sozinho no relatório de privacidade do app. Ele declara dados de crash e outros diagnósticos, não ligados à identidade e sem rastreamento, e o uso de `UserDefaults` (motivo `CA92.1`), onde fica a decisão de consentimento. |
| Ficha de privacidade (App Store Connect) | No **seu** app, marque "Crash Data" e "Other Diagnostic Data" como *não ligados ao usuário*, finalidade *App Functionality*. Se enviar um identificador do usuário com `setCustom`, marque como *ligados*. |
| App Tracking Transparency | Não se aplica: o SDK não rastreia nem usa IDFA. |
| Background Modes, entitlements, App Intents | Não são necessários. |
| Criptografia (export compliance) | Nada muda: o envio usa HTTPS do sistema, que é isento. |
| Só em desenvolvimento | Com DSN `http://` (Sentinel local), libere `NSAllowsLocalNetworking` em `NSAppTransportSecurity`. Num iPhone físico apontando para o IP do seu Mac, o iOS pede acesso à rede local: adicione `NSLocalNetworkUsageDescription`. Não leve isso para a versão da loja. |

## Peça para a sua IA integrar

Copie o texto abaixo para o Claude Code (ou outro agente) na raiz do seu app:

```text
Integre o SentinelKit (https://github.com/didisouzacosta/sentinel-ios) neste app iOS para enviar erros ao
Sentinel Lab.

1. DSN: se o MCP "sentinel" estiver conectado, chame `list_projects`, me pergunte qual projeto usar e chame
   `get_project_setup` com a plataforma "ios" para obter o DSN. Sem o MCP, peça o DSN para mim (Sentinel →
   Settings → Client keys). O DSN é público; nunca use nem peça um token `wst_`.
2. Adicione o pacote por Swift Package Manager (produto "SentinelKit", versão "Up to Next Major" a partir de 0.1.0).
3. Chame `Sentinel.start(dsn:)` uma única vez no `init()` do `App` (ou no `application(_:didFinishLaunchingWithOptions:)`).
   Defina `environment` como "debug" em builds de debug e "production" nos demais.
   Mantenha `consent = .required` (padrão) e chame `Sentinel.grantConsent()` no ponto onde o app já informa o usuário
   sobre coleta de dados; se não existir, me pergunte onde colocar. Não envie e-mail, nome ou outros dados pessoais;
   se for preciso identificar algo, use `Sentinel.setCustom` com um identificador interno.
4. Nos `catch` que hoje só imprimem o erro, acrescente `Sentinel.capture(error)`. Não capture erros esperados
   (cancelamento, validação de formulário).
5. Compile, rode no simulador, envie `Sentinel.capture(message: "Teste do SentinelKit")` e confirme comigo que o
   evento apareceu em Issues no Sentinel.
Mostre o diff antes de concluir.
```

O MCP do Sentinel se conecta pela página **Connect → MCP · AI agents** do painel.

## Como funciona

O SDK monta cada evento em JSON e envia com `POST` para `/api/<id>/envelope/` do Sentinel, autenticado pela chave do
DSN. O formato do pacote é o "envelope" do Sentry: uma linha de cabeçalho e, para cada item, uma linha que o descreve
(tipo e tamanho em bytes) seguida do conteúdo. Um evento sem anexos ocupa três linhas. O servidor do Sentinel já
entende esse formato, então nada precisa mudar nele. O SDK não usa nenhuma biblioteca, conta ou servidor do Sentry.

```
{"event_id":"0123…","sdk":{"name":"sentinel.cocoa","version":"0.1.0"},"sent_at":"2025-11-24T16:00:00.500Z"}
{"length":816,"type":"event"}
{"event_id":"0123…","level":"error","platform":"cocoa","exception":{…},"breadcrumbs":[…],…}
```

## Desenvolvimento

- Ferramentas usadas no desenvolvimento: Xcode 27 / Swift 6.4 (o pacote exige no mínimo Swift 6.0).
- Testes: `swift test`, ou no simulador com
  `xcodebuild test -scheme SentinelKit -destination 'platform=iOS Simulator,name=iPhone 17'`.
- Teste contra um Sentinel de verdade (opcional; sem as variáveis ele é pulado):
  `SENTINEL_DSN="http://<chave>@127.0.0.1:8787/<id>" SENTINEL_API_TOKEN="wst_…" swift test --filter LiveServer`.
  Ele envia um evento montado pelo SDK e, com o token, confirma pela `/api/0` que o servidor o encontrou.
- App de exemplo e testes do view model:
  `xcodebuild test -project Example/SentinelExample.xcodeproj -scheme SentinelExample -destination 'platform=iOS Simulator,name=iPhone 17'`.
- Lint (obrigatório): `scripts/lint-swift.sh --fix` e depois `scripts/lint-swift.sh`.
- Regras para pessoas e agentes: [AGENTS.md](AGENTS.md), com o brief e o guia em `.ai/`.
- O arquivo `Tests/SentinelKitTests/Fixtures/handled-error.envelope` é o contrato com o servidor: o Sentinel aceita
  esse envelope exatamente como está. Se o formato mudar, regrave com `RECORD_FIXTURES=1 swift test --filter contractFixture`
  e valide de novo contra o servidor. O sentinel-lab tem uma cópia idêntica em
  `packages/workers-sentinel/test/fixtures/sentinelkit-handled-error.envelope`, testada em `sentinelkit-contract.test.ts`:
  mude as duas juntas.
