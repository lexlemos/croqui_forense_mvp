# Auditoria Arquitetural - Croqui Forense MVP (v1)

**Data:** 2026-04-28
**Auditor:** Lideranca Tecnica (Claude)
**Escopo:** Varredura completa de `/lib` com base nas regras de `/docs` e `CLAUDE.md`
**Branch:** `refactor/code-hygiene-cycle-1`

---

## 1. Resumo da Saude Geral

A estrutura do projeto demonstra uma **base arquitetural solida e bem-intencionada**: a separacao em camadas (core, data, domain, presentation) existe, o `SyncService` respeita a inversao de dependencia via `ISyncRepository`, o `SecurityHelper` usa PBKDF2 com constant-time comparison, e o fluxo de criptografia com cleanup via `try/finally` esta correto.

Porem, a execucao apresenta **inconsistencias graves** que comprometem a Cadeia de Custodia, a integridade da sincronizacao e a testabilidade do codigo. Existem quebras de Clean Architecture pontuais mas criticas, codigo morto que referencia tabelas inexistentes, e um bug de hardcode no `SyncService` que atribui todos os laudos sincronizados a um unico usuario fixo.

**Veredito:** O app funciona para demonstracao local, mas a sincronizacao com o backend esta estruturalmente quebrada em pelo menos 3 pontos criticos. Refatoracao necessaria antes de qualquer teste de integracao real.

---

## 2. Areas Problematicas Detalhadas

### PRIORIDADE CRITICA - Risco a Integridade e Cadeia de Custodia

---

#### C1. Hardcode de `id_usuario_criador` no payload de sincronizacao

**Arquivo:** `lib/domain/services/sync_service.dart`, linha ~432
**Descricao:** O metodo `_casoParaJson()` ignora `caso.idUsuarioCriador` e envia um UUID fixo hardcoded:
```dart
'id_usuario_criador': 'eec31ca4-5660-4ee9-9f7a-87a89a67cb17',
```
**Impacto:** TODOS os laudos sincronizados serao atribuidos ao mesmo perito no backend, independente de quem realmente criou o caso. Isso **invalida a Cadeia de Custodia** e viola diretamente a regra de autoria descrita em `/docs/04_api_contracts.md` (campo obrigatorio UUIDv4 do perito).

**Estrategia de correcao:** Substituir pelo campo real `caso.idUsuarioCriador`. O TODO no codigo ja indica a intencao.

---

#### C2. Achados nunca sao enviados na sincronizacao

**Arquivo:** `lib/domain/services/sync_service.dart`, linha ~443
**Descricao:** O metodo `_casoParaJson()` envia `'achados': []` (lista vazia fixa). O metodo `_achadoParaJson()` (linhas 453-480) existe e esta corretamente implementado, mas **nunca e chamado**.
**Impacto:** O backend recebe laudos sem nenhum achado/lesao. O payload viola o contrato `CasoSyncDTO` de `/docs/04_api_contracts.md` que exige a lista de achados populada. Laudos ficam vazios no servidor.

**Estrategia de correcao:** No `_casoParaJson()`, buscar os achados do caso via `_repository.getAchadosPorCaso()` (ja existe no `CasoRepository`) e mapea-los com `_achadoParaJson()`. Isso requer tornar `_casoParaJson` async ou carregar os achados antes no `_pushTextual`.

---

#### C3. Sessao de login nao persiste apos reinicio do app

**Arquivo:** `lib/domain/services/auth_service.dart`, linhas 36-53
**Descricao:** O metodo `login()` autentica o usuario e define `_usuarioLogado`, mas **nunca grava** o `user_id` no `_keyStorage`. O metodo `checkSession()` (linha 61) tenta ler `_keyStorage.read(key: 'user_id')` para restaurar a sessao, mas esse valor nunca foi persistido.
**Impacto:** Toda vez que o app e reiniciado, o perito e deslogado e precisa re-autenticar. Em campo, isso e uma interrupcao operacional significativa.

**Estrategia de correcao:** Adicionar `await _keyStorage.save(key: 'user_id', value: usuario.id)` ao final do fluxo de `login()` bem-sucedido.

---

#### C4. EXIF sendo removido das fotos de evidencia

