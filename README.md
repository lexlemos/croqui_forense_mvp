# Croqui Forense — MVP

Plataforma móvel especializada para a realização de esboços anatômicos e diagramações forenses (croquis) voltada para a Segurança Pública e o Instituto Médico Legal (IML). O aplicativo permite a plotagem de lesões em modelos bidimensionais mapeados, funcionando de forma totalmente isolada (Offline-First) e garantindo a integridade dos dados periciais.

## 🚀 Funcionalidades Principais

* **Mapeamento Anatômico**: Interação dinâmica sobre máscaras vetoriais (SVG) para marcação exata de coordenadas ($X, Y$) de lesões.
* **Formulários Dinâmicos**: Captura de dados clínicos e forenses customizados de acordo com o tipo de achado.
* **Arquitetura Offline-First**: Persistência local imediata para operação em locais sem conectividade.
* **Segurança Estrita**: Banco de dados criptografado nativamente e armazenamento seguro de chaves de autenticação.
* **Sincronização Periódica**: Protocolo de envio de dados textuais e evidências fotográficas em lote para o backend quando há rede confiável.

## 🏗️ Arquitetura do Projeto

O projeto adota uma abordagem **Layer-First** baseada nos princípios da *Clean Architecture*, promovendo o desacoplamento estrito entre as regras de negócio e os detalhes de infraestrutura (banco de dados, pacotes de terceiros e interface visual).

A estrutura de diretórios em `lib/` está dividida em quatro macro-camadas:

```text
lib/
├── core/         # Recursos transversais (Segurança, Redes, Temas, Constantes e Utilitários)
├── data/         # Implementações de dados, Repositórios locais (SQLite) e Fontes de Dados Remotas (Data Sources)
├── domain/       # O "Coração" do app: Contratos (Interfaces), Entidades e Serviços de Regras de Negócio (Services)
└── presentation/ # Camada de UI: Páginas (Views), Controladores Locais (Controllers) e Estado Global (Providers)

```


## 🛠️ Tecnologias e Dependências Utilizadas

* **Framework**: Flutter (Material 3)
* **Gerenciamento de Estado**: Provider (ChangeNotifier)
* **Persistência Local**: SQLite encriptado (SQLCipher)
* **Cliente HTTP**: Dio (Isolado na camada de dados via Data Sources)
* **Segurança**: Flutter Secure Storage & Helpers Criptográficos locais

## 🏁 Como Executar o Projeto

### Pré-requisitos

* Flutter SDK instalado (versão estável compatível com as dependências do `pubspec.yaml`).
* Dispositivo físico (Tablet/Smartphone) ou Emulador configurado.

### Instalação e Execução

1. Clone o repositório para a sua máquina local.
2. No terminal, execute o comando para recuperar as dependências:
```bash
flutter pub get

```


3. Execute os geradores de código internos (se houver, ex: para mocks ou serializadores):
```bash
flutter pub run build_runner build --delete-conflicting-outputs

```


4. Inicie o aplicativo em modo de desenvolvimento:
```bash
flutter run

```


## 📝 Diretrizes de Desenvolvimento e Código

* **Regra de Ouro do Estado**: Interfaces visuais (`Pages`) devem ser anêmicas. Lógicas locais pertencem a `Controllers` Dart puros. Lógicas e persistências globais pertencem a `Providers`.
* **Pureza do Domínio**: Nenhuma biblioteca de infraestrutura externa (como o pacote `dio`) deve ser importada dentro da camada de `domain/`. Toda comunicação externa é feita mediada por contratos abstratos (`Interfaces`).
* **Documentação**: Ao atualizar ou criar métodos, é obrigatório o uso de Dartdoc (`///`) explicando a regra de negócio associada e documentando possíveis exceções disparadas.
