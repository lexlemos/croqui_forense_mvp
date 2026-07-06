# Camada de Domínio (`lib/domain/`)

Esta é a camada mais interna e central da aplicação no padrão *Clean Architecture*. Ela atua como o "coração" do sistema, encapsulando as regras de negócio puras da plataforma **Croqui Forense** e definindo os contratos (interfaces) que regem as demais camadas.

---

## 🛡️ Diretrizes e Restrições de Dependência

A camada de Domínio é totalmente agnóstica de detalhes técnicos e de infraestrutura. Por isso, as seguintes restrições de dependências são estritamente obrigatórias:

* **Aqui NÃO entra Interface de Usuário (UI/Apresentação)**: Não é permitida a importação de nenhum pacote de interface do Flutter (`material.dart`, `widgets.dart`) ou gerenciadores de estado (`provider`, `bloc`, etc.).
* **Aqui NÃO entram Bibliotecas de Infraestrutura**: É expressamente proibida a importação de bibliotecas de rede (como o pacote `dio`), bancos de dados (`sqflite`), ou utilitários específicos de persistência.
* **Comunicação por Contratos**: Toda interação com APIs externas, armazenamento de arquivos ou persistência local deve ser intermediada por contratos abstratos (interfaces), cuja implementação concreta reside na camada de `data/` ou `core/`.

---

## 📂 Estrutura e Sumário dos Componentes

A pasta está dividida entre contratos de repositórios e serviços de domínio:

### 1. Repositórios (`lib/domain/repositories/`)

Define as assinaturas abstratas para acesso a fontes de dados externas sem revelar detalhes sobre HTTP ou redes.

* **`remote_data_source.dart`**: Contrato abstrato para a comunicação remota com os servidores centrais. Define as operações de login do perito, alteração de PIN de acesso, obtenção de tipos de achados dinâmicos e sincronização de laudos.

### 2. Serviços (`lib/domain/services/`)

Classes especializadas que coordenam a execução das regras de negócio do aplicativo forense.

* **`achado_service.dart`**: Orquestra e gerencia as operações sobre as lesões físicas anotadas (achados) em um determinado caso.
* **`auth_service.dart`**: Gerencia a autenticação e sessão do perito no tablet, englobando login online e validação criptográfica offline de PINs locais.
* **`case_service.dart`**: Coordena o ciclo de vida dos casos periciais (Laudos), incluindo criação de rascunhos, salvamento físico local, finalização do caso e assinatura do hash de integridade digital.
* **`device_info_service.dart`**: Recupera dados identificadores únicos do dispositivo (tablet) para rastreabilidade de auditoria.
* **`domain_sync_service.dart`**: Gerencia a sincronização local de templates gráficos e regras de formulários dinâmicos de lesão.
* **`sync_service.dart`**: Orquestra a rotina de sincronização de dados textuais de laudos e o upload em lote de evidências fotográficas para a central, preservando a cadeia de custódia.
* **`user_service.dart`**: Provê funcionalidades administrativas locais para listagem e alteração de status de peritos.
* **`pdf_service.dart` / `pdf_constants.dart` / `pdf_helpers.dart`**: Motor de exportação de dados, responsável por gerar o arquivo físico final do Laudo Cadavérico Oficial em PDF no formato padronizado do IML.