**Arquivo:** `lib/core/utils/image_helper.dart`, linha 28
**Descricao:** `keepExif: false` na compressao de imagens. Para evidencias forenses, os metadados EXIF (timestamp da captura, coordenadas GPS, modelo do dispositivo) sao parte da Cadeia de Custodia.
**Impacto:** Metadados forenses criticos sao destruidos irreversivelmente no momento da compressao.

**Estrategia de correcao:** Alterar para `keepExif: true`. Se houver preocupacao com privacidade, preservar os EXIF no arquivo local e remove-los seletivamente apenas na exportacao publica.

---

### PRIORIDADE ALTA - Quebras de Clean Architecture

---

#### A1. `InjuryService` (camada domain) acessa banco de dados diretamente

**Arquivo:** `lib/domain/services/injury_service.dart`, linhas 1-58
**Descricao:** Este servico na camada `domain/` importa `DatabaseHelper` e `sqflite_sqlcipher` diretamente, executando queries SQL sem intermediacao de repositorio. Alem disso, referencia uma tabela `injury_markers` que **nao existe** no schema (`database_constants.dart`).
**Impacto:** Viola a Regra de Ouro #1 do CLAUDE.md. Qualquer chamada a esse servico ira crashar em runtime com "table injury_markers not found". E codigo morto perigoso.

**Estrategia de correcao:** Remover `InjuryService` e `InjuryMarker` inteiramente. A funcionalidade de marcadores ja e coberta por `AchadoService` + `Achado` + tabela `achados`. Sao sistemas paralelos para o mesmo conceito.

---

#### A2. `InjuryFormModal` (camada presentation) instancia repositorio diretamente

**Arquivo:** `lib/components/forms/injury_form_modal.dart`, linha 39
**Descricao:** `final InjuryTypeRepository _repository = InjuryTypeRepository()` - Um widget de apresentacao cria uma instancia concreta de repositorio, acessando o banco de dados diretamente.
**Impacto:** Viola a Regra de Ouro #1. A camada `presentation` esta acoplada diretamente a `data/`. Impossivel de testar unitariamente.

**Estrategia de correcao:** Injetar `InjuryTypeRepository` via Provider no `main.dart`, ou criar um `InjuryTypeService` na camada domain e injeta-lo. O widget deve receber os dados via construtor ou Provider.

---

#### A3. `AchadoRepository` e `DiagramaRepository` usam singleton ao inves de injecao

**Arquivo:** `lib/data/repositories/achado_repository.dart`, linha 6
**Arquivo:** `lib/data/repositories/diagrama_repository.dart`, linha 6
**Descricao:** Ambos acessam `DatabaseHelper.instance` diretamente em vez de receber o `DatabaseHelper` via construtor, como fazem `CasoRepository` e `UsuarioRepository`.
**Impacto:** Inconsistencia no padrao de DI. Impossibilita mock em testes unitarios. Cria acoplamento rigido.

**Estrategia de correcao:** Alterar os construtores para receber `DatabaseHelper` como parametro, seguindo o padrao de `CasoRepository(this._dbHelper)`.

---

#### A4. `InjuryTypeRepository` usa singleton ao inves de injecao

**Arquivo:** `lib/data/repositories/injury_type_repository.dart`, linha 5
**Descricao:** `final DatabaseHelper _dbHelper = DatabaseHelper.instance;` - Mesmo problema de A3.

**Estrategia de correcao:** Receber via construtor e registrar no Provider tree do `main.dart`.

---

#### A5. `AchadoService.instance` e um singleton com dependencias concretas

**Arquivo:** `lib/domain/services/achado_service.dart`, linha 13
**Descricao:** `static final AchadoService instance = AchadoService(AchadoRepository(), DiagramaRepository());` - Cria repositorios concretos diretamente, bypassando o container de DI. Usado em `CroquiPage` (linha 28: `AchadoService.instance`).
**Impacto:** O servico fica impossivel de testar, e os repositorios que ele cria internamente nao passam pelo mesmo `DatabaseHelper` gerenciado pelo Provider tree.

**Estrategia de correcao:** Remover o singleton. Registrar `AchadoService` no `main.dart` via `ProxyProvider` com as dependencias injetadas. `CroquiPage` deve ler via `context.read<AchadoService>()`.

---

### PRIORIDADE ALTA - Bugs Funcionais

---

#### B1. `SyncProvider` recriado a cada rebuild, perdendo estado

