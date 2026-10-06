# AGENTS.md

Instructions and context for AI coding agents operating on the `croqui_forense_mvp` codebase.

---

## Agent skills

### Issue tracker

GitHub issues tracked via the `gh` CLI. See [`docs/agents/issue-tracker.md`](docs/agents/issue-tracker.md).

### Triage labels

Canonical five-role triage vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See [`docs/agents/triage-labels.md`](docs/agents/triage-labels.md).

### Domain docs

Single-context repo layout (`GLOSSARY.md` and `docs/adr/`). See [`docs/agents/domain.md`](docs/agents/domain.md).

---

## Project Overview

- **Product**: Necrópsia Digital / Croqui Forense MVP (Polícia Científica / IML-SE).
- **Core Goal**: Digitalização e mapeamento anatômico 2D de lesões em exames cadavéricos e clínicos, gerando laudos periciais oficiais em PDF com integridade forense e cadeia de custódia.
- **Stack**: Flutter / Dart, SQLite criptografado via SQLCipher (`sqflite_sqlcipher`), `Dio`, `Provider`, `Sentry`.
- **Primary Operational Paradigm**: **Strict Offline-First** (o perito médico-legista opera em salas de necropsia e locais de crime sem internet; todos os dados, evidências e laudos são persistidos localmente antes de sincronizar).

---

## Core Architecture & Guidelines

1. **Camadas**:
   - `lib/core/`: Constantes, utilitários, temas, exceptions, network (`ApiClient`) e interfaces de segurança.
   - `lib/data/`: Models, Repositories (CRUD SQLite), DataSources (`RemoteDataSourceImpl`) e helpers locais (`DatabaseHelper`).
   - `lib/domain/services/`: Regras de negócio, ciclo de vida dos laudos (`CaseService`), motor de PDF (`PdfService`, `PdfReportService`, `PdfGenerationService`), autenticação e RBAC (`AuthService`), motor de sincronização (`SyncService`).
   - `lib/presentation/`: Controllers (MVVM), Providers reativos, páginas e widgets de visualização/edição do croqui anatômico.

2. **Threading & Performance**:
   - Processamentos computacionalmente caros (parse massivo de JSON, compilação vetorial de PDF, cálculo de hash PBKDF2 de credenciais) **devem** ser executados em background isolates via `compute()`.
   - Métodos síncronos pesados executando na UI thread devem ser devidamente sinalizados com a tag dartdoc `/// **Atenção: roda na UI thread.**`.

3. **Validação & Análise Estática**:
   - Antes de concluir qualquer tarefa, garanta que `flutter analyze` não aponte erros ou warnings.
   - Execute testes via `flutter test`.
