# Mapa de Contratos Frontend ↔ Backend (Sprint 1)

Este documento centraliza todas as alterações arquiteturais nos modelos e payloads feitas no Aplicativo Flutter durante a Sprint 1. 
**O time de Backend (FastAPI) precisará atualizar as validações do Pydantic, Schemas de Banco (SQLAlchemy/Alembic) e o Swagger para suportar as novas estruturas e manter a consistência da API.**

---

## 1. Alterações no Schema: `Achado` (Balística e Cadeia de Custódia)
Para garantir o rastreio da cadeia de custódia na sala de necrópsia, a entidade que documenta lesões (Achados) ganhou novos atributos tipados. 

No contrato de recepção do `POST /croqui/sync/push` (e no envio no `GET /croqui/sync/pull`), o DTO do Achado enviará as novas chaves:

- `tipo_ferimento` (String, nullable): Descreve a característica clínica, ex: "entrada", "saida", "raspao".
- `numero_lacre` (String, nullable): O número identificador do saco plástico de evidência para o vestígio extraído.
- `tipo_objeto` (String, nullable): O que foi recolhido do corpo, ex: "Projetil", "Fragmento", "Jaqueta".
- `comentario_adicional` (String, nullable): Observações do perito focadas na balística/item.

---

## 2. Alterações no Schema: `ExameSolicitado` (Trava Processual)
A entidade que governa os pedidos aos laboratórios complementares agora possui estado para suportar o *early-return* de finalização do caso.

Novo campo na entidade:
- `status` (String): Mapeamento fixo de estados.
  - O app envia `'aguardando'` como default no ato da solicitação.
  - Futuramente, o backend enviará `'confirmado'` ou `'rejeitado'` no payload de PULL para avisar o Flutter que a trava do laudo pode ser liberada.

---

## 3. Alterações no DTO do Laudo (`dados_laudo_json`)
Foi erradicada a tipagem livre (`dynamic` e JSON sem estrutura fixa). O aplicativo agora consolida o JSON dentro da coluna baseando-se nas seguintes árvores rígidas. O Backend pode adotar esquemas Pydantic explícitos ao invés de `Dict[str, Any]` se desejar validar a integridade.

### Estrutura Base (DadosLaudoModel)
```json
{
  "cabecalho": { ... },
  "identificacao": {
    "historico": "String",
    "vestes": "String",
    "sexo": "String"
  },
  "caracteristicas": {
    "identificacao": "String",
    "tanato_imediato": "String",
    "tanato_consecutivo": "String",
    "tanato_observacao": "String"
  },
  "conclusao": {
    "discussao": "String",
    "conclusao_texto": "String",
    "quesito_1_morte": "String",
    "quesito_2_causa": "String",
    "quesito_3_instrumento": "String",
    "quesito_4_meio": "String"
  },
  "auditoria": {
    "perito_responsavel": "String",
    "data_finalizacao": "String"
  }
}
```

### Estrutura de Causa da Morte (CausaMorteModel)
Antigamente submetida como um sub-nó variável ou *Array de dinâmicos*, agora está explícita.
No Flutter, ela foi estabilizada para ser um `List<CausaMorteModel>`.

No JSON principal do Sync (Possivelmente serializado como uma lista de objetos na raiz de Caso ou dentro de dadosLaudo), cada objeto possuirá:
```json
{
  "imediata": "String",
  "devido_a": "String",
  "consequencia": "String"
}
```

> **Atenção Backend:** Ao receber payloads em DTOs antigos da versão anterior, assumam _Defaults_ para manter retrocompatibilidade com versões de aplicativo desatualizadas durante a fase de transição (ex: Assumir `status = 'aguardando'` para exames que cheguem sem a chave de status).
