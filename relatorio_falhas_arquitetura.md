# Relatório de Falhas de Arquitetura

## lib/data/repositories/caso_repository.dart
- **Arquivo/Linha**: lib/data/repositories/caso_repository.dart, linha 647 (método _decodeJson)
- **Gravidade**: Média
- **Descrição Técnica da Falha**: Try/catch silencioso (catch (_) { return {}; }).
- **Impacto no Negócio**: Caso o JSON da evidência esteja corrompido, a aplicação engole o erro e retorna vazio. Isso pode causar perda silenciosa de dados (campos extras do JSON) comprometendo evidências de lesões.
- **Sugestão de Correção para a próxima Sprint**: Lançar uma exceção específica (DataCorruptionException) ou no mínimo registrar um log de warning com Sentry para permitir a rastreabilidade do laudo.

## lib/data/models/caso_model.dart
- **Arquivo/Linha**: lib/data/models/caso_model.dart, linha 24 e 54
- **Gravidade**: Alta
- **Descrição Técnica da Falha**: Vazamento de tipagem. Uso de Map<String, dynamic> dadosLaudo e List<dynamic>? causaMorte no core do domínio ao invés de DTOs tipados.
- **Impacto no Negócio**: Permite mutabilidade acidental e inserção de dados inconsistentes na árvore do laudo pericial (Cadeia de Custódia), dificultando serialização segura e podendo causar crash no parsing do motor de sincronização.
- **Sugestão de Correção para a próxima Sprint**: Criar classes/DTOs estritamente tipados como DadosLaudoModel e CausaMorteModel.
