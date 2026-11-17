# Processo de trabalho

> **Versão 5 — proposta de enxugamento (n=1).** Esta revisão reduz o atrito do processo para um fork de uma pessoa, sem perder o rigor que protege de verdade. O que mudou em relação à v4:
> - A **issue é a Spec**: não há mais etapa separada de Spec nem gate de aprovação manual; "pronto pra dev" é um label (`status:ready`) na issue.
> - **O gate que reprova merge é a CI verde** (lint + test + build). Review por pessoa com "identidade diferente" deixou de ser exigido; review assistido por IA é opcional.
> - **Gate de documentação virou condicional** (só quando muda comportamento observável, contrato público ou UX) e **o teto de PR virou guia, não bloqueio**; só a label de tipo é obrigatória.

Este documento é o dono do procedimento: como uma mudança passa de um relato até o main remoto, quais são as regras de autorização, de worktree, de ambiente e de documentação, e onde ficam os valores de configuração. As regras invariantes para qualquer agente estão em [`AGENTS.md`](../AGENTS.md), e não são repetidas aqui. As etapas são executadas pelas skills, instaladas por máquina. Os valores que as skills leem estão na seção [Configuração](#configuração).

Cada regra tem um único dono. As demais seções e arquivos citam a chave, não repetem o texto.

## Hierarquia

O trabalho é fatiado por capacidade do usuário (vertical), não por camada técnica.

| Nível | O que é | Onde vive | Regra |
|---|---|---|---|
| **Épico** | Uma capacidade que o usuário consegue usar do início ao fim | Issue `epic.yml` | Tem plano, dono, cenários Given/When/Then, grafo de tickets por papel e casos E2E de aceite. É demonstrável pelo consumidor real. Épico só de backend exige justificativa e consumidor declarado. |
| **Ticket** | Uma entrega descrita na própria issue | Issue `feature.yml` (Trabalho) | O corpo da issue é a Spec (ver [A issue é a Spec](#a-issue-é-a-spec)). Declara "Parte de #", "Bloqueado por #", "Paralelizável com #" e as áreas ou arquivos que toca. |
| **PR** | Uma unidade revisável | Pull request | Uma por ticket, por padrão. Fatias opcionais usam `Refs #n`, e a última usa `Closes #n`. |
| **Tarefa** | Passo da issue | Checklist da issue | Ordenada, com critério de conclusão e teste. Tarefa não é commit. |

Não há número fixo de tickets por épico, nem estimativa em unidades de tempo. Dependências entre tickets usam sub-issues e dependências nativas do GitHub quando disponíveis. Tickets só são paralelizáveis quando não tocam os mesmos arquivos.

## Fluxo

O fluxo resumido é **issue → branch → código + teste → CI verde → (review IA, opcional) → merge.**

| Etapa | Skill | Entrada | Saída |
|---|---|---|---|
| 0. Relato | `relato-para-issue` | Queixa, dor, história ou pedido em linguagem livre | Issue publicada, com capacidade, contexto, critérios de aceite e tipo (bug, ticket ou épico) |
| 1. Implementação | `implementar-spec` | Issue com `status:ready` | Commits atômicos na branch da issue, com testes, documentação quando aplicável e validação visual quando houver interface |
| 2. Pull request | `abrir-pr` | Branch com os comandos de verificação verdes local | PR com o template, vinculada à issue, com a CI rodando |
| 3. Review (opcional) | `review-pr` ou `/code-review` | PR | Review assistido por IA, com findings classificados e marcador |
| 3.2. Remediação | `tratar-findings` | Findings | Correções com TDD e resposta a cada finding |
| 4. Merge | `merge-gate` | PR com CI verde | Squash merge, branch e worktree limpas, e fechamento do épico quando for o último ticket |

### Estado real antes de agir

Antes de cada etapa que age sobre a issue ou a PR (implementar, abrir PR, review, merge e tratar findings), a skill confere no GitHub o estado da issue e das PRs ligadas à branch. O registro local em `.agent/` não basta.

1. Estado da issue: `gh issue view <n> --json state`.
2. PRs da branch: `gh pr list --head <branch> --state all --json number,state`.
3. PRs e branches ligadas à issue: GraphQL `closedByPullRequestsReferences(includeClosedPrs: true)`, `gh issue develop --list <n>`, e `git ls-remote --heads origin` filtrado por `*/<n>-*`.

A skill para e reporta, sem agir, se a issue estiver fechada, se a PR da branch estiver mesclada ou fechada, ou se outra branch ou PR estiver ligada à issue. Em `implementar-spec`, a parada também acontece se já houver branch ou PR da issue no remoto.

### Etapa 0: relato para issue

A skill `relato-para-issue` traduz o relato em: pessoa e situação, dor, contorno atual, resultado esperado, capacidade, cenários derivados e tipo. Hipóteses viram pergunta. Temas misturados são separados em issues distintas. Antes de publicar, a busca por duplicatas abertas e fechadas é obrigatória. A issue usa o formulário YAML de `.github/ISSUE_TEMPLATE/`. Uma issue só entra em trabalho quando está **pronta pra dev** (ver abaixo).

### A issue é a Spec

Não há etapa de Spec separada nem gate de aprovação manual. O formulário `feature.yml` (Trabalho) já pede o que a Spec pedia: contexto, capacidade do usuário, comportamento esperado, critérios de aceite verificáveis e as áreas ou arquivos que a mudança toca. **O corpo da issue é a Spec.** A checklist de Tarefas, quando ajuda, vai no próprio corpo.

Uma issue está **pronta pra dev** quando recebe o label `status:ready` (chave `label_ready`). O label é aplicado pelo mantenedor quando a issue tem o que a implementação precisa:

- contexto e critérios de aceite claros, sem premissa não verificada pendente;
- quando há interface, o contrato visual ou a referência (ver [Contrato visual](#contrato-visual));
- quando há fronteira entre front e back, o contrato da interface (ver [Contrato](#contrato));
- o risco classificado como **comum** ou **sensível** (sensível: autenticação, dados pessoais, financeiro, migração destrutiva ou produção), e ADR proposta quando houver decisão transversal.

Falta de acesso ou premissa não verificada é pendência bloqueante: some antes do `status:ready`, não durante a implementação. Decisão transversal que surja depois vira ADR em `docs/adr/`.

### Etapa 1: implementação

- Execução das Tarefas na ordem da issue, sem pausas entre elas, exceto por bloqueio real (decisão que a issue não cobre).
- Uma issue, uma branch e uma worktree (ver [Worktrees e branches](#worktrees-e-branches)).
- TDD para cada comportamento testável, no nível que o testa melhor (ver [Níveis de teste](#níveis-de-teste)). RED: teste que falha pelo motivo esperado. GREEN: implementação mínima. REFACTOR: com testes verdes. Falha de configuração, import, fixture ou ambiente não conta como RED válido.
- Antes de criar um mecanismo de teste ou verificação, o agente procura o que já existe. O mecanismo criado é versionado, declarado na Configuração, documentado e genérico. Scripts ou configurações por PR ou issue são proibidos.
- Commits pequenos e atômicos, cada um deixando o código consistente. Tarefas não são commits.
- Decisões que surgirem durante a implementação são classificadas: **produto** (emenda da issue, com aceite do mantenedor), **técnica local** (registrada na PR) ou **transversal** (ADR em `docs/adr/`).
- Ao concluir uma Tarefa, o registro de progresso em `.agent/progresso.md` (não versionado) recebe comportamentos, testes, resultados, commits e desvios.
- Mudança de interface segue o [ciclo de validação visual](#validação-visual) dentro do próprio ticket.
- Documentação só quando a mudança for observável (ver [Gate de documentação](#gate-de-documentação)).
- Sem squash durante o desenvolvimento.

Antes de abrir a PR, o agente roda os comandos de verificação da Configuração (`lint`, `test`, `build`) localmente. São os mesmos comandos que a CI roda — a CI é a fonte do gate, a execução local é só para não abrir PR vermelha.

### Etapa 2: pull request

A PR usa o template em `.github/pull_request_template.md`. Ela referencia a issue, lista as Tarefas marcadas apenas quando satisfeitas e registra a verificação com resultados reais. Testes não executados não são marcados como aprovados.

Regras da PR:

- Vinculada a uma issue, com `Closes #<n>` na última fatia, ou `Refs #<n>` nas fatias intermediárias.
- Exatamente um label `type:*` (ver [Labels](#labels)). Os demais labels são opcionais.
- Seção "Documentação" preenchida **quando a mudança for observável** (ver [Gate de documentação](#gate-de-documentação)); refactor interno registra "sem impacto observável".
- Seção "Roteiro de aceite manual" preenchida quando houver o que testar à mão.
- Não há criação de PR sem a instrução explícita do mantenedor na invocação.

Ao abrir a PR, a CI (`.github/workflows/ci.yml`) roda lint, test e build. Ela é o gate que reprova o merge (ver [Qualidade: a CI é o gate](#qualidade-a-ci-é-o-gate)).

### Etapa 3: review (opcional)

O review é **opcional** e assistido por IA. Com n=1 não há revisor de "identidade diferente" honesto; o papel de linha de base de qualidade é da CI, não de um revisor humano independente. O review de IA (por exemplo `/code-review`, Claude no PR ou `review-pr` em contexto novo) ajuda a achar o que a CI não pega, e não substitui a CI.

Quando rodado, o revisor não altera código. Ele avalia correção, aderência à issue, critérios de aceite, invariantes, regressões, validação de entrada, autorização por perfil, isolamento entre clientes, tratamento de erros, segurança (incluindo os Requisitos de Segurança aplicáveis), concorrência, consistência entre frontend e backend, consistência de renderização quando aplicável, performance de consultas, testes ausentes ou frágeis, documentação e alterações fora de escopo.

Os findings são classificados como:

- **BLOCKING:** CRITICAL, HIGH ou MEDIUM. Corrigidos antes do merge.
- **NON-BLOCKING:** LOW ou NIT. Corrigidos por decisão do mantenedor. Só viram issue de follow-up o que o mantenedor decidir não corrigir.
- **ACCEPTED / DOCUMENTED RISKS:** limitações já registradas na issue ou na PR. Não são findings da implementação.

Cada finding traz severidade, arquivo e linha, comportamento observado, comportamento esperado, justificativa, cenário que reproduz e sugestão de correção. Findings especulativos não são registrados. O review é publicado com o marcador descrito em [Review como comentário](#review-como-comentário).

### Etapa 3.2: remediação

Todo finding aplicável é tratado, bloqueante ou não. Para cada bug confirmado, vale o TDD da etapa 1. Não se resolve finding sem evidência de correção. Ao final, cada finding recebe resposta na PR com: causa, correção, teste que reproduziu, teste que comprova a correção e commit correspondente.

### Etapa 4: merge

O merge gate verifica: **CI verde no HEAD atual da PR**, conflitos com o main remoto, commits inesperados, segredos ou arquivos de ambiente no diff, documentação conferida quando a mudança for observável, e limitações conhecidas. Se houver review com findings bloqueantes abertos, eles são tratados antes.

Resultados possíveis:

- **READY FOR SQUASH MERGE:** CI verde e sem blockers concretos. Pode fazer o squash.
- **NOT READY FOR MERGE:** CI vermelha, ou blockers concretos identificados.

A invocação da etapa 4 é a autorização do squash, se o gate estiver verde. Depois do merge, a branch remota e a worktree são limpas (ver [Worktrees e branches](#worktrees-e-branches)).

**Fechamento do épico.** Quando a PR é o último ticket filho aberto do épico (todos os outros itens da checklist estão fechados), o merge gate faz mais uma verificação, antes de dar o resultado final:

1. os casos E2E do épico estão ativos, na branch integrada, e verdes;
2. o épico não tem item pendente na checklist;
3. o flag de feature (se houver) está desligado em produção ou será removido nesta PR, conforme o plano.

Se as três condições valem, o merge gate informa "fecha o épico" no resultado. O fechamento do épico é ação separada, e exige instrução explícita na invocação. Sem a suíte verde, o épico não fecha, mesmo com todos os tickets mesclados.

## Qualidade: a CI é o gate

A linha de base de qualidade é automática, não humana. A CI em `.github/workflows/ci.yml` roda os comandos de verificação da Configuração — `lint`, `test` e `build` — a cada push da branch e na PR. **A CI verde é o gate que libera o merge; a CI vermelha o reprova.** Nenhum review humano independente é exigido para esse papel.

- Os mesmos comandos rodam local antes de abrir a PR, para não abrir PR vermelha.
- Falhas de gate já existentes num checkout limpo do main remoto (pré-existentes à mudança) são anotadas na própria issue da correção, com a causa. Elas explicam por que um gate já falha, mas não aprovam regressões novas: a PR precisa demonstrar que não introduz erros nos arquivos e comportamentos que altera.
- Bypass de proteção de branch ou de checks obrigatórios segue [Autorização](#autorização): não acontece por conta própria.

## Contrato e testes

### Épico e suíte de aceite

- O plano do épico tem cenários Given/When/Then, o grafo de tickets por papel (contrato, persistência, regra, interface, integração e aceite) e, quando houver fronteira entre front e back, o esboço do contrato.
- Cada cenário do épico que cruza a costura com o sistema (ver [Quando um ticket precisa de E2E](#quando-um-ticket-precisa-de-e2e)) vira um caso E2E, atribuído ao ticket que o entrega.
- O épico fecha com todos os seus casos ativos e verdes na `main` integrada (ver [Etapa 4](#etapa-4-merge)). Não há ticket de aceite separado nem ativação no fechamento.

### Níveis de teste

- **Unitário:** regra pura, validação, decisão, parsing, cálculo. Roda a cada commit e na CI.
- **Integração:** componente com arquivos, banco ou processo, em diretório temporário ou com fake. Roda na CI.
- **E2E:** fluxo ponta a ponta no ambiente real, só para a costura com o sistema. Roda antes da PR e no merge, não a cada commit.

Não são E2E: aparência e layout (captura visual), textos e traduções (lint), e regra de dados já coberta pelo unitário ou pela integração.

### Quando um ticket precisa de E2E

Um ticket precisa de E2E quando muda algo que só se verifica no sistema real: permissão, seletor do sistema, montagem ou processo nativo, FileProvider, ou arquivo que outro app enxerga.

- O ticket ativa de 1 a 3 casos, cada um um fluxo que o usuário faz do início ao fim. Não se cobre cada detalhe de UI.
- O caso nasce ativo no ticket que o entrega. O harness pode listar casos de tickets futuros como NOT TESTED, só para exibição; isso não cria caso pendente no ticket atual.
- O caso não repete o que o unitário ou a integração já provam.
- Se o ambiente de teste não estiver disponível, o ticket não é dado como concluído, e a pendência é dita na issue, antes da implementação.

### Contrato

Quando há fronteira entre front e back, existe uma fonte única da interface, com verificação automática de divergência. O mecanismo (tipos gerados, validação em runtime ou contract test) fica a critério da stack, e é declarado na Configuração.

### Feature flag

Feature flag é obrigatório quando código mesclado expõe ao usuário um comportamento incompleto. O flag fica desligado em produção, ligado em DEV, e é removido no ticket que fecha o épico.

## Ambientes

A matriz de ambientes fica na [Configuração](#configuração), chave `ambientes`. Ela define, para cada ambiente, se o agente pode ler, testar, escrever dados e fazer deploy sem pedir nova autorização na invocação. É a única pré-autorização permanente que o processo admite, e só vale para as células marcadas como `sim`.

Os ambientes são dois: DEV e PROD.

- **DEV** é o desenvolvimento, com dados sintéticos. A máquina local de desenvolvimento segue a linha `dev` da matriz. Pode ser pré-autorizado pela matriz, conforme configurado.
- **PROD** nunca é pré-autorizado para escrita, teste ou deploy. Leitura só ocorre por acesso somente leitura configurado e com pedido explícito.
- Testes e comandos de escrita conferem o alvo antes de executar (invariante 5 de [`AGENTS.md`](../AGENTS.md)).

### Identidade de teste

- Usuários sintéticos por perfil e fixtures existem só em DEV. A sessão de teste em DEV é obtida sem interação para o agente.
- Há um teste que prova a indisponibilidade desses usuários e atalhos em produção. Ele é obrigatório.
- O agente nunca usa credencial real de pessoa.

### Ensaio de migração

O ensaio de migrações acontece em DEV, com dados sintéticos. Ele é isolado de produção e nunca é escrito pelo E2E automático. Antes de migração, a reversão é planejada por tipo:

- **aditiva** (coluna que aceita nulo, tabela nova, índice): conferir que o backup automático do provedor existe e é recente. Não exige dump. A reversão é remover o que foi adicionado.
- **transformadora** (troca de tipo, backfill, mudança de formato): expandir e contrair. A migração cria o novo ao lado do antigo, o backfill preenche o novo, o código passa a usar o novo, e o antigo só é removido em outra entrega. Antes, dump somente das tabelas afetadas.
- **destrutiva** (remoção de coluna, tabela ou dados): ensaio em DEV, que mede a duração e valida a volta, e dump das tabelas afetadas antes da execução. Exige instrução explícita na invocação.

Dump completo do banco não é exigido em nenhum dos tipos.

O baseline de schema fica numa PR própria, e a CI verifica paridade entre o schema e o baseline.

### Serviços locais e mecanismos de teste

- Compose de desenvolvimento e de teste não usa `restart: unless-stopped` nem `always`. O serviço sobe quando o trabalho precisa dele (containers sob demanda). Esses restart policies fazem os containers religarem a cada boot.
- Mecanismo de teste que cria recurso (container, volume, rede, banco ou pasta temporária) o remove ao terminar, inclusive quando a execução é interrompida. Ele trata os sinais (INT, TERM, HUP), e não só o `finally`.
- O nome do recurso segue `<projeto>-<finalidade>-<pid>-<8 hex>`, em que `<pid>` é o PID do processo que coordena a execução. A [higiene da máquina](#skills) reconhece esse formato para separar órfão de ativo.

## Segredos

- Um `.env` por projeto, na raiz do checkout principal, compartilhado pelas worktrees por link ou caminho, com prefixos por ambiente.
- `.env.example` versionado contém somente referências `op://` do 1Password, preenchidas por `op inject`.
- **Exceção (D4, issue #4):** `.env.example` também pode conter chaves não secretas do projeto, com valor vazio (ex.: `ADB_DEVICE=`). Nenhum valor real entra no modelo.
- O comando `env:check` (chave `env_check` da Configuração, `scripts/env-check.sh`) confere a presença das chaves sem exibir valores.
- Nenhum arquivo de segredo é versionado, nem criptografado.
- Segredos não aparecem em skills, exemplos, issues, PRs, logs ou saídas de script.

## Requisitos de Segurança

A issue lista os Requisitos de Segurança acionados pela superfície da mudança. Mudança sem superfície registra "não aplicável" numa linha. Itens aplicáveis quando houver a superfície:

- autorização por perfil e isolamento entre clientes;
- trilha de auditoria para ações sensíveis;
- cabeçalhos de segurança em respostas HTTP;
- guarda do modo de teste, que impede ativar identidade de teste em produção;
- plano de reversão de schema, conforme [Ensaio de migração](#ensaio-de-migração).

## Interface

### Contrato visual

Imagem ou referência enviada pelo usuário pode ser a fonte de verdade. A issue traz o inventário de elementos, classificados como adotado, adaptado (com motivo), descartado ou divergente entre imagens, e a fidelidade (próxima ou inspiração). O repositório é a única fonte de verdade da interface. Claude Design é opcional, tem uma direção só, e o canvas dele não faz parte da definição de pronto: o que vale é o código no repositório validado pelo ciclo visual.

### Validação visual

Ciclo dentro do ticket de interface, sem ticket separado:

1. captura automática das telas alteradas, em desktop e mobile;
2. autoavaliação por modelo de visão, comparando com o inventário da issue;
3. correção dos desvios;
4. E2E do fluxo alterado, quando o ticket tocar a costura (ver [Quando um ticket precisa de E2E](#quando-um-ticket-precisa-de-e2e)). O mesmo caso serve de evidência; não se repete.

A evidência (capturas e resultado da autoavaliação) vai para a PR. Quando não houver ferramenta de captura configurada, a captura é feita manualmente e anexada.

### Roteiro de aceite manual

A PR e a mensagem final trazem o roteiro: o que foi entregue (funções, telas e rotas), onde testar, conta de teste (pela referência de [Identidade de teste](#identidade-de-teste)), cenários com o resultado esperado e o que já foi verificado automaticamente.

## Prontidão de sites

Use esta checklist em projetos que oferecem um site. Ela ajuda a avaliar o que é pertinente ao contexto; não exige que todo projeto implemente todos os itens e não garante, sozinha, prontidão para produção ou conformidade legal. Decisões jurídicas dependem do tratamento de dados, do serviço e das obrigações aplicáveis.

Ao adaptar a checklist ao projeto, registre o estado de cada item e a evidência ou justificativa. Para itens condicionais ou não aplicáveis, explique a decisão. Não trate `robots.txt` como controle de segurança, nem suponha que um sitemap garanta indexação ou que mecanismos de busca exibam a meta description fornecida.

| # | Categoria | Elemento | Aplicabilidade e orientação | Estado no projeto | Evidência ou justificativa |
|---:|---|---|---|---|---|
| 1 | Experiência e acessibilidade | Página 404 personalizada | Recomendada quando o site tem rotas próprias; explique o erro e ofereça um caminho de retorno. | A preencher | A preencher |
| 2 | Conversão e marketing | CTA no topo da página | Condicional: use quando houver uma ação principal clara, como agendar ou pedir orçamento. | A preencher | A preencher |
| 3 | SEO e descoberta | Meta title por página | Recomendado para páginas públicas; descreva o conteúdo de cada página. | A preencher | A preencher |
| 4 | SEO e descoberta | Meta description por página | Recomendada para resumir páginas públicas; buscadores podem exibir outro texto. | A preencher | A preencher |
| 5 | SEO e descoberta | Imagem Open Graph | Recomendada para páginas que serão compartilhadas; forneça uma prévia coerente com a marca e o conteúdo. | A preencher | A preencher |
| 6 | Identidade e infraestrutura | Conjunto de favicons | Recomendado para identificar a marca em abas, favoritos e atalhos. | A preencher | A preencher |
| 7 | SEO e descoberta | `robots.txt` | Condicional: oriente rastreadores que respeitam o arquivo; ele não protege conteúdo nem substitui autorização. | A preencher | A preencher |
| 8 | SEO e descoberta | `sitemap.xml` | Recomendado quando há páginas públicas relevantes a descobrir; não garante indexação. | A preencher | A preencher |
| 9 | SEO e descoberta | Texto alternativo em imagens | Recomendado para imagens informativas, com descrição útil; imagens decorativas devem usar `alt=""`. Considere acessibilidade além de `alt`. | A preencher | A preencher |
| 10 | Experiência e acessibilidade | Versão mobile ajustada | Recomendada para todas as páginas; conteúdo e controles devem funcionar em telas estreitas. | A preencher | A preencher |
| 11 | Conversão e marketing | CTA fixo no celular | Condicional: só use se facilitar a ação principal sem cobrir conteúdo ou atrapalhar navegação. | A preencher | A preencher |
| 12 | Experiência e acessibilidade | Telas de carregamento | Use indicadores quando uma operação assíncrona ou demorada deixar o resultado temporariamente indisponível. | A preencher | A preencher |
| 13 | Experiência e acessibilidade | Erros de formulário | Condicional: formulários devem explicar o erro e orientar a correção junto ao campo afetado. | A preencher | A preencher |
| 14 | Conversão e marketing | Página de confirmação | Condicional: após uma ação concluída, confirme o resultado e explique os próximos passos. | A preencher | A preencher |
| 15 | Jurídico e transparência | Política de privacidade | Avalie quando houver tratamento de dados pessoais ou outra obrigação aplicável; descreva as práticas reais. | A preencher | A preencher |
| 16 | Jurídico e transparência | Termos de uso | Condicionais ao serviço e à relação com o usuário; descreva regras que realmente se aplicam. | A preencher | A preencher |
| 17 | Jurídico e transparência | Banner de cookies | Condicional: avalie as tecnologias usadas e as obrigações aplicáveis; banner de consentimento não é necessário em todos os sites. | A preencher | A preencher |
| 18 | Conversão e marketing | Analytics instalado | Condicional: adote quando houver uma pergunta de negócio e uma base apropriada para coleta e uso dos dados. | A preencher | A preencher |
| 19 | Jurídico e transparência | Endereço de contato real | Recomendado: disponibilize canais verdadeiros e acessíveis. Endereço físico depende do negócio e não é necessário em todo serviço digital. | A preencher | A preencher |
| 20 | Identidade e infraestrutura | Domínio próprio com HTTPS | HTTPS protege a conexão e é recomendado para todo site. Domínio próprio reforça a identidade da organização. | A preencher | A preencher |

### Verificações além da checklist

Os 20 elementos não cobrem todo o trabalho de produção. Avalie também, conforme a aplicação:

- **Segurança:** autenticação e autorização quando existirem contas, proteção de dados e segredos, dependências e configurações seguras.
- **Desempenho:** carregamento e resposta das páginas nos dispositivos e conexões esperados.
- **Testes automatizados:** fluxos críticos, validações e comportamento em falhas.
- **Monitoramento:** erros da aplicação, indisponibilidade e falhas do servidor, com alertas e tratamento apropriados.
- **Acessibilidade:** navegação por teclado, foco, estrutura semântica, contraste, ampliação de texto e comunicação de atualizações, além dos textos alternativos.

Registre os critérios e evidências pertinentes ao produto na issue e na documentação do projeto. Use a matriz de risco e os [Requisitos de Segurança](#requisitos-de-segurança) quando aplicáveis.

## Gate de documentação

O gate de documentação é **condicional**: só vale quando a mudança altera algo que alguém de fora enxerga. Refactor interno, renomeação privada ou melhoria sem efeito observável não exigem doc.

**Exige atualização de documentação quando a mudança altera:**

- comportamento observável do produto (o que ele faz, para quem serve ou o seu status);
- contrato público (API, formato de arquivo, CLI, permissões, interface entre front e back);
- UX (telas, fluxos, textos visíveis ao usuário).

Nesses casos, a documentação existente é atualizada, ou a seção que falta é criada, junto da mudança, antes da PR. A seção "Documentação" da PR lista o que mudou; o merge gate confere que a atualização existe. Quando a mudança altera o que o projeto faz, para quem serve ou o seu status, a linha de descrição do README e a descrição do repositório no GitHub são atualizadas na mesma PR.

Quando não há impacto observável, a PR registra "sem impacto observável" na seção "Documentação", e o gate está satisfeito.

### Estrutura de documentação

| Arquivo ou pasta | Conteúdo |
|---|---|
| `docs/PROCESSO.md` | Este documento |
| `docs/adr/` | Decisões transversais, uma por arquivo |
| `docs/dominio.md` | Glossário do domínio |
| `docs/arquitetura.md` | Visão da arquitetura |
| `docs/ambientes.md` | Ambientes (DEV e PROD) e identidade de teste |
| `docs/funcionalidades/` | Uma página por funcionalidade entregue |
| `docs/design-system/` | Tokens e componentes, quando houver interface |
| `docs/referencias/<épico-ou-issue>/` | Referências enviadas pelo usuário, com manifesto |
| `README.md` | Índice de entrada do repositório |

A Spec é a issue, não um arquivo em `docs/`. Logs ficam em `.agent/`, que não é versionado. README de pasta só existe como índice.

### Idioma

Texto da organização em pt-BR. Identificadores (código, pastas, tokens, chaves de label e de configuração) em inglês. Um idioma por repositório, e outro só por ADR. O glossário de domínio fica em `docs/dominio.md`.

## Autorização

- **A autorização vale para a invocação.** Quem invoca uma skill com a ação explícita já autorizou aquela ação.
- **Única exceção permanente:** a matriz de ambientes da Configuração. Uma célula marcada como `sim` dispensa nova autorização para a ação correspondente, naquele ambiente. Nenhuma outra configuração versionada concede autorização. Produção nunca é pré-autorizada.
- **Ações que exigem instrução explícita na invocação:** publicar issue, publicar comentário, abrir PR, aplicar o label `status:ready`, criar ou alterar label, squash merge, fechar épico, apagar branch remota ou local, remover worktree, remover arquivos, qualquer ação em produção e qualquer deploy fora da matriz.
- **Bypass de proteção de branch ou de checks obrigatórios** só acontece com autorização explícita do mantenedor na própria invocação, e somente se a plataforma oferecer esse mecanismo ao usuário. O agente não contorna proteção por conta própria.
- **O bypass administrativo nunca cobre** checks obrigatórios (a CI), conflitos, achados pendentes ou mudanças destrutivas.
- Uma etapa autorizada é executada até o fim, sem pausas por cautela, exceto por bloqueio real (decisão que a issue não cobre).

## Review como comentário

Quando houver review (opcional), o `review-pr` publica o review com um marcador HTML na primeira linha e uma linha de status:

```text
<!-- review-pr mode=<review|re-review> sha=<sha> -->
REVIEW STATUS: <estado>
```

`merge-gate` e `tratar-findings` leem três fontes: reviews formais da PR, comentários da PR e comentários inline. Um review é considerado válido quando tem o marcador (de qualquer identidade) ou quando o mantenedor declara o comentário como review. Review não é o gate de merge — a CI verde é (ver [Qualidade: a CI é o gate](#qualidade-a-ci-é-o-gate)).

## Labels

Os nomes, cores e descrições dos labels estão em `.github/labels.yml`, que é a fonte única desse conjunto. Este documento define as regras de uso:

- **Obrigatória:** cada PR tem exatamente um `type:*`. Os demais labels são opcionais.
- `status:ready` registra que a issue está pronta pra dev. Não aprova a PR.
- `size:large` (quando existir) é apenas um aviso de tamanho, não um gate (ver [Tamanho de PR](#tamanho-de-pr)).
- `duplicate`, `invalid` e `wontfix` fazem parte do conjunto final e não são removidos pela normalização.
- Labels não são criados nem alterados no GitHub sem instrução explícita na invocação.

**Normalização.** Um label em uso que não está no manifesto é remarcado para o correspondente (seção `remarcar` do manifesto) e só depois é removido. Os que não têm correspondente vão para decisão do mantenedor, com lista. Nenhum label em uso é removido antes da remarcação.

**Branches.** `delete_branch_on_merge` fica ligado no repositório. Branches com PR mesclada são removidas. Branches sem PR são listadas para decisão.

## Tamanho de PR

- **Guia, não bloqueio.** O teto `teto_pr_linhas` da Configuração (padrão 2.000 linhas alteradas, adições mais remoções, excluindo arquivos gerados) é um **aviso**: acima dele, a PR traz na descrição por que não foi fatiada. Nenhuma PR é reprovada só por ultrapassar o teto.
- Fatiar continua sendo boa prática quando ajuda a revisar, mas é opcional.

## Acúmulo

Artefatos antigos (relatórios, skills copiadas e código sem uso) são retirados do repositório. A cópia vai para a raiz de aposentados (`raiz_aposentados` da Configuração), fora do repositório, e o original só é removido com lista e confirmação. Código legado só sai com prova de não uso.

## Worktrees e branches

Worktree é temporária. Ela é criada para uma mudança e removida ao fim do trabalho, se estiver limpa.

- **Uma issue, uma branch, uma worktree.** Antes de criar, procure a branch e a worktree que já existem para a issue (`git worktree list` e busca pelo número da issue). Se existir, reutilize-a, depois de confirmar o estado. Não crie segunda branch para a mesma issue sem decisão do mantenedor.
- Nome da branch: prefixo de `prefixos_branch` seguido do número da issue, por exemplo `docs/2-processo-v2`.
- Ao criar, a branch não rastreia a `main`: use `--no-track` a partir de `origin/main`. Publique só a própria branch, com `git push -u origin <branch>`. Nunca faça push para a `main`.
- O diretório da worktree depende da ferramenta que a criou. Claude usa `.claude/worktrees/<nome>`. Codex usa `~/.codex/worktrees/<nome>`, fixo pela ferramenta. OpenCode usa o diretório do checkout, conforme a configuração local. Não crie worktree fora do diretório que a ferramenta usa.
- Antes de criar uma worktree, atualize as referências: `git fetch origin --prune`.
- Submódulos não vêm com a worktree. Depois de criá-la, rode `git submodule update --init --recursive` dentro dela. Sem isso, o CMake do Android falha ao gerar o build, porque `third_party/proot` e `third_party/libandroid-shmem` ficam vazios.
- Não substitua um submódulo por link simbólico apontando para o checkout principal. O git registra o caminho como `T` (typechange), e um commit feito nesse estado troca o submódulo por um link.
- Antes de editar, confirme `git status` limpo, a branch atual e a relação com o main remoto.
- Antes de remover, confirme que não há trabalho não publicado. Não remova worktree de outra sessão, nem limpe branch, worktree ou artefato de outra sessão automaticamente. Liste o alvo, confirme que não está associado a trabalho ativo e peça confirmação.
- Use `git worktree list` para inspecionar, independentemente da localização.
- Branch remota de feature é apagada após o squash merge. Branch local é apagada após o merge, se não houver trabalho não publicado.
- Nenhuma worktree ou branch é removida sem confirmação de que não há trabalho ativo. A skill `higiene-maquina` lista o estado e pede confirmação. A remoção acontece pela lista aprovada, com `inventario.sh --remover`, que revalida cada item antes de agir.

## Identidade GitHub

O processo usa a sessão `gh` ativa (`gh auth status`). A conta pode variar por colaborador e não é fixada neste documento. Commits usam a identidade dessa sessão, com o e-mail de noreply do GitHub.

## Skills

As etapas do processo são executadas por skills. Há duas classes:

- **Skill do processo:** uma pasta de `skills/` do template (e a antiga `higiene-git`). Não é copiada para os projetos: é instalada por máquina com `instalar-processo`, por links.
- **Skill própria do projeto:** qualquer outra skill que o projeto tenha, por exemplo um wrapper de deploy ou um roteiro de smoke. Fica no projeto, em `.agents/skills/<nome>/`, que Codex e OpenCode leem e o Hermes lê depois de `hermes skills trust`. Para o Claude, `.claude/skills/<nome>` é um link relativo para `../../.agents/skills/<nome>`.

A adoção nunca remove uma skill própria do projeto. Uma skill própria com o mesmo nome de uma skill do processo é conflito, e vai para decisão do mantenedor.

Se as skills não estiverem disponíveis no ambiente de execução (por exemplo, numa sessão na nuvem), leia o procedimento em `skills/<nome>/SKILL.md` no repositório do template, `onluis-dev/template`, antes de executar a etapa. Não invente o procedimento a partir da memória.

## Configuração

Bloco lido pelas skills. Cada projeto que adote o processo preenche os valores, com `adotar-processo`. Enquanto houver placeholder, a skill que depende do valor deve pedir a informação em vez de assumi-la.

```yaml
processo_versao: 5
branch_base: main
prefixos_branch: [feat/, fix/, docs/]
label_tipo: escolhido por PR, entre os type:*   # único label obrigatório
label_ready: status:ready                       # issue pronta pra dev (ex-aprovação de Spec)
teto_pr_linhas: 2000                            # guia (aviso na descrição), não bloqueia o merge
raiz_aposentados: ~/.local/share/onluis-dev/aposentados
env_check: sh scripts/env-check.sh  # confere chaves de .env contra .env.example, sem exibir valores
ci_workflow: .github/workflows/ci.yml  # fonte do gate: lint + test + build na PR; CI verde libera o merge
comandos:
  lint: ./gradlew lint
  test: ./gradlew testOfflineDebugUnitTest testOnlineDebugUnitTest
  integracao: 
  typecheck: 
  build: ./gradlew assembleOfflineDebug assembleOnlineDebug
  smoke: 
  e2e: sh scripts/e2e/run.sh  # harness adb; alvo: ADB_DEVICE do .env, senão aparelho único, senão emulador; cada ticket ativa os seus casos
  visual: manual
ambiente_local: sh scripts/install-phone.sh  # build online, instalação e abertura no celular conectado por adb; teste de atualização em docs/update-testing.md
ambientes:
  # Matriz: sim = pré-autorizado na invocação; nao = exige instrução explícita.
  # Preenchida como nao em tudo: a pré-autorização é decisão do mantenedor.
  dev:      {ler: nao, testar: nao, escrever_dados: nao, deploy: nao}
  prod:     {ler: nao, testar: nao, escrever_dados: nao, deploy: nao}
stack:
  gerenciador_pacotes: Gradle (wrapper 8.14)
  lockfile: nenhum
  linguagens: Kotlin 2.2.21, JVM 17
  frameworks: Android (compileSdk 36), Jetpack Compose
  servicos_locais: nenhum identificado
  regras_adicionais: nenhuma além das do AGENTS.md
```

Os valores de `comandos`, `ambientes` e `stack` são específicos de cada projeto. O template não os preenche.
