# GLOSSARY.md

Glossário de termos ubíquos e conceitos do domínio para o projeto **Necrópsia Digital / Croqui Forense MVP**.

---

## 1. Termos de Negócio e Medicina Legal (IML)

### Laudo Pericial (Caso)
Documento oficial médico-legal expedido pelo perito legista contendo identificação, histórico policial, tanatologia, descrição topográfica de lesões corporais, exames complementares laboratoriais e resposta aos quesitos formulados pela autoridade requisitante.

### Croqui Forense
Mapeamento gráfico vetorial 2D de lesões corporais sobre diagramas corporais anatômicos padronizados (vistas anterior, posterior, lateral direita, lateral esquerda e perineal).

### Achado Pericial
Registro individual de uma lesão corporal ou evidência física demarcada no croqui, contendo coordenadas cartesianas normalizadas (X, Y), classificação tipológica da lesão, dimensões métricas, fotografias e vínculo com cadeia de custódia balística.

### Cadeia Balística (PAF)
Associação pericial de projéteis de arma de fogo a orifícios de entrada e saída no corpo, com numeração e rastreabilidade de lacre físico.

### ATN (Auxiliar Técnico de Necrópsia)
Profissional técnico que auxilia o médico-legista nos procedimentos de sala de necrópsia, coleta de materiais biológicos e custódia de frascos laboratoriais.

---

## 2. Termos de Engenharia e Arquitetura Offline-First

### Strict Offline-First
Paradigma operacional em que todas as mutações de dados, capturas de imagem e gerações de laudo ocorrem primariamente no armazenamento criptografado local (SQLite/SQLCipher), garantindo operação autônoma sem dependência de rede celular ou internet.

### Draft AutoSave
Mecanismo de persistência preventiva com debounce (1000ms) que consolida as entradas digitadas pelo perito diretamente no banco local SQLite, prevenindo perda de dados por queda de energia ou fechamento inesperado do aplicativo.

### Optimistic Concurrency Control (OCC)
Controle de versão sequencial monotônico (`versao = versao + 1`) associado a cada laudo para detectar divergências entre alterações locais e o banco central do backend durante ciclos de sincronização.

### Active Case Mutex (Lock de Edição Local)
Mecanismo de proteção de concorrência que impede o motor de sincronização (`SyncService`) de sobrescrever cegamente no SQLite um laudo pericial que esteja em edição ativa no `CroquiController`, eliminando condições de corrida entre o AutoSave local e o Pull da central.

### Atomic Media Upload
Pipeline de transmissão particionado onde fotografias e arquivos de evidência são enviados individualmente via requisições multipart sequenciais com hash SHA-256 de validação, evitando pacotes volumosos (Erro 413) e permitindo retomada do envio a partir da última foto confirmada.

### Keep-Alive Wakelock
Mecanismo transitório de controle de energia que impede a suspensão da CPU e corte de soquetes de rede pelo Android (Doze Mode / LMK) enquanto houver um ciclo de sincronização de dados e mídias em andamento.
