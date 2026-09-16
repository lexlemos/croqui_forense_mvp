# 🔎 Necrópsia Digital (Croqui Forense MVP)

> **Aplicativo Mobile Offline-First para Perícia Criminal e Gestão de Laudos Cadavéricos**

## 📖 Visão Geral do App
O **Necrópsia Digital** é a ferramenta primária para Médicos Legistas e Técnicos de Necrópsia atuarem diretamente na sala de exames. Focado no uso pericial (IML), o sistema elimina o uso de papel, assegurando a **Cadeia de Custódia** e o rigor técnico desde o momento da coleta de vestígios até a assinatura eletrônica do Laudo Cadavérico Oficial.

Diferente de sistemas web tradicionais, o app foi arquitetado para suportar **ambientes sem internet** (comum em salas de necrópsia com isolamento de sinal), garantindo alta performance e zero perda de dados.

---

## 🏗 Arquitetura Offline-First & Sincronização
A espinha dorsal do projeto é a resiliência de dados em ambientes sem conectividade, implementada sob os seguintes pilares:

- **Fonte da Verdade Local (SQLite):** O estado inteiro da perícia (dados do laudo, achados, croquis, vestígios) vive no dispositivo do perito até a submissão.
- **Controle de Concorrência Otimista (OCC):** Utilização de versionamento de registros (`versao` no SQLite) para mitigar conflitos (lost updates) caso dois peritos operem simultaneamente no mesmo caso e ocorra sincronização concorrente no backend.
- **Sincronização Assíncrona (Isolates):** O processamento de Push/Pull para o servidor remoto (FastAPI) ocorre através de `Isolates` do Dart. A conversão pesada do DTO `ParsedSyncPayload` e as requisições HTTP ocorrem em threads de background (Worker Threads), **garantindo zero UI Jank** (congelamento de tela) para o perito, que pode continuar documentando lesões livremente.

---

## ⚖️ Regras de Negócio Jurídicas e Cadeia de Custódia

A confiabilidade jurídica é imperativa no sistema. A Sprint 1 introduziu as seguintes garantias sistêmicas (Hard Constraints):

1. **Gestão de Memória e Expurgo Forense (Retenção Local):**
   - O aplicativo armazena as mídias e os laudos no dispositivo SQLite. Para evitar esgotamento de memória no tablet a longo prazo, existe uma rotina automática de **Expurgo**.
   - **Regra:** Casos com status `FINALIZADO` há mais de **30 dias** são limpos do armazenamento local automaticamente.
   - **Garantia:** Laudos em status `RASCUNHO` ou `LAUDO_PENDENTE` são **blindados** contra o expurgo, evitando a perda de perícias que ainda não foram enviadas e processadas pelo Backend.

2. **Trava Processual de Exames Pendentes:**
   - Ao solicitar exames de laboratório (Toxicológico, DNA, Balística, etc.), a entidade no banco (`exames_solicitados`) recebe o status `'aguardando'`.
   - **A Trava:** O *State Management* impede ativamente a mudança de status do laudo para `FINALIZADO` caso existam exames complementares aguardando retorno. Isso obedece ao trâmite legal, impedindo a geração de laudos incompletos ou a quebra de protocolos processuais.

3. **Cadeia de Custódia (Balística):**
   - Os achados mapeiam fortemente a topologia dos projéteis no corpo. Atributos rigorosos como `numeroLacre`, `tipoFerimento` (entrada/saída), e `tipoObjeto` garantem que o vestígio físico esteja rastreado desde a sala de necrópsia até a submissão no cofre de evidências.

---

## 🛠 Tech Stack

- **Framework Gráfico:** Flutter (Dart).
- **Banco de Dados Local:** SQLite (via `sqflite` com versionamento de schemas incrementais).
- **Concorrência:** Dart Isolates (`compute`) para parseamento JSON e networking.
- **Arquitetura Base:** Clean Architecture adaptada, injeção de dependências modular, Modelos Estritamente Tipados (`DadosLaudoModel`, `CausaMorteModel`) erradicando o uso de tipagem `dynamic`.
- **Backend Integração:** FastAPI (Motor de Sincronização / OCC).
- **CI/CD:** GitHub Actions (Dart Analyzer / Flutter Test).

---

## 🚀 Como Rodar o Projeto

### Pré-requisitos
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (versão atual recomendada pelo projeto).
- Dispositivo Android/iOS ou Emulador devidamente configurado.

### Passos de Instalação

1. Clone este repositório:
   ```bash
   git clone https://github.com/lexlemos/croqui_forense_mvp.git
   cd croqui_forense_mvp
   ```
2. Instale as dependências:
   ```bash
   flutter pub get
   ```
3. Verifique as ferramentas estáticas e de qualidade de código (Recomendado antes do Commit):
   ```bash
   flutter analyze
   flutter test
   ```
4. Execute o app:
   ```bash
   flutter run
   ```
