# Laudo Pericial em PDF — guia de porte para o sistema web

**O que é isto.** A especificação de como o app Flutter monta o PDF do **Laudo Pericial Cadavérico**, escrita para quem vai reproduzir essa visualização no sistema web. Cobre a decisão de arquitetura, os tokens de página, o contrato de dados e o documento bloco a bloco, com as armadilhas já mapeadas.

**Como usar.** Se você só quer *ver* o laudo no web, leia a seção 0 e o caminho A da seção 7 — é meia hora de trabalho. O resto do documento é a especificação do caminho B (re-renderizar em HTML), que você só precisa se quiser o laudo como DOM.

**Fonte da verdade.** Este documento é o mapa; o território são os arquivos em `lib/domain/services/`. Cada bloco abaixo aponta o método exato que o produz, e onde este guia e o código divergirem, o código vence.

---

## 0. Antes de escrever código: escolha o caminho

O PDF **não é gerado no backend**. Ele é compilado no dispositivo pelo app Flutter (pacote `pdf: ^3.11.1`, em isolate), gravado em `laudo_{uuid}.pdf` no sandbox e depois enviado por upload multipart (`POST /croqui/sync/laudo-pdf`), que devolve a `pdf_url` gravada em `casos.pdf_url`.

| | Caminho A — exibir o artefato | Caminho B — re-renderizar em HTML |
|---|---|---|
| O que faz | Busca `pdf_url` e renderiza os bytes com pdf.js / `<iframe>` | Reconstrói o laudo em HTML/CSS a partir dos dados do backend |
| Fidelidade | Total, por construção: é o mesmo arquivo | Depende de replicar tokens e regras (este guia) |
| Esforço | Baixo | Alto |
| Quando faz sentido | Requisito é "conferir/baixar/imprimir o laudo" | Precisa de busca no texto, destaque de trecho, layout responsivo, laudo editável/comentável, ou o laudo **antes** de o PDF existir |
| Cuidados | Autenticação/CORS na URL do arquivo; casos sem `pdf_url` (laudo ainda não finalizado no dispositivo) não têm o que exibir | Divergência silenciosa a cada mudança no app; a numeração das fotos é posicional (ver §8) |

**Recomendação:** faça o caminho A primeiro, mesmo que o objetivo final seja o B. Ele entrega valor imediato, serve de referência visual para calibrar o B e cobre o caso de uso mais provável (conferência e impressão). O B só se paga se houver requisito de DOM.

O restante do guia serve aos dois: as seções 1–6 são a especificação do B, e as seções 2, 6.1–6.2 e 7.1 são o que o A precisa.

---

## 1. Mapa do código

| Arquivo | Papel | O que copiar de lá |
|---|---|---|
| `lib/domain/services/pdf_service.dart` | **O documento inteiro.** Ordem dos blocos, textos fixos, agrupamento anatômico, croquis, fotos, encerramento | A ordem e o conteúdo de cada seção (§5, §6) |
| `lib/domain/services/pdf_constants.dart` | Constantes oficiais: margens, mapeamento anatômico, títulos internos, texto de encerramento | Margens (§3) e o agrupamento (§6.6) |
| `lib/domain/services/pdf_helpers.dart` | Widgets reutilizáveis: parágrafo com recuo, linha label+valor, título de seção, cabeçalho, rodapé, ano por extenso | Os estilos nomeados de §4 e §6.1–6.2 |
| `lib/domain/services/pdf_report_service.dart` | Orquestra geração + gravação em disco e sanitização de PDFs órfãos | Nada de layout; é o que chama o motor |
| `lib/domain/services/pdf_generation_service.dart` | Fachada usada pelos controllers | Nada de layout |
| `lib/presentation/pages/pdf_preview_page.dart` | Como o app **visualiza**: `PdfPreview` (pacote `printing`), `maxPageWidth: 700`, `dpi: 72` | Referência do visualizador (§7.1) |
| `lib/presentation/utils/achado_formatter.dart` | Formata os campos dinâmicos de cada achado (`obterCamposFormatados`) | A regra dos campos extras (§6.6) |
| `lib/data/models/dados_laudo_model.dart` | Estrutura de `dados_laudo_json` | O contrato da §2 |
| `lib/data/models/achado_model.dart` | Estrutura do achado e `dados_preenchidos_json` | O contrato da §2 |
| `lib/data/datasources/remote_data_source_impl.dart` | `uploadLaudoPdf` → `POST croqui/sync/laudo-pdf`, devolve `pdf_url` | O contrato do caminho A (§7.1) |
| `tool/export_pdf_layout.dart` | Gera `docs/handoff/mapeamento-anatomico.json` a partir de `pdf_constants.dart` | Rode para portar o agrupamento sem redigitar |

Nenhum ajuste de backend é necessário para o caminho A: `pdf_url` já chega ao servidor central em `casos.pdf_url`.

---

## 2. Contrato de dados

Os nomes abaixo são as chaves que o app envia no push (`Caso.toSyncMap()` e `Achado.toSyncMap()`) e que o backend persiste. É o que o web tem para trabalhar.

### 2.1 Nível do caso

| Campo | Usado em |
|---|---|
| `numero_requisicao`, `numero_laudo_externo` | Cabeçalho das páginas 2+ e linha "Laudo Pericial Cadavérico nº CD" |
| `numero_bo`, `numero_pic`, `requisitante`, `destino`, `nome_vitima` | Bloco de dados iniciais |
| `atns_ids` (lista) | Linha "Técnico(s) de Necrópsia", só quando não vazia |
| `criado_em_dispositivo` | Data da frase de abertura |
| `finalizado_em`, `status_pericia` | Não impressos diretamente (a data impressa vem de `auditoria.data_finalizacao`) |
| `hash_integridade` | Bloco de certificação (12 primeiros caracteres) |
| `causa_morte[]` | Seção 10, quesito II |
| `dados_laudo_json` | Todo o corpo textual (abaixo) |
| `pdf_url` | Caminho A |

### 2.2 `dados_laudo_json`

