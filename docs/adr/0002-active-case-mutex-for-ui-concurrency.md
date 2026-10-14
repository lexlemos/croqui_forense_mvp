# Active Case Mutex for UI Concurrency

## Status
Accepted

## Context
Se o perito estiver com um laudo aberto em edição no `CroquiController` e o `SyncService` no background executar um Pull (`pullCasos`), uma versão remota mais nova desse mesmo laudo pode ser gravada no SQLite via `upsertCasoTransaction`. Em seguida, o AutoSave periódico (debounce 1000ms) do `CroquiController` grava os dados que estavam na memória da UI sobre a tabela `casos`, sobrescrevendo cegamente a atualização que veio do servidor.

## Decision
Adotamos o padrão **Active Case Mutex** gerenciado em memória:
1. Criamos o `ActiveCaseLockService` (injetado via Provider / Service locator).
2. O `CroquiController` registra o UUID do laudo aberto em seu `init()` e obrigatoriamente desregistra no `dispose()`.
3. Durante a etapa de Pull, o `SyncService` consulta o `ActiveCaseLockService`. Caso o laudo remoto coincida com o UUID em edição ativa na UI:
   - O `SyncService` **não sobrescreve** o SQLite para este laudo;
   - Registra o UUID em um conjunto transitório de `laudosIgnoradosPorEdicaoAtiva`;
   - O restante dos casos é sincronizado normalmente.
4. Ao fechar a tela do croqui (`dispose()`), a lista da Home detecta a pendência e agenda um Pull limpo para ingerir o delta remoto com segurança.

## Considered Options
- **Coluna `is_being_edited` persistida no SQLite**: Rejeitada porque falhas de energia ou encerramento abrupto do app pelo SO deixariam a flag travada em `1` para sempre, bloqueando permanentemente a sincronização daquele laudo.
- **Pausa Total de Sync durante Edição**: Rejeitada por impedir que outros laudos finalizados subam para a central enquanto o perito digita um novo caso.
- **Merge Automático de Campos em Staging**: Rejeitado pela alta complexidade de reconciliação de dados clínicos conflitantes sem intervenção humana.
