# swift-service-template

Lo scopo di questa repository è fornire un template base per microservizi scritti in swift utilizzando il framework vapor.

Il template contiene l'architettura base di un microservizio (con la suddivisione App, API e Core), con l'implementazione base di un controller, un entità base e test; includendo la configurazione per Postgres e le migrazioni.

Files:

- `.swift-format`
- `docker-compose.yaml`: per avviare localmente un istanza di Postgres.
- `.env.testing`: environment di base.

## Architettura base

- **App**: contiene la configurazione del microservizio: database (incluse le migrazioni), leaf, queue, ecc...
- **API**: contiene Controller, middleware e DTO; gestione della validazione dell'input e dei messaggi di errore.
- **Core**: contiene la business logic del microservizio e gli adapter; interazione con il db tramite l'ORM Fluent.