**Arquivo:** `lib/main.dart`, linha 92
**Descricao:**
```dart
ChangeNotifierProxyProvider<SyncService, SyncProvider>(
  create: (ctx) => SyncProvider(ctx.read<SyncService>()),
  update: (_, syncService, previous) => SyncProvider(syncService), // BUG
),
```
O `update` cria uma instancia **nova** de `SyncProvider` a cada rebuild, em vez de atualizar a existente (como fazem `AuthProvider`, `CaseListProvider` e `UserManagementProvider` com `previous!..updateService()`).
**Impacto:** O estado de sincronizacao (loading, success, error) e descartado silenciosamente. O botao de sync pode parecer travado ou nao reagir.

**Estrategia de correcao:** Adicionar `updateService(SyncService)` ao `SyncProvider` e usar o padrao `update: (_, syncService, previous) => previous!..updateService(syncService)`.

---

#### B2. `AchadoService.salvarAchado` passa UUID do caso como UUID do diagrama

**Arquivo:** `lib/domain/services/achado_service.dart`, linhas 15-19
**Descricao:**
```dart
final casoUuid = achado.diagramaCasoUuid;
await _diagramaRepository.garantirExistencia(casoUuid, achado.diagramaCasoUuid);
```
Ambos os argumentos sao o mesmo valor (`diagramaCasoUuid`). No `CroquiController.addAchado` (linha 102), `diagramaCasoUuid` recebe `casoAtual.uuid` (o UUID do caso), nao o UUID de um diagrama real. Assim, `garantirExistencia` cria um diagrama cujo UUID e o UUID do caso.
**Impacto:** O relacionamento `achados -> diagramas_do_caso -> casos` usa o UUID do caso como UUID do diagrama, quebrando a integridade referencial semantica. Se o backend validar UUIDs distintos, a sincronizacao falhara.

**Estrategia de correcao:** Gerar um UUID real para o diagrama na criacao do caso (ou no primeiro achado) e armazena-lo. O `Achado.diagramaCasoUuid` deve referenciar o UUID do diagrama, nao do caso.

---

#### B3. Modelo `Permissao` declara `id` como `int`, schema usa `TEXT`

**Arquivo:** `lib/data/models/permissao_model.dart`, linha 3
**Descricao:** `final int id;` e `id: map['id'] as int` — mas a tabela `permissoes` define `id TEXT PRIMARY KEY`. O cast `as int` em uma String causara um `TypeError` em runtime.
**Impacto:** Qualquer tentativa de ler permissoes do banco causara crash. Atualmente nao e exercitado no fluxo principal do MVP, mas e uma bomba-relogio.

**Estrategia de correcao:** Alterar o tipo de `id` para `String` no modelo, alinhando com o schema.

---

### PRIORIDADE MEDIA - Performance e Gargalos

---

#### P1. `getAllCases()` usado para buscar um caso especifico (3 ocorrencias)

**Arquivo:** `lib/domain/services/case_service.dart`, linhas 57, 81, 131
**Arquivo:** `lib/presentation/pages/controllers/croqui_controller.dart`, linha 310
**Descricao:** `finalizarCaso()`, `reabrirCaso()`, `exportarJsonUnicoComBase64()` e `_reloadCaso()` carregam TODOS os casos do banco e fazem `firstWhere()` em memoria para encontrar um unico caso por UUID.
**Impacto:** O(n) por operacao. Com centenas de laudos, isso se torna lento e consume memoria desnecessariamente.

**Estrategia de correcao:** Adicionar `getCaseByUuid(String uuid)` ao `CasoRepository` com query WHERE direta. O indice primario do UUID garante O(1).

---

#### P2. Ausencia de `copyWith` no modelo `Caso`

**Arquivo:** `lib/data/models/caso_model.dart`
**Descricao:** O modelo `Caso` e imutavel (todos os campos `final`) mas nao possui metodo `copyWith`. Isso forca a reconstrucao manual em 5+ lugares do codigo:
- `case_service.dart` linhas 63-78, 84-99, 107-123
- `croqui_controller.dart` linhas 208-224
**Impacto:** Cada reconstrucao manual e uma oportunidade de esquecer um campo. Se um novo campo for adicionado ao `Caso`, todos esses pontos precisam ser atualizados ou dados serao silenciosamente perdidos. O modelo `Usuario` ja possui `copyWith` — inconsistencia.

