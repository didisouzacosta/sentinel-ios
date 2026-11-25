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

> **Status:** em construção, ainda sem versão publicada (use a branch `main`). Prontos: início, captura de erros e
> mensagens, breadcrumbs, parâmetros personalizados, consentimento e fila offline. Os crashes chegam na etapa 3 e a
> versão 0.1.0 na etapa 4.

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

## Privacidade (GDPR)

- **Consentimento:**
  - por padrão (`consent = .required`), nada sai do aparelho até você chamar `Sentinel.grantConsent()`. Até lá os eventos esperam no aparelho;
  - `Sentinel.revokeConsent()` apaga o que está guardado e para a captura;
  - a escolha fica salva entre aberturas;
  - se o seu app usa outra base legal, inicie com `options.consent = .notRequired`.
- **Sem dados pessoais automáticos:**
  - não há campo de usuário;
  - o SDK não coleta nome do aparelho, IP, IDFA nem IDFV.
- **Identificar alguém é opção sua:** use `Sentinel.setCustom("chave", "valor")`, de preferência com um identificador interno e não com e-mail ou nome. Também não coloque dados pessoais em mensagens e breadcrumbs.
  Se você enviar um identificador do usuário, os dados passam a ser "ligados à identidade": declare isso no manifesto de privacidade e na ficha de privacidade do **seu** app.
- **Manifesto da Apple:** o pacote traz `PrivacyInfo.xcprivacy` declarando dados de diagnóstico, não ligados à identidade e sem rastreamento.

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
- Lint (obrigatório): `scripts/lint-swift.sh --fix` e depois `scripts/lint-swift.sh`.
- Regras para pessoas e agentes: [AGENTS.md](AGENTS.md), com o brief e o guia em `.ai/`.
- O arquivo `Tests/SentinelKitTests/Fixtures/handled-error.envelope` é o contrato com o servidor: o Sentinel aceita
  esse envelope exatamente como está. Se o formato mudar, regrave com `RECORD_FIXTURES=1 swift test --filter contractFixture`
  e valide de novo contra o servidor.