```
identificacao   { historico, vestes, sexo, fotos[] }
caracteristicas { identificacao, tanato_imediato, tanato_consecutivo, tanato_observacao }
conclusao       { discussao, conclusao_texto,
                  quesito_1_morte, quesito_2_causa, quesito_3_instrumento, quesito_4_meio }
cabecalho       { descricao }            // não usado no PDF atual
auditoria       { perito_responsavel, data_finalizacao }
```

`causa_morte[]` traz `{ imediata, devido_a, consequencia }` por item.

### 2.3 Achado

```
uuid, numero_sequencial, pos_x, pos_y, tipo_achado_id, versao, removido,
observacoes_texto, tamanho, vista_anatomica, local_anatomico, tipo_ferimento,
numero_lacre, tipo_objeto, comentario_adicional, criado_em, atualizado_em,
dados_preenchidos_json { ... }
```

Dentro de `dados_preenchidos_json`, o motor de PDF usa:

| Chave | Uso |
|---|---|
| `view` | Qual croqui desenha o achado (§6.8). Ausente ⇒ `frente` |
| `local_anatomico_id` | Decide o grupo das seções 3/4 (§6.6) |
| `local_anatomico_nome` | Texto da linha do achado |
| `type_label` | Rótulo do tipo da lesão ("Entrada de PAF", "Equimose"…) |
| `photo_path` | Caminho local da foto — **só existe no dispositivo** |
| `dados_dinamicos_json` (ou `dynamicFields`) | Campos extras por tipo de lesão (§6.6) |

### 2.4 Ordenação — leia antes de numerar qualquer coisa

`getAchadosPorCaso` consulta com `WHERE caso_uuid = ? AND removido = 0 ORDER BY criado_em DESC`. Consequências que aparecem no laudo:

- **Seções 3/4 e registro fotográfico listam os achados do mais novo para o mais antigo**, mas imprimem o prefixo `${numero_sequencial}.` — então a sequência impressa tende a ser decrescente (`5. …`, `4. …`). Se o produto quer numeração crescente, ordene por `numero_sequencial ASC` — mas isso **muda o PDF atual**, então é decisão de produto, não do porte.
- **A numeração de fotografias é posicional** (§6.9), e depende dessa mesma ordem mais a ordem das evidências gerais. Ver §8, item 3.

---

## 3. Tokens de página

| Token | Valor no app | Equivalente |
|---|---|---|
| Formato | `PdfPageFormat.a4` = 21,0 × 29,7 cm | 595,28 × 841,89 pt |
| Margem esquerda | 85,05 pt | 3 cm (encadernação) |
| Margem superior | 28,35 pt | 1 cm |
| Margem direita | 56,7 pt | 2 cm |
| Margem inferior | 56,7 pt | 2 cm |
| **Área útil** | 453,53 × 756,84 pt | 160 × 267 mm |

Duas observações que economizam tempo:

1. `PdfPageFormat.a4` do pacote traz margem padrão de 2 cm em todos os lados, mas ela é **sobrescrita** por `PdfConstants.marginDefault` (`pdf_service.dart`, `pageTheme`). Vale a tabela acima.
2. **Cabeçalho e rodapé ficam dentro da área útil**, não nas margens. O `MultiPage` do pacote reserva a altura do header no topo da área útil e a do footer no pé, e o conteúdo flui entre os dois (`multi_page.dart`, linhas 497–537). Ou seja: 1 cm de papel em branco no topo, depois o cabeçalho, depois o conteúdo.

Em CSS, isso é `padding: 28.35pt 56.7pt 56.7pt 85.05pt` na "folha". CSS aceita `pt` nativamente — **cole os números do app direto no CSS** e você evita toda conversão.

---

## 4. Tipografia e cores

**Fonte:** `Roboto-Regular.ttf` e `Roboto-Bold.ttf` de `assets/fonts/`, embutidas no PDF via `pw.ThemeData.withFont(base, bold)`. Para o web, sirva os mesmos dois TTFs por `@font-face` — com outra fonte, as quebras de linha divergem.

**Exceção que pega todo mundo:** o código pede `fontStyle: italic` em três lugares, mas `withFont` só recebe base e bold, então a "vaga" do itálico fica com o padrão do pacote — **Helvetica Oblique** (uma fonte Type1 base-14, não Roboto e não uma inclinação sintética): `TextStyle.defaultStyle()` já vem com `fontItalic: Font.helveticaOblique()` e o `copyWith` de `withFont` não sobrescreve. Ou seja, esses textos saem em **outra família** no PDF. Decida com o time: ou o app passa um `Roboto-Italic.ttf` para `withFont` (aí o web usa `font-style: italic` na Roboto), ou o web replica a divergência. Enquanto isso, não prometa "itálico Roboto" a ninguém.

| Estilo | Tamanho | Peso/estilo | Onde |
|---|---|---|---|
| Título do documento ("LAUDO CADAVÉRICO") | 12 | bold | Dados iniciais |
| Instituição no cabeçalho (pág. 1) | 11 | bold | "INSTITUTO MÉDICO-LEGAL" |
| Título de seção ("1. HISTÓRICO") | 11 | bold | As 10 seções |
| Governo/secretaria (pág. 1) | 10 e 8 | bold / regular | Cabeçalho pág. 1 |
| Corpo de texto | 10 | regular | Parágrafos, dados iniciais, achados, quesitos |
| Rótulos em negrito | 10 | bold | `buildLinhaDetalhe`, `buildItemComLabel`, títulos de grupo |
| Títulos de bloco da seção 5 | 10 | bold | "A) EXAME TOXICOLÓGICO" |
| Sub-títulos / itens da seção 5 | 9,5 | bold / regular | Frasco, materiais, lacres |
| Sub-item da seção 5 | 9 | regular | "Solicita quantificacao de drogas" |
| Campos dinâmicos do achado | 8,5 | itálico → Helvetica Oblique | Sob a linha do achado |
| CRM / classe do perito | 8,5 | regular cinza | Assinatura |
| Rodapé institucional | 7 / 6 | bold / regular | Endereço, telefone, paginação |
| Certificação de integridade | 7 / 7,5 / 6,5 | ver §6.12 | Bloco final |

**Cores** (`PdfColors` = paleta Material):