**Estrategia de correcao:** Adicionar `copyWith()` ao `Caso` e ao `Achado`, e substituir todas as reconstrucoes manuais.

---

### PRIORIDADE MEDIA - Manutencao e Higiene de Codigo

---

#### M1. Sistema duplicado de modelos: `InjuryMarker` + `injury_markers` vs `Achado` + `achados`

**Arquivo:** `lib/data/models/injury_marker_model.dart`
**Arquivo:** `lib/domain/services/injury_service.dart`
**Descricao:** `InjuryMarker` e `InjuryService` sao um sistema paralelo ao `Achado` + `AchadoService` + `AchadoRepository`. Ambos representam marcacoes de lesoes no croqui. O `InjuryService` referencia a tabela `injury_markers` que nao existe no schema.
**Impacto:** Confusao para desenvolvedores, codigo morto que pode ser chamado acidentalmente.

**Estrategia de correcao:** Remover `InjuryMarker`, `InjuryService` e quaisquer referencias. O sistema canonico e `Achado`.

---

#### M2. Sistema duplicado de catalogos: `injury_types` vs `tipos_achados`

**Arquivo:** `lib/data/local/database_seeder.dart`, linhas 26-53 e 111-144
**Arquivo:** `lib/core/constants/database_constants.dart`, tabelas `injury_types` e `tipos_achados`
**Descricao:** Duas tabelas diferentes (`injury_types` e `tipos_achados`) armazenam a mesma informacao (tipos de lesao: Equimose, Escoriacao, etc.) com schemas ligeiramente diferentes. O `InjuryFormModal` consome `injury_types` via `InjuryTypeRepository`, enquanto o `AchadoService` referencia `tipos_achados`.
**Impacto:** Dados divergentes entre as duas tabelas. Adicionar um novo tipo de lesao requer atualizar dois lugares.

**Estrategia de correcao:** Unificar em uma unica tabela. Recomendacao: manter `tipos_achados` (que segue a nomenclatura do schema documentado) e migrar o `InjuryTypeRepository` para consultar `tipos_achados`.

---

#### M3. Arquivos de teste/debug dentro de `/lib`

**Arquivo:** `lib/test_s.dart`
**Arquivo:** `lib/debug_body_test.dart`
**Descricao:** Arquivos de teste e debug estao no diretorio de producao `/lib`. Serao incluidos no build final do APK.
**Impacto:** Aumento desnecessario do tamanho do build. `debug_body_test.dart` importa dependencias pesadas (`flutter_svg`, `image`) apenas para debug.

**Estrategia de correcao:** Mover para `/test` ou `/tool`, ou remover se nao forem mais necessarios.

---

#### M4. `SqlCipherDatabaseFactory` e `DatabaseFactoryImpl` sao duplicatas

**Arquivo:** `lib/data/local/sqlcipher_database_factory.dart`
**Arquivo:** `lib/data/local/database_factory_impl.dart`
**Descricao:** Duas implementacoes de `IDatabaseFactory` que fazem exatamente a mesma coisa: delegam para `sqflite_sqlcipher.openDatabase`.
**Impacto:** Confusao sobre qual usar. `SqlCipherDatabaseFactory` nao e referenciada em nenhum lugar do codigo.

**Estrategia de correcao:** Remover `SqlCipherDatabaseFactory`. Manter apenas `DatabaseFactoryImpl`.

---

#### M5. `_achadoParaJson` definido mas nunca chamado (codigo morto)

**Arquivo:** `lib/domain/services/sync_service.dart`, linhas 453-480
**Descricao:** Metodo implementado corretamente mas sem nenhuma chamada no codigo. Relacionado a C2.

**Estrategia de correcao:** Sera resolvido junto com C2 ao integrar achados no payload de sincronizacao.

---

### PRIORIDADE BAIXA - Observacoes e Debitos Controlados

---

#### L1. `LogInterceptor` com `responseBody: true` pode expor dados periciais

**Arquivo:** `lib/core/network/api_client.dart`, linhas 185-189
**Descricao:** Em modo debug, o `LogInterceptor` imprime corpos de resposta completos. Respostas do backend podem conter dados periciais sensiveis.
**Nota:** Nao e um risco de producao (guarded por `bool.fromEnvironment('dart.vm.product')`), mas logs em desenvolvimento podem vazar para screenshots ou ferramentas de debug compartilhadas.

