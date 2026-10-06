# Guia Prático do Perito Médico-Legista — Croqui Forense Digital

Bem-vindo ao **Croqui Forense Digital**. Este manual foi elaborado para orientar você, perito médico-legista, na utilização prática de todas as funcionalidades do aplicativo durante os exames necroscópicos na sala de necropsia, no consultório pericial e em operações de campo.

---

## Sumário
1. [Acesso ao Aplicativo (Com e Sem Internet)](#1-acesso-ao-aplicativo-com-e-sem-internet)
2. [Criando e Inicializando um Novo Laudo](#2-criando-e-inicializando-um-novo-laudo)
3. [Mapeamento Corporal e Registro de Lesões (Croqui)](#3-mapeamento-corporal-e-registro-de-lesões-croqui)
4. [Exames Complementares e Rastreio Balístico (Cadeia de Custódia)](#4-exames-complementares-e-rastreio-balístico-cadeia-de-custódia)
5. [Finalização e Assinatura do Laudo Pericial](#5-finalização-e-assinatura-do-laudo-pericial)
6. [Sincronização com a Central (A Nuvem de Dados)](#6-sincronização-com-a-central-a-nuvem-de-dados)
7. [Guia de Solução de Problemas (Troubleshooting)](#7-guia-de-solução-de-problemas-troubleshooting)

---

## 1. Acesso ao Aplicativo (Com e Sem Internet)

O aplicativo foi projetado para funcionar mesmo quando o necrotério ou a sala de necropsia não tiver sinal de Wi-Fi ou rede móvel.

![Tela de Login](docs/img/tela-login.png)

### Como Fazer o Primeiro Acesso (Online)
1. Conecte o tablet à rede Wi-Fi da unidade pericial.
2. Digite seu **Login (CPF/Matrícula)** e sua **Senha**.
3. Toque em **Entrar**. O aplicativo autenticará suas credenciais e preparará a base de dados segura no seu dispositivo.

### Como Fazer o Login Sem Internet (Modo Offline)
Quando estiver na sala de necropsia sem conexão:
1. Digite seu **Login** e **Senha** habituais.
2. Toque em **Entrar**.

> [!IMPORTANT]
> **Atenção — Regra de Segurança do Acesso Offline:**
> Por exigência de segurança e proteção de dados sigilosos, o acesso sem internet é permitido **exclusivamente para o último perito que utilizou o tablet online**. Caso outro médico tente entrar no aparelho sem rede, o aplicativo exigirá conexão com a central para validar a nova identidade.

---

## 2. Criando e Inicializando um Novo Laudo

Você pode criar um novo caso em poucos segundos utilizando o número de procedimento policial (PIC) para puxar automaticamente os dados cadastrais da delegacia.

![Tela Inicial com Lista de Casos](docs/img/tela-home-casos.png)

### Passo a Passo para Iniciar um Caso com o PIC:
1. Na tela inicial, toque no botão **"+" (Novo Caso)**.
2. No campo **Nº do PIC**, digite o número do protocolo da ocorrência.
3. Toque no **ícone da lupa (🔍)** ao lado do campo:
   - **Se houver internet e o PIC existir na base central:** Os campos *Nº do Boletim de Ocorrência (BO)*, *Delegacia Solicitante*, *Autoridade Requisitante*, *Nome da Vítima*, *Data/Hora do Fato* e *Sexo Estimado* serão preenchidos automaticamente.
   - **Se o aparelho estiver sem internet ou o PIC for novo:** Uma notificação informará que a busca não pôde ser concluída. Você poderá digitar todos os dados manualmente sem qualquer impedimento.
4. Selecione os **Auxiliares Técnicos de Necrópsia (A.T.N.s)** que estão participando do exame.
5. Toque em **Iniciar Exame**. O croqui anatômico será aberto imediatamente.

> [!NOTE]
> **Salvamento Automático em Tempo Real:**
> Você não precisa procurar um botão de "Salvar" a cada palavra digitada. O aplicativo grava suas alterações no banco de dados do tablet 1 segundo após você parar de digitar.

---

## 3. Mapeamento Corporal e Registro de Lesões (Croqui)

O croqui digital substitui o papel, permitindo marcar graficamente com precisão milimétrica a localização de ferimentos, trajetos de projéteis e lesões contusas.

![Croqui Anatômico Interativo](docs/img/tela-croqui-anatomico.png)

### Como Registrar uma Lesão:
1. Na visualização do corpo (Frente, Costas, Laterais, Tronco, Face ou Região Perineal), localize a região anatômica desejada.
2. **Toque exatamente sobre o ponto anatômico** onde a lesão se encontra.
3. Um formulário de detalhamento será exibido na tela:
   - **Tipo de Lesão:** Selecione entre *Pérfuro-contusa (PAF)*, *Corto-contusa*, *Pérfuro-incisa*, *Escoriação*, *Equimose*, *Queimadura*, entre outras.
   - **Dimensões e Profundidade:** Digite as medidas em milímetros ou centímetros (ex: `15 x 8 mm`).
   - **Fotografia Pericial:** Toque no botão de câmera para fotografar a lesão com a régua milimetrada. O aplicativo otimiza e comprime a foto automaticamente.
   - **Descrição Detalhada:** Digite observações específicas (bordas, zona de tatuagem, halo de enxugo, infiltração hemorrágica).
4. Toque em **Salvar Lesão**. Um marcador numerado aparecerá no desenho anatômico exatamente onde você tocou.

### Como Editar ou Mover uma Lesão:
- Toque sobre o marcador numerado no desenho anatômico para reabrir os detalhes, atualizar medidas ou substituir fotografias.

---

## 4. Exames Complementares e Rastreio Balístico (Cadeia de Custódia)

A aba **Exames** e a aba **Balística** conectam o seu trabalho de médico-legista ao fluxo do Auxiliar Técnico de Necrópsia (A.T.N.) e aos laboratórios do IML, garantindo a conformidade da Lei da Cadeia de Custódia (Lei 13.964/19).

![Aba de Exames Complementares](docs/img/tela-exames-tab.png)

### 4.1. Solicitando Exames Laboratoriais
Na aba superior **Exames**, marque as caixas de seleção desejadas:
- **Exame Toxicológico:** Sangue, humor vítreo, urina, conteúdo gástrico ou fragmentos de vísceras.
- **Exame Genético/Biológico:** Swabs de cavidade oral, anal, vaginal ou fragmentos de pele/unhas para confronto de DNA.
- **Exame Anátomo-patológico:** Frascos com formol contendo fragmentos de órgãos para estudo microscópico.

Para cada exame, informe o **Nº do Lacre de Segurança** correspondente ao envelope ou frasco físico.

### 4.2. Entendendo os Crachás de Status do A.T.N.
Ao lado de cada exame e de cada projétil/vestígio balístico cadastrado, você verá um **crachá colorido** indicando a situação da amostra com o técnico de necropsia:

| Crachá | Cor | O que significa? |
| :--- | :---: | :--- |
| **Pendente** | 🟡 Amarelo | Você solicitou o item, e ele aguarda o A.T.N. recolher e conferir fisicamente o frasco/lacre. |
| **Visualizado** | 🔵 Azul | O A.T.N. visualizou a requisição no sistema, mas ainda está processando a coleta. |
| **Confirmado** | 🟢 Verde | O A.T.N. conferiu o lacre, atestou que a amostra está íntegra e aceitou a custódia formal. |
| **Recusado** | 🔴 Vermelho | O A.T.N. recusou o recebimento da amostra ou do projétil por inconformidade física. |

### 4.3. O que fazer quando um exame ou projétil for "RECUSADO"?
Se o crachá estiver vermelho (**Recusado**), uma caixa de aviso vermelha aparecerá logo abaixo com o motivo formal apontado pelo técnico (ex: *"Lacre do frasco 02 violado"* ou *"Projétil extraviado antes do acondicionamento"*).

![Alerta de Recusa de Custódia](docs/img/alerta-recusa-atn.png)

**Ação do Perito:**
1. Converse com o A.T.N. responsável na sala de necropsia.
2. Se necessário, colete uma nova amostra ou providencie a substituição do lacre rompido.
3. Atualize o número do novo lacre no formulário para reiniciar a conferência.

---

## 5. Finalização e Assinatura do Laudo Pericial

Quando o exame físico do corpo for concluído, você possui duas opções flexíveis de encerramento:

![Modal de Conclusão do Laudo](docs/img/modal-conclusao.png)

1. Na aba **Conclusão**, preencha a discussão médico-legal e responda aos quesitos oficiais obrigatórios (1º Morte, 2º Causa, 3º Instrumento/Meio, 4º Meio cruel).
2. Toque no botão verde **Finalizar Exame**:
   - **Opção A — "Deixar Pendente" (Recomendado para plantões intensos):** Encerra a etapa física do corpo e libera a mesa de necropsia, mantendo o laudo em aberto para você redigir a discussão pericial detalhada mais tarde no consultório.
   - **Opção B — "Concluir Laudo Agora":** Compila todo o laudo, gera o documento **PDF oficial com os desenhos anatômicos coloridos, fotos e respostas aos quesitos**, e bloqueia o laudo contra edições acidentais.

> [!WARNING]
> **Trava de Segurança Processual:**
> O aplicativo não permite **Concluir Laudo Definitivamente** se houver exames laboratoriais com o status de realização pendente no laboratório central. Para esses casos, escolha sempre **"Deixar Pendente"**.

---

## 6. Sincronização com a Central (A Nuvem de Dados)

No canto superior direito da tela inicial, você encontra o botão **Sincronizar** acompanhado do ícone da nuvem.

![Botão de Sincronização](docs/img/botao-sync.png)

### Como Funciona a Sincronização:
1. Ao tocar em **Sincronizar**, o ícone começará a girar (**Sincronizando...**).
2. O aplicativo executa automaticamente a seguinte sequência segura:
   - **Passo 1:** Verifica se a rede e o servidor central estão operacionais.
   - **Passo 2:** Baixa os laudos atualizados da central para o seu tablet (*Pull*).
   - **Passo 3:** Envia seus laudos, lesões e textos salvos no tablet (*Push Textual*).
   - **Passo 4:** Envia todas as fotos de lesões e arquivos binários de alta resolução.
   - **Passo 5:** Envia o PDF oficial compilado e assinado.
3. Ao término, uma barra verde na parte inferior confirmará: *"Laudos sincronizados com sucesso!"*.

---

## 7. Guia de Solução de Problemas (Troubleshooting)

Utilize a tabela abaixo caso encontre alguma dificuldade durante a utilização do sistema:

### 1. Dificuldade no Acesso
- **Sintoma:** Ao tentar entrar sem internet, o aplicativo exibe a mensagem *"Dispositivo offline. Conecte-se para o primeiro acesso."*.
- **Causa:** O tablet foi reiniciado após limpeza de dados ou o último perito a logar no aparelho foi outro colega.
- **Ação:** Conecte o tablet momentaneamente ao Wi-Fi ou roteador 4G do celular, faça o login com sua senha uma única vez e desconecte. A partir daí, o acesso sem internet funcionará normalmente.

### 2. Busca pelo PIC não preenche os dados
- **Sintoma:** Ao digitar o número do PIC e clicar na lupa, aparece o aviso *"Rede instável ou PIC não localizado"*.
- **Causa:** O tablet está sem sinal de internet ou o número do PIC ainda não foi cadastrado no sistema da Polícia Civil/IML.
- **Ação:** Prossiga com o preenchimento manual dos campos de BO e nome da vítima. O laudo continuará válido e será integrado à base central na próxima sincronização.

### 3. Alerta de Conflito de Versão na Sincronização
- **Sintoma:** Ao tocar no botão *Sincronizar*, a mensagem informa *"Sincronização parcial: 1 em conflito"*.
- **Causa:** O mesmo laudo foi aberto e modificado na central web por outro usuário enquanto você estava editando no tablet offline com uma versão desatualizada.
- **Ação:** O aplicativo preserva suas anotações no tablet e impede a sobreposição de dados. Abra o laudo sinalizado, revise as alterações e faça uma nova sincronização com a rede ativa.

### 4. O laudo não fecha no botão "Concluir Laudo Agora"
- **Sintoma:** Ao clicar em *Concluir Laudo Agora*, o aplicativo emite um alerta vermelho: *"O laudo não pode ser finalizado com exames complementares pendentes"*.
- **Causa:** Existem requisições de exames (Toxicológico, DNA ou Anátomo) marcadas como aguardando laudo laboratorial.
- **Ação:** Escolha a opção **"Deixar Pendente"**. O exame necroscópico será gravado com segurança e você poderá finalizar o documento assim que os resultados laboratoriais forem emitidos.

---

*Manual atualizado para a versão 1.0 — Instituto de Medicina Legal / Polícia Científica.*