| Token | Hex | Uso |
|---|---|---|
| `red` | `#F44336` | Círculo numerado sobre o croqui |
| `white` | `#FFFFFF` | Número dentro do círculo |
| `grey` | `#9E9E9E` | Borda das fotografias |
| `grey50` | `#FAFAFA` | Fundo do bloco de certificação |
| `grey300` | `#E0E0E0` | Bordas de croqui/certificação |
| `grey600` | `#757575` | Texto do hash |
| `grey700` | `#616161` | CRM, classe, texto legal da certificação |
| `indigo900` | `#1A237E` | Título da certificação |
| `black` / `grey300` | `#000000` / `#E0E0E0` | Linhas divisórias |

**Ritmo vertical (detalhes que só aparecem comparando lado a lado):**

- `pw.Text` não recebe line-height explícito: a altura da linha vem das métricas da Roboto (≈1,17 em). Em 10 pt, ≈11,7 pt por linha.
- `pw.Divider` é uma **caixa de 16 pt** com o traço centralizado: `thickness: 0.5` deixa ≈7,75 pt de respiro acima e abaixo do traço.
- `pw.Bullet` (só na seção 10): ponto de 2 mm (5,67 pt), com margens top 1,5 mm / esquerda 5 mm / direita 2 mm, e 2 mm abaixo de cada item; o tema do pacote ainda soma `lineSpacing: 5` nas quebras de linha.

---

## 5. Esqueleto do documento

Ordem exata de `_gerarLaudoPdfIsolate` (`pdf_service.dart`), com os espaçadores entre blocos:

| # | Bloco | Origem |
|---|---|---|
| | `SizedBox(10)` | — |
| 0a | Dados iniciais (7 linhas + título centralizado) | `_buildDadosIniciais` |
| | `SizedBox(20)` | — |
| 0b | Frase de abertura | `_buildTextoAbertura` |
| | `SizedBox(15)` | — |
| 1 | **1. HISTÓRICO** | `identificacao.historico` ou `"XXX"` |
| 2 | **2. IDENTIFICAÇÃO** | `_buildIdentificacaoOficial` |
| 3 | **3. EXAME EXTERNO** | `_buildExameAgrupado(isInterno: false)` |
| 4 | **4. EXAME INTERNO (Cavidades)** | `_buildExameAgrupado(isInterno: true)` |
| 5 | **5. EXAMES COMPLEMENTARES** | `_buildDadosComplementares` |
| 6 | **6. RASCUNHOS E ESQUEMAS DE LESÃO** | `_gerarMapasSVGSincrono` |
| 7 | **7. REGISTRO FOTOGRÁFICO** | `_buildSecaoFotos` |
| 8 | **8. COMENTÁRIO MÉDICO FORENSE** | `conclusao.discussao` ou `"XXX"` |
| 9 | **9. CONCLUSÃO** | `conclusao.conclusao_texto` ou `"XXX"` |
| | `SizedBox(10)` + parágrafo de encerramento padrão | `PdfConstants.encerramentoPadrao` |
| 10 | **10. RESPOSTA AOS QUESITOS** | `_buildDadosQuesitosOficial` |
| | `SizedBox(40)` | — |
| | Encerramento + certificação (centralizado) | `_buildEncerramento` |

Todas as seções são separadas por `SizedBox(15)` e os títulos usam `buildSectionTitle` (11 pt bold, 12 pt acima e 4 pt abaixo). A quebra de página é automática do `MultiPage`: nenhum bloco tem quebra forçada, então um grupo anatômico pode começar no fim de uma página.

---

## 6. Bloco a bloco

### 6.1 Cabeçalho (difere entre a página 1 e as demais)

`PdfHelpers.buildDynamicHeader` recebe `context.pageNumber`; o número do laudo é `numero_requisicao` se não vazio, senão `numero_laudo_externo`.

**Página 1** — logo `logo-policia-se.jpeg` 60 × 60 pt centralizada; 5 pt; quatro linhas centralizadas:

```
GOVERNO DO ESTADO DE SERGIPE                                   (10 pt, bold)
SECRETARIA DE ESTADO DA SEGURANÇA PÚBLICA DE SERGIPE           (8 pt)
COORDENADORIA GERAL DE PERÍCIAS                                (8 pt)
INSTITUTO MÉDICO-LEGAL                                         (11 pt, bold)
```

…com 15 pt de margem inferior.

**Páginas 2+** — uma linha com o logo 25 × 25 pt à esquerda, 8 pt de espaço, `Laboratório de Tanatologia Forense` (8 pt) e, à direita, `Laudo Cadavérico nº CD {número}` (8 pt bold); abaixo, `Divider(thickness: 0.5)` (preto, caixa de 16 pt). Margem inferior de 10 pt.

> No web: um cabeçalho `position: fixed` repetiria o institucional na página 1 também. Ou você pagina explicitamente (folhas como `<div>` de altura fixa), ou aceita o cabeçalho compacto em todas as páginas. Ver §7.2.

### 6.2 Rodapé (todas as páginas)

`PdfHelpers.buildInstitucionalFooter`, centralizado, exceto a paginação:

```
Divider(thickness: 0.5)                                        (preto, caixa 16 pt)
INSTITUTO MÉDICO-LEGAL                                         (7 pt, bold)
Rua da Frente, S/N, Povoado Tabocas, Nossa Senhora do Socorro/SE – CEP: 49160-000   (6 pt)
Fone: (79) 3205-0636 – e-mail: laudos.iml@policiatecnica.se.gov.br                  (6 pt)
                                              Página {n} de {total}   (6 pt, à direita)
```

### 6.3 Dados iniciais e abertura

`_buildDadosIniciais` usa `buildLinhaDetalhe`: rótulo bold 10 pt em coluna fixa de **170 pt**, valor 10 pt ao lado, 2 pt abaixo por linha. Quando o campo está vazio, imprime `XXX`:

```
Laudo Pericial Cadavérico nº CD   {numero_requisicao | numero_laudo_externo | XXX}
Boletim de Ocorrência (B.O.):     {numero_bo | XXX}
PIC:                              {numero_pic | XXX}
Requisitante: Delegado (a)        {requisitante | XXX}
Destino:                          {destino | XXX}
Nome da vítima:                   {nome_vitima | XXX}          (valor em bold)
Técnico(s) de Necrópsia:          {atns_ids.join(", ")}         (só se a lista não for vazia)
```

Depois, 20 pt e `LAUDO CADAVÉRICO` centralizado (12 pt bold).

`_buildTextoAbertura` monta a data a partir de `criado_em_dispositivo` (em hora local) e o ano por extenso via `PdfHelpers.anoPorExtenso` (só cobre 2000–2099; fora disso devolve o número):

> "No dia {dd} do mês de {mês} do ano de {ano por extenso}, neste Instituto de Medicina Legal da Coordenadoria Geral de Perícias da Secretaria de Estado da Segurança Pública de Sergipe, em conformidade com a legislação e com os dispositivos regulamentares vigentes, foram designados, o Perito Médico-Legal Dr. Ronmel Lisboa dos Santos e os Agentes técnicos em Necropsia para procederem a exame pericial, a fim de atender ao ofício retro, descrevendo fielmente e com todas as circunstâncias o que encontrarem e, bem assim, esclarecerem tudo quanto interessar possa com relação ao exame solicitado."

O nome do perito nessa frase é **literal** — ver §8, item 4.

**Recuo do parágrafo:** `buildParagrafoComRecuo` não usa indent de verdade; ela prefixa **10 espaços** ao texto e justifica. Em Roboto 10 pt isso equivale a ≈24,75 pt. No HTML os espaços iniciais são colapsados — use `text-indent: 24.75pt` e `text-align: justify`.

### 6.4 Seção 1 — HISTÓRICO

`buildParagrafoComRecuo(identificacao.historico)` ou `"XXX"` quando vazio.

### 6.5 Seção 2 — IDENTIFICAÇÃO

`_buildIdentificacaoOficial`, três itens romanos com 5 pt entre eles:

- **`I) Vestes:`** (10 pt bold) + `buildParagrafoComRecuo(identificacao.vestes ou "XXX")`.
- **`II) Características de identificação:`** (10 pt bold) + o parágrafo **literal**: `Cadáver do sexo XXX, raça XXX, estado nutricional XXX, e idade aparente de XX anos.` — o texto não é montado a partir dos dados do caso (§8, item 5).
- **`III) Dados tanatológicos:`** (10 pt bold), depois, com 15 pt de recuo: a frase `A morte está evidenciada pela presença dos seguintes sinais tanatológicos:` (10 pt) e três itens `buildItemComLabel` (rótulo bold + valor), 3 pt entre eles:
  - `A) IMEDIATOS: ` → `caracteristicas.tanato_imediato` ou `XXX`
  - `B) CONSECUTIVOS: ` → `caracteristicas.tanato_consecutivo` ou `XXX`
  - `COMENTARIOS ADICIONAIS: ` → `caracteristicas.tanato_observacao` ou `XXX` (sem acento, como no código)

### 6.6 Seções 3 e 4 — EXAME EXTERNO / INTERNO (o agrupamento anatômico)

`_buildExameAgrupado` é o mesmo método para as duas seções; muda o título dos grupos e os textos de vazio. O algoritmo, na ordem:

1. **Separação:** `isInterno` divide os achados em dois conjuntos. `removido = true` nunca aparece (o repositório já filtra; o serviço filtra de novo).
2. **Grupos:** itera `PdfConstants.mapeamentoAnatomico` **na ordem de declaração** — `I) Crânio e Face`, `II) Pescoço`, `III) Membros`, `IV) Tórax`, `V) Abdome` (o porte fiel dessas listas está em `mapeamento-anatomico.json`, gerado do próprio Dart).
3. **Casamento:** o achado entra no grupo quando `local_anatomico_id` (com `trim` + `toLowerCase`) está na lista do grupo. Cada achado é consumido no primeiro grupo que o reclamar (`removeWhere`), então os ids repetidos entre listas — que existem — não duplicam nada.
4. **Título do grupo:** externo = o próprio texto do mapa; interno = `PdfConstants.titulosInternos`:

   | Grupo no mapa | Título no exame interno |
   |---|---|
   | `I) Crânio e Face` | `I) Cavidade craniana` |
   | `II) Pescoço` | `II) Pescoço` |
   | `III) Membros` | `III) Membros` |
   | `IV) Tórax` | `IV) Cavidade torácica` |
   | `V) Abdome` | `V) Cavidade abdominal` |

   O título é impresso como `{título}:` (10 pt bold, 6 pt acima).
5. **Grupo vazio** (recuo 15 pt, 10 pt):
   - externo: `Sem evidências de lesões macroscópicas de natureza traumática.`
   - interno: `Sem alterações macroscópicas dignas de nota.`
6. **Grupo com achados** — no externo, antes da lista, a linha (recuo 15 pt): `Com evidências de lesões macroscópicas:`. No interno essa linha **não existe**.
7. **Cada achado** (recuo 30 pt, 2 pt acima), nesta forma:

   ```
   {numero_sequencial}. {type_label} em {local_anatomico_nome}: {observacoes_texto}[ [VER REGISTRO FOTOGRÁFICO {n}]]
   ```

   O sufixo de foto sai quando existe um anexo com o mesmo `uuid` do achado (§6.9). E, abaixo, com mais 15 pt de recuo, os **campos formatados** em 8,5 pt itálico, um por linha, no formato `{label}: {valor}` — a regra está em `achado_formatter.dart`:
   - `Tamanho` — valor de `tamanho` (com ` cm` se não terminar em letra);
   - `Profundidade` — valor de `profundidade`;
   - `Orifício de Entrada Vinculado` — quando há `achadoRelacionadoUuid`: `Achado nº {numeroSequencial} ({type})` se o alvo estiver na lista, senão `Vinculado (ID: {8 primeiros})`;
   - os pares de `dados_dinamicos_json` (ou `dynamicFields`), ignorando chaves que começam com `_`, valores nulos/vazios e as chaves `photo_path`, `photoPath`, `view`, `local_anatomico_id`, `local_anatomico_nome`, `type_label`, `typeId`, `is_interno`, `isInterno`, `achadoRelacionadoUuid`. Booleanos viram `Sim`/`Não`; valores que casam com o `uuid` de outro achado viram `Achado nº N (tipo)`.
   - **Rótulo:** quando o `schemas` do tipo está disponível, usa `campos[].label` do schema; senão, converte a chave para Title Case (`tipo_ferimento` → `Tipo Ferimento`). No fluxo atual do app o `schemas` chega **nulo** (§8, item 1), então o laudo real usa o Title Case.
