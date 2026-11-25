# Changelog

Todas as mudanças relevantes do SentinelKit. O formato segue o [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/)
e as versões seguem o [SemVer](https://semver.org/lang/pt-BR/). Até a 1.0, uma versão menor (0.x) pode quebrar a API.

## [0.1.0] - 2026-11-25

Primeira versão.

### Adicionado

- `Sentinel.start(dsn:configure:)`, com `environment`, `release`, `dist` e a política de consentimento em `Options`.
- Captura de erros (`Sentinel.capture(_:)`) e mensagens (`Sentinel.capture(message:level:)`), com stack trace
  resolvido no aparelho e contextos de app, sistema e aparelho.
- `Sentinel.flush()` para esperar o envio da fila (por exemplo, antes de encerrar uma tarefa).
- Breadcrumbs (até 50) e parâmetros personalizados enviados como tags (`Sentinel.setCustom(_:_:)`).
- Consentimento exigido por padrão (`grantConsent()` / `revokeConsent()`), salvo entre aberturas; revogar apaga a fila.
- Fila offline em disco com no máximo 10 eventos, reciclando o mais antigo, enviada ao abrir o app, quando a rede
  volta, no ciclo de vida do app (com tempo extra de segundo plano) e após cada captura; backoff de 30 s até 1 h e
  respeito ao `Retry-After`.
- Crashes por `NSException` não tratada (gravados no momento do crash e enviados na abertura seguinte) e crashes
  nativos pelo MetricKit, com `debug_meta` e deduplicação entre os dois.
- Seguro para extensões de app (widgets, Notification Service): nenhuma API indisponível em extensões.
- `PrivacyInfo.xcprivacy` com dados de diagnóstico não ligados à identidade, sem rastreamento.
- App de exemplo em `Example/` e teste opcional contra um servidor real (`swift test --filter LiveServer`).

[0.1.0]: https://github.com/didisouzacosta/sentinel-ios/releases/tag/0.1.0