**Estrategia de correcao:** Considerar `responseBody: false` ou limitar o tamanho do log.

---

#### L2. `SecureKeyStorage` instanciado duas vezes

**Arquivo:** `lib/main.dart`, linhas 30 e 42
**Descricao:** `SecureKeyStorage()` e criado em `main()` para o `DatabaseHelper.init()` e novamente em `AppRoot.build()` para o `AuthService`. Embora stateless, cria ambiguidade.

**Estrategia de correcao:** Instanciar uma unica vez e propagar via Provider ou parametro.

---

#### L3. Falta de `onUpgrade` no `DatabaseHelper`

**Arquivo:** `lib/data/local/database_helper.dart`
**Descricao:** Ja documentado em `/docs/02_database_schema.md` como debito tecnico. Nao ha logica de migracao.

**Estrategia de correcao:** Implementar antes da segunda versao do schema. Sem urgencia para o MVP v1.

---

#### L4. `device_id` hardcoded em multiplos locais

**Arquivo:** `lib/domain/services/sync_service.dart`, linha 213 (`'tablet-teste-mvp-01'`)
**Arquivo:** `lib/data/repositories/diagrama_repository.dart`, linha 19 (`'APP_TABLET'`)
**Descricao:** Ja documentado em `/docs/04_api_contracts.md` como debito tecnico da fase MVP.

**Estrategia de correcao:** Substituir por `device_info_plus` quando sair da fase MVP.

---

## 3. Matriz de Priorizacao para Refatoracao

| # | ID | Descricao | Risco | Esforco |
|---|-----|-----------|-------|---------|
| 1 | C1 | Hardcode id_usuario_criador no sync | Cadeia de Custodia | Baixo |
| 2 | C2 | Achados nunca enviados no sync | Integridade de Dados | Medio |
| 3 | C3 | Sessao de login nao persiste | Operacional | Baixo |
| 4 | C4 | EXIF removido das evidencias | Cadeia de Custodia | Baixo |
| 5 | B1 | SyncProvider recriado a cada rebuild | Bug Funcional | Baixo |
| 6 | B2 | UUID do diagrama = UUID do caso | Integridade Relacional | Medio |
| 7 | B3 | Permissao.id tipo int vs TEXT | Crash em Runtime | Baixo |
| 8 | A1 | InjuryService acessa DB direto | Arquitetura | Medio |
| 9 | A2 | InjuryFormModal instancia repo | Arquitetura | Medio |
| 10 | A3 | Repos sem injecao de dependencia | Arquitetura/Testabilidade | Medio |
| 11 | A4 | InjuryTypeRepository singleton | Arquitetura/Testabilidade | Baixo |
| 12 | A5 | AchadoService.instance singleton | Arquitetura/Testabilidade | Medio |
| 13 | P1 | getAllCases() para busca unitaria | Performance | Baixo |
| 14 | P2 | Ausencia de copyWith em Caso | Manutencao | Medio |
| 15 | M1 | InjuryMarker duplica Achado | Codigo Morto | Medio |
| 16 | M2 | injury_types duplica tipos_achados | Dados Divergentes | Medio |
| 17 | M3 | Arquivos debug em /lib | Build Size | Baixo |
| 18 | M4 | SqlCipherDatabaseFactory duplicata | Codigo Morto | Baixo |
| 19 | M5 | _achadoParaJson nunca chamado | Codigo Morto | Resolvido com C2 |

---

## 4. Recomendacao de Ciclos de Refatoracao

**Ciclo 1 (Urgente):** C1, C2, C3, C4, B1, B3 — Correcoes cirurgicas que nao alteram arquitetura. Todos sao ajustes de 1-5 linhas, exceto C2 que requer integracao do `_achadoParaJson`.

**Ciclo 2 (Estrutural):** A1-A5, M1, M2 — Unificacao do sistema de modelos (remover InjuryMarker/InjuryService), padronizar injecao de dependencia em todos os repositorios, e remover a duplicidade de catalogo.

**Ciclo 3 (Qualidade):** P1, P2, B2, M3, M4 — Adicionar `getCaseByUuid`, `copyWith`, corrigir UUID do diagrama, limpar codigo morto.

---

*Aguardando aprovacao para iniciar o Ciclo 1 de refatoracao.*