8. **Sobras:** os achados que não casaram com nenhum grupo vão para o bloco final `OUTRAS REGIÕES NÃO MAPEADAS:` (10 pt bold, 10 pt acima), seguido de `Com evidências de lesões:` (recuo 15 pt) e das mesmas linhas de achado — mas com o id explícito no texto: `… em {local_anatomico_nome} (ID: {local_anatomico_id}): …`. Esse bloco é montado no fim do método **sem consultar `isInterno`**, então ele aparece nas duas seções (com os mesmos dois rótulos), sempre que sobrar achado.

### 6.7 Seção 5 — EXAMES COMPLEMENTARES

Há **dois formatos**, e o web precisa saber qual está valendo:

**Formato rico** (`examesModel` não vazio): um bloco por exame, com letra sequencial `A`, `B`, `C`, `D`, `E` (do sexto em diante, o número: `6)`, `7)`…). Só `TOXICOLOGICO`, `GENETICA` e `ANATOMO` geram bloco — outros tipos são pulados, mas **ainda consomem a letra**.

- **`{letra}) EXAME TOXICOLÓGICO`** (10 pt bold, 10 pt acima/4 pt abaixo). Sem detalhes: `Detalhes não disponíveis.`
  - `Histórico da Ocorrência:` (9,5 pt bold, recuo 15 pt) + o valor (se `historicoOcorrencia == 'Outro'`, imprime `Outro: {historicoOutro}`; senão `Não informado` como fallback).
  - `Materiais Biológicos Solicitados:` quando há algum material, e então, com recuo 25 pt (9,5 pt): `- Sangue (SG) [Veia Femoral, Cavidade Cardíaca, Outro sítio: x] — Lacre: {n}` (sub-linhas de 9 pt com recuo 38 pt), `- Urina (UR)`, `- Humor Vitreo (HV)`, `- Conteudo Estomacal (CE)`, `- Pulmao (PM)` — todas com `— Lacre: {número | Não informado}`.
  - Nenhum material marcado: `Nenhum material selecionado.`
- **`{letra}) EXAME GENÉTICO E BIOLÓGICO`**: separa as amostras em `Amostras Questionadas:` (`tipoAmostra != SWAB_BUCAL_VITIMA`) e `Amostra de Referencia:` (swab bucal), com lacre do envelope em cada linha e as pesquisas entre colchetes (`[Pesquisa de Semen + Pesquisa de DNA]`). Vazio: `Nenhuma amostra registrada.`
- **`{letra}) EXAME ANÁTOMO-PATOLÓGICO (HISTOPATOLÓGICO)`**: frascos ordenados por `numeroFrasco`; cada um abre com `Frasco {NN} — Lacre: {n}` (9,5 pt bold, recuo 15 pt) e lista órgãos (`Coracao | Figado | Baco | Encefalo | Rim D. | Rim E. | Pulmao (LSD, LMD, …)`), `Pele — Regiao:`, `Partes Moles — Regiao:`, `Outras — Descricao:`. Frasco sem nada: `(Frasco sem conteudo especificado)`. Vazio: `Nenhum frasco registrado.`

**Formato legado** (`examesModel` nulo/vazio): quatro linhas `buildItemComLabel` com lacre ou `NÃO SOLICITADO` — `Anátomo-Patológico (Nº do Lacre): `, `Toxicológico (Nº do Lacre): `, `Genética (Nº do Lacre): `, `Outros (Nº do Lacre): `.

### 6.8 Seção 6 — Rascunhos e esquemas de lesão (croquis)

Para cada `view` presente nos achados ativos (`!removido`), na ordem em que a vista aparece pela primeira vez:

1. `VISTA: {VIEW EM MAIÚSCULAS}` (10 pt bold, centralizado), 5 pt, e uma caixa de **318 × 450 pt** com borda `grey300`.
2. Dentro da caixa: o SVG da vista esticado com `BoxFit.fill` (ou seja, o `viewBox` do arquivo **não** importa para o posicionamento — a régua é a caixa).
3. Sobre o SVG, um marcador por achado da vista: círculo de **14 × 14 pt**, `red`, com `${numero_sequencial}` centralizado em 8 pt bold branco, posicionado em:

   ```
   left = (posX * 318) - 7        top = (posY * 450) - 7      // posX/posY normalizados 0..1; NaN ⇒ 0.5
   ```

4. Cada vista é um `pw.Wrap` de um filho só — ou seja, **empilha uma vista por linha**, com 20 pt abaixo e 15 pt à esquerda. Não há grade de duas colunas.
5. Se nenhuma vista tem SVG carregado, a seção imprime `Sem rascunhos anexados.`

**Arquivo de cada vista** (`_carregarSvgs`):

| `view` | Asset |
|---|---|
| `frente` | `croqui-frente.svg` |
| `costas` ou `back` | `croqui-costas.svg` |
| `lateral_dir` | `face-lateral-direita.svg` |
| `lateral_esq` | `face-lateral-esquerda.svg` |
| `trunk_dir` | `tronco-direito-contorno.svg` |
| `trunk_esq` | `tronco-esquerdo-contorno.svg` |
| `perineal` | `perineo_feminino.svg` se `dados_laudo.identificacao.sexo` começar com `f`, senão `perineo_masculino.svg` |
| `face_dir` | `croqui-rosto-direito.svg` |
| `face_esq` | `croqui-rosto-frente.svg` (ver §8, item 7) |
| qualquer outra | `croqui-frente.svg` |

Duas regras que não aparecem em nenhum outro lugar:

- **Filtro perineal:** na vista `perineal`, só entram achados cujo `local_anatomico_id` comece com `male_` ou `female_`, conforme o sexo (masculino = não começa com `f`). Achados perineais sem esse prefixo não são plotados — embora continuem aparecendo nas seções 3/4, se o id estiver no mapa.
- **Sanitização do SVG:** o app remove os atributos `xmlns:inkscape` e `xmlns:sodipodi` antes de entregar o SVG ao parser do pacote `pdf`, que engasga com esses namespaces. No navegador, **não faça isso**: SVG do Inkscape renderiza nativamente.

Os 10 SVGs estão em `assets/images/` e podem ser copiados como estão.

### 6.9 Seção 7 — Registro fotográfico

**Numeração e rótulos** (`_prepararFotos`), contador único começando em 1:

1. Primeiro as **evidências gerais** com `caminhoArquivoEncriptado` não vazio, na ordem em que vieram: `Fotografia {n} - Identificação Geral`.
2. Depois as **fotos dos achados** com `photo_path` não vazio, na ordem dos achados (§2.4): `Fotografia {n} - Ref. Achado {numero_sequencial} ({type_label})`. Esses anexos carregam o `uuid` do achado, e é por ele que as seções 3/4 escrevem `[VER REGISTRO FOTOGRÁFICO {n}]`.
3. Se o arquivo não existe no disco, o rótulo ganha o sufixo ` [IMAGEM INDISPONÍVEL]` e entra uma imagem PNG de 1 × 1 px no lugar — o laudo sai com o rótulo e a moldura vazia.

**Compactação** (`_comprimirBytesIterativamente`), para não estourar o PDF: arquivo com menos de **500 KB** passa intacto; imagem com até **1200 × 1200** passa intacta; senão, redimensiona para 1200 px de largura e reencoda em JPEG qualidade **70**.

**Render:** rótulo 10 pt bold centralizado, 5 pt, caixa de **350 × 400 pt** com borda `grey` e a foto com `ObjectFit.contain`; 20 pt abaixo e 15 pt à esquerda por foto — mesma história do croqui, **uma foto por linha**. Vazio: `Sem fotografias anexadas.`

> O `photo_path` e o `caminhoArquivoEncriptado` são caminhos do dispositivo. O web recebe as mídias por URL do backend, e a ordem de chegada **não** é necessariamente a que gerou a numeração — ver §8, item 3.

### 6.10 Seções 8, 9 e o encerramento padrão

- **8. COMENTÁRIO MÉDICO FORENSE** → `conclusao.discussao` ou `"XXX"`, como parágrafo com recuo.
- **9. CONCLUSÃO** → `conclusao.conclusao_texto` ou `"XXX"`, idem.
- Depois de 10 pt, o parágrafo fixo `PdfConstants.encerramentoPadrao`: *"Nada mais havendo a lavrar, encerra-se o presente Laudo Pericial que segue em formato digital, devidamente assinado, cujas páginas encontram-se numeradas no rodapé deste documento."*

### 6.11 Seção 10 — Resposta aos quesitos

`_buildDadosQuesitosOficial`, perguntas em 10 pt bold, respostas em 10 pt, 8 pt entre os blocos:

```
I) Houve morte?
R: {quesito_1_morte | XXX}
II) Qual a causa?
   → se causa_morte[] existe: para cada item, "Causa #{i+1}:" (10 pt itálico, só quando há mais de um)
     e três pw.Bullet: "Imediata: {…}", "Devido a: {…}", "Consequência: {…}"  (cada campo com fallback XXX)
   → senão: R: {quesito_2_causa | XXX}
III) Qual o instrumento ou meio que a produziu?
R: {quesito_3_instrumento | XXX}
IV) Foi produzida por meio de veneno, fogo, explosivo, asfixia ou meio insidioso cruel?
R: {quesito_4_meio | XXX}
```

Depois da seção, 40 pt e o bloco de assinatura.

### 6.12 Encerramento e certificação de integridade

`_buildEncerramento`, tudo centralizado:

1. `Nossa Senhora do Socorro/SE, {dd} de {mês} de {ano}.` (10 pt) — data de **geração** (`DateTime.now()`), não a do caso.
2. 50 pt, e uma linha divisória de **280 pt** de largura (`black`, 0,8 pt — a caixa do divider tem 16 pt).
3. Nome do responsável em maiúsculas (11 pt bold), `perito.nomeCompleto`, ou `auditoria.perito_responsavel` quando presente.
4. `Perito Médico-Legal` (9 pt, `grey700`); `CRM: {crm}` (8,5 pt, `grey700`, sem duplicar o prefixo se já vier `CRM…`); `Classe: {classe}` (idem), cada um só quando preenchido.
5. 40 pt e a caixa de certificação: fundo `grey50`, borda `grey300` 0,5 pt, raio 4 pt, padding 8 pt.
   - Linha 1: `CERTIFICAÇÃO DE INTEGRIDADE DIGITAL` (7 pt bold, `indigo900`) à esquerda e, à direita, `HASH: {12 primeiros caracteres}...` (6 pt, `grey600`) quando `hash_integridade` existe.
   - `Divider(grey300, 0.5)`.
   - Linha: `Finalizado em: {dd/MM/yyyy às HH:mm}` (7,5 pt) à esquerda — de `auditoria.data_finalizacao`, ou `Confirmado (Data Indisponível)` se a data não parseia, ou `Confirmado no Sistema` se for nula — e `Exportado em: {dd/MM/yyyy às HH:mm:ss}` (7,5 pt) à direita, com a data de geração.
   - Texto legal em 6,5 pt itálico `grey700`: *"Este documento foi gerado pelo sistema Necropsia Digital e assinado eletronicamente por {nome}. A conferência de autenticidade deve ser feita via base de dados oficial da Coordenadoria Geral de Perícias."*

---

## 7. Como fazer no web

### 7.1 Caminho A — exibir o PDF que já existe

1. Leia a URL do PDF do caso (o app grava a URL depois do upload multipart em `POST croqui/sync/laudo-pdf`, que devolve `pdf_url` e persiste na coluna local `casos.pdf_url`). **Confirme o nome do campo exposto pela API do web** — este guia descreve o lado do app; não tenho o repo do backend para verificar o contrato. O padrão de rota do sistema web lá é `/croqui/web/...` (por exemplo, `PATCH /croqui/web/casos/exames-solicitados/{id}/confirmacao-atn`, em `remote_data_source_impl.dart`), então o endpoint do laudo provavelmente está sob `/croqui/web/casos/...`. Casos sem PDF são laudos ainda não finalizados no dispositivo: trate como "indisponível", não como erro.
2. Renderize com pdf.js (`pdfjs-dist`) apontando para a URL, ou num `<iframe>`/`<embed>` se a URL já servir `Content-Type: application/pdf` e não exigir cabeçalho de autenticação. Se exigir, prefira pdf.js com `httpHeaders` (ou baixe o arquivo via a sua API e sirva um blob), porque `<iframe>` não envia o seu `Authorization`.
3. Se o backend for de outra origem, resolva CORS no servidor do arquivo — não tente contornar no cliente.
4. Para conferência fiel, o app usa `PdfPreview` (`printing`) com `maxPageWidth: 700`, `dpi: 72`, impressão e compartilhamento habilitados, sem trocar formato/orientação. Reproduza isso como toolbar do visualizador: página, zoom, download, imprimir.

### 7.2 Caminho B — re-renderizar em HTML/CSS

**Use `pt` em todo o CSS.** CSS aceita `pt` nativamente, então cada número deste guia entra no CSS sem conversão. Os tokens:

```css
:root{
  /* folha e margens (equivale a PdfConstants.marginDefault) */
  --page-w: 595.28pt; --page-h: 841.89pt;
  --m-top: 28.35pt; --m-right: 56.7pt; --m-bottom: 56.7pt; --m-left: 85.05pt;
  /* tipografia */
  --fs-doc: 12pt; --fs-section: 11pt; --fs-body: 10pt;
  --fs-item: 9.5pt; --fs-item2: 9pt; --fs-dyn: 8.5pt;
  /* cores */
  --c-mark:#f44336; --c-line:#e0e0e0; --c-muted:#616161; --c-seal:#1a237e;
  --indent-first: 24.75pt;   /* os 10 espaços da Roboto em 10pt */
}
.sheet{                       /* uma página do laudo */
  width:var(--page-w); height:var(--page-h); box-sizing:border-box;
  padding:var(--m-top) var(--m-right) var(--m-bottom) var(--m-left);
  position:relative; background:#fff;
}
.sheet__flow{ display:flex; flex-direction:column; }   /* header, conteúdo, footer */
.paragrafo{ font-size:var(--fs-body); text-align:justify; text-indent:var(--indent-first); }
.secao-titulo{ font-size:var(--fs-section); font-weight:700; margin:12pt 0 4pt; }
.achado-campo{ font-size:var(--fs-dyn); font-style:italic; }
.certificacao{ background:#fafafa; border:.5pt solid var(--c-line); border-radius:4pt; padding:8pt;
               -webkit-print-color-adjust:exact; print-color-adjust:exact; }
.croqui{ width:318pt; height:450pt; border:.5pt solid var(--c-line); position:relative; }
.croqui svg{ width:100%; height:100%; }        /* BoxFit.fill */
.marcador{ position:absolute; width:14pt; height:14pt; border-radius:50%;
           background:var(--c-mark); color:#fff; font:700 8pt/14pt Roboto; text-align:center;
           transform:translate(-7pt,-7pt); }    /* o -7 do código */
.foto{ width:350pt; height:400pt; border:.5pt solid #9e9e9e; }
.foto img{ width:100%; height:100%; object-fit:contain; }
@media print{ @page{ size:A4; margin:10mm 20mm 20mm 30mm; } }
```

Posicione o marcador com `left: calc(var(--pos-x) * 318pt); top: calc(var(--pos-y) * 450pt)` (ou `posX * 100%` dentro do `.croqui`, já que a caixa tem exatamente 318 × 450) e deixe o `translate(-7pt,-7pt)` centralizar o círculo — assim você replica a fórmula do §6.8 sem espalhar aritmética pelo componente.

**Paginação.** Chrome não implementa as caixas de margem do CSS Paged Media (`@top-center`, `@bottom-center`), então um cabeçalho `position: fixed` aparece em **todas** as páginas — inclusive na primeira, que no laudo tem o cabeçalho institucional completo. Duas saídas honestas:

- **Paginar em JS** e emitir `<div class="sheet">` de altura fixa, um por página, com header/footer próprios. É a única que reproduz fielmente a página 1 diferente, o `Página X de Y` e os blocos que não podem quebrar. Custa um paginador (meça a altura dos blocos, empacote, repita header/footer).
- **Deixar o navegador paginar** com `@page` + `break-inside: avoid` nos blocos atômicos (achado, croqui, foto, certificação). Mais simples, e a diferença fica no cabeçalho da página 1 e no "de Y".

Em qualquer das duas: mantenha `break-inside: avoid` no bloco de certificação e nas fotos/croquis, porque no app cada um desses é uma unidade indivisível.

**Fontes.** Copie `assets/fonts/Roboto-Regular.ttf` e `Roboto-Bold.ttf` para o web e declare por `@font-face` (peso 700 para a bold). Sem os mesmos arquivos, o número de linhas por parágrafo muda.

**Dados.** Você já tem tudo pelo backend (§2). Os dois artefatos que economizam redigitação:

- `docs/handoff/mapeamento-anatomico.json` — os cinco grupos, os títulos internos e a lista de ids de cada grupo.
- Como ele é gerado: `dart run tool/export_pdf_layout.dart > docs/handoff/mapeamento-anatomico.json` relê `pdf_constants.dart` e reescreve o JSON. Rode isso sempre que o app mexer no mapa anatômico, em vez de editar o JSON à mão.

### 7.3 Checklist de verificação (compare o PDF do app com o HTML lado a lado)

1. Contagem de páginas e, em cada uma, o rodapé `Página X de Y`.
2. Cabeçalho completo na página 1 e compacto nas seguintes.
3. Margem esquerda de 3 cm visivelmente maior que a direita de 2 cm.
4. Os 10 títulos de seção, na ordem, com os mesmos textos (inclusive `4. EXAME INTERNO (Cavidades)`).
5. Grupos anatômicos vazios com o texto certo — e o texto do interno é diferente do externo.
6. Numeração dos achados e sua ordem dentro de cada grupo.
7. Campos extras em itálico, com os rótulos em Title Case.
8. Posição dos círculos vermelhos sobre o mesmo ponto do croqui, e a mesma lista de vistas.
9. Numeração das fotografias e as referências cruzadas nas seções 3/4.
10. Bloco de certificação: hash, as duas datas e o texto legal.

---

## 8. Armadilhas e divergências conhecidas

Coisas que vão te custar tempo se você não souber. Nenhuma delas impede o porte; algumas são candidatas a correção no app.

1. **`schemas` chega nulo no fluxo real.** `PdfPreviewPage` não passa `schemas`, então `obterCamposFormatados` nunca acha o schema do tipo e cai no Title Case da chave. Se o web usar o schema de verdade, os rótulos vão ficar *diferentes* do PDF — melhores, mas diferentes. Decida de qual lado está a verdade.
2. **Achados em ordem decrescente.** `ORDER BY criado_em DESC` (§2.4) faz a lista impressa descer (`5.`, `4.`, `3.`…). Se quiser ordem crescente, é mudança no app, feita nos dois lados.
3. **A numeração das fotos é posicional e depende da ordem do dispositivo.** Evidências gerais primeiro, achados depois, ambos na ordem em que o app leu os dados locais. O web recebe mídias por URL, em ordem própria: as referências `[VER REGISTRO FOTOGRÁFICO n]` podem apontar para a foto errada. Para bater, replique a ordenação — ou, melhor, numere as fotos no backend e passe a exibir a referência calculada lá.
4. **O nome do perito na abertura é literal** ("Dr. Ronmel Lisboa dos Santos"); não vem do `perito` autenticado.
5. **A seção 2 (II) é literal**: `Cadáver do sexo XXX, raça XXX, estado nutricional XXX, e idade aparente de XX anos.` Os dados reais de sexo/raça/idade não são lidos.
6. **`hash_integridade.substring(0, 12)`** sem checagem de tamanho: um hash com menos de 12 caracteres derruba a geração.
7. **`face_esq` aponta para `croqui-rosto-frente.svg`**, enquanto `face_dir` aponta para `croqui-rosto-direito.svg`. Parece engano.
8. **`view` desconhecida** desenha o SVG da frente, mas rotula `VISTA: {view}` — a imagem não corresponde ao rótulo.
9. **Um exame `OUTROS` (ou qualquer tipo fora de TOXICOLOGICO/GENETICA/ANATOMO) não gera bloco na seção 5 rica**, mas ainda consome uma letra da sequência — a numeração pode pular a letra sem nada impresso.
10. **O texto de abertura e o de encerramento usam `DateTime.now()`** (data de geração). A data de finalização do caso só aparece dentro da certificação.
11. **A cidade do encerramento é fixa** ("Nossa Senhora do Socorro/SE"), independente do caso.
12. **A seção 6 só mostra vistas que têm achado**, e a ordem das vistas é a ordem do primeiro achado de cada uma — não uma ordem canônica. O mesmo vale para as fotos, sempre uma por linha (herança de `pw.Wrap` com um filho único).
13. **Marcador fora do corpo:** `posX`/`posY` são normalizados e não sofrem clamp; um valor fora de 0..1 posiciona o círculo fora da moldura do croqui (o `pdf` não recorta o `Stack`).
14. **Placeholders são o comportamento esperado**, não bug de dados: `XXX` em campo vazio e `NÃO SOLICITADO` na seção 5 legada fazem parte do laudo.
15. **Os três itálicos do laudo saem em Helvetica Oblique**, não em Roboto (§4). São eles: os campos dinâmicos dos achados (8,5 pt), o rótulo `Causa #n:` (10 pt) e o texto legal da certificação (6,5 pt). Se o web usar `font-style: italic` na Roboto, essas linhas ficam *parecidas* mas não idênticas — e, se o app depois embutir uma Roboto Itálica, o web precisa acompanhar.

---

## 9. Skills úteis para o próximo agente

Este repositório traz o conjunto de skills do Matt Pocock em `.agents/skills/` (dá para copiar a pasta para o repo do web). As que rendem neste trabalho:

- **`codebase-design`** — para desenhar o renderizador do laudo como um módulo profundo: uma interface pequena (`renderLaudo(dados) → páginas`) escondendo os tokens, o agrupamento e a paginação. Evita que cada seção vire um componente que conhece o layout.
- **`tdd`** — os invariantes do §7.3 são testáveis sem navegador: agrupamento anatômico, numeração de fotos, formatação dos campos dinâmicos e ordem das seções. Comece por eles; são exatamente os pontos onde o porte erra em silêncio.
- **`code-review`** — antes do PR, contra o ponto de partida; útil para o eixo "o web faz o que o laudo manda".
- **`domain-modeling`** / `GLOSSARY.md` — o vocabulário do laudo (`Achado`, `Croqui`, `Local anatômico`, `Vista`) tem significados precisos aqui; reusar os mesmos termos no web evita mapeamento torto.
- **`writing-for-agents`** — se você for documentar o renderizador do lado do web, é a referência de como escrever o documento que o próximo agente consome.

---

## Apêndice — artefatos do porte

| Arquivo | O que é |
|---|---|
| `docs/handoff/mapeamento-anatomico.json` | Grupos anatômicos, títulos internos e ids, gerados de `pdf_constants.dart` |
| `tool/export_pdf_layout.dart` | Regenera o JSON acima: `dart run tool/export_pdf_layout.dart > docs/handoff/mapeamento-anatomico.json` |
| `assets/images/*.svg` | Os 10 croquis (copiar como estão) |
| `assets/fonts/Roboto-{Regular,Bold}.ttf` | As fontes embutidas no PDF |
| `assets/images/logo/logo-policia-se.jpeg` | Brasão do cabeçalho |
