# sandbox - Epic Breakdown

**Author:** Luis
**Date:** 2025-11-29T19:52:52-03:00
**Project Level:** Level 2
**Target Scale:** 43 Functional Requirements

---

## Overview

This document provides the complete epic and story breakdown for sandbox, decomposing the requirements from the [PRD](./prd.md) into implementable stories.

**Living Document Notice:** This is the initial version. It will be updated after UX Design and Architecture workflows add interaction and technical details to stories.

**Epic Summary:**
- **Epic 1**: Foundation & Setup - Estabelecer base do projeto Next.js e conexão com banco de dados
- **Epic 2**: Visualização de Conversas - Permitir que desenvolvedores visualizem e naveguem conversas
- **Epic 3**: Visualização de Gerações e Eventos - Explorar gerações e eventos dentro de conversas
- **Epic 4**: Análise de Decisões de Reexecução - Analisar decisões do agente sobre continuar/finalizar tarefas
- **Epic 5**: Formatação e Navegação de Dados - Formatar dados e facilitar navegação entre entidades relacionadas
- **Epic 6**: Tratamento de Erros e Validação - Garantir experiência robusta mesmo com erros

**Total:** 6 épicos, ~25 histórias

---

## Functional Requirements Inventory

### User Account & Access
- FR1: Usuários podem acessar o dashboard sem autenticação (ferramenta local)
- FR2: Sistema detecta e conecta automaticamente ao banco SQLite em `.cursor/database/cursor_hooks.db`
- FR3: Sistema valida existência do banco de dados e exibe mensagem apropriada se não encontrado

### Conversation Management
- FR4: Sistema pode listar todas as conversas do banco de dados
- FR5: Sistema pode filtrar conversas por status (active, completed, aborted, error)
- FR6: Sistema pode ordenar conversas por data de início (ascendente/descendente)
- FR7: Sistema pode buscar conversas por ID ou email do usuário
- FR8: Sistema pode exibir detalhes completos de uma conversa selecionada
- FR9: Sistema pode exibir todas as gerações relacionadas a uma conversa
- FR10: Sistema pode exibir workspace(s) associados a uma conversa

### Generation Viewing
- FR11: Sistema pode exibir informações de uma geração (ID, modelo, status, timestamps)
- FR12: Sistema pode listar todos os eventos relacionados a uma geração
- FR13: Sistema pode calcular e exibir duração de uma geração (quando end_time disponível)

### Event Visualization
- FR14: Sistema pode exibir eventos do tipo `beforeSubmitPrompt` (prompts do usuário)
- FR15: Sistema pode exibir eventos do tipo `afterAgentResponse` (respostas do agente)
- FR16: Sistema pode exibir eventos do tipo `afterAgentThought` (pensamentos do agente)
- FR17: Sistema pode exibir eventos do tipo `afterShellExecution` (comandos shell executados)
- FR18: Sistema pode exibir eventos do tipo `afterMCPExecution` (execuções MCP)
- FR19: Sistema pode exibir eventos do tipo `afterFileEdit` (edições de arquivos)
- FR20: Sistema pode exibir eventos do tipo `stop` (finalização do loop)
- FR21: Sistema pode exibir timeline cronológica de eventos de uma geração
- FR22: Sistema pode exibir dados específicos de cada tipo de evento (comando shell, arquivo editado, etc.)

### Reexecution Decisions Analysis
- FR23: Sistema pode listar todas as decisões de reexecução do banco de dados
- FR24: Sistema pode filtrar decisões por finish (true/false)
- FR25: Sistema pode exibir informações completas de uma decisão (reason, followup_message, timestamp)
- FR26: Sistema pode exibir prompt relacionado a uma decisão
- FR27: Sistema pode exibir resumo da resposta do agente relacionada a uma decisão
- FR28: Sistema pode navegar da decisão para a conversa/geração relacionada
- FR29: Sistema pode calcular estatísticas de decisões (total concluídas vs continuadas)

### Data Navigation
- FR30: Sistema pode navegar de uma conversa para suas gerações
- FR31: Sistema pode navegar de uma geração para seus eventos
- FR32: Sistema pode navegar de um evento para sua geração/conversa pai
- FR33: Sistema pode navegar de uma decisão para sua conversa/geração relacionada
- FR34: Sistema pode exibir breadcrumbs para indicar localização atual na hierarquia

### Data Display
- FR35: Sistema pode exibir dados JSON formatados de forma legível
- FR36: Sistema pode exibir timestamps em formato legível (data/hora local)
- FR37: Sistema pode exibir durações em formato legível (milissegundos → segundos/minutos)
- FR38: Sistema pode truncar textos longos com opção de expandir
- FR39: Sistema pode exibir código (comandos shell, JSON) com syntax highlighting

### Error Handling
- FR40: Sistema pode detectar quando o banco de dados não existe e exibir mensagem apropriada
- FR41: Sistema pode detectar erros de conexão com o banco e exibir mensagem de erro
- FR42: Sistema pode exibir mensagens de erro amigáveis para consultas SQL falhadas
- FR43: Sistema pode lidar com dados corrompidos ou ausentes graciosamente

---

## FR Coverage Map

| Epic | FRs Covered | Description |
|------|-------------|-------------|
| Epic 1: Foundation & Setup | FR1, FR2, FR3 | Infraestrutura base e conexão com banco |
| Epic 2: Visualização de Conversas | FR4, FR5, FR6, FR7, FR8, FR9, FR10, FR30 | Listagem, filtros, busca e detalhes de conversas |
| Epic 3: Visualização de Gerações e Eventos | FR11, FR12, FR13, FR14, FR15, FR16, FR17, FR18, FR19, FR20, FR21, FR22, FR31, FR32 | Visualização completa de gerações e eventos |
| Epic 4: Análise de Decisões de Reexecução | FR23, FR24, FR25, FR26, FR27, FR28, FR29, FR33 | Listagem e análise de decisões do agente |
| Epic 5: Formatação e Navegação de Dados | FR34, FR35, FR36, FR37, FR38, FR39 | Formatação de dados e navegação entre entidades |
| Epic 6: Tratamento de Erros e Validação | FR40, FR41, FR42, FR43 | Tratamento robusto de erros |

---

## Epic 1: Foundation & Setup

**Goal:** Estabelecer a base do projeto Next.js, configurar conexão com banco de dados SQLite, e criar estrutura básica para desenvolvimento.

**FRs Covered:** FR1, FR2, FR3

### Story 1.1: Inicializar Projeto Next.js

As a **desenvolvedor**,
I want **um projeto Next.js configurado com TypeScript e Tailwind CSS**,
So that **posso começar a desenvolver o dashboard**.

**Acceptance Criteria:**

**Given** que estou no diretório do projeto
**When** executo o comando de inicialização do Next.js
**Then** o projeto é criado com:
- Next.js 15 com App Router
- TypeScript configurado
- Tailwind CSS configurado
- Estrutura de diretórios `app/` criada
- Arquivos de configuração (`tsconfig.json`, `tailwind.config.ts`, `next.config.js`) criados

**And** o projeto pode ser executado com `npm run dev` sem erros

**Prerequisites:** Nenhum

**Technical Notes:**
- Usar comando: `npx create-next-app@latest dashboard --typescript --tailwind --app --no-src-dir --import-alias "@/*"`
- Verificar arquitetura.md seção "Project Initialization" para detalhes

### Story 1.2: Configurar Conexão com Banco SQLite

As a **desenvolvedor**,
I want **conexão configurada com o banco SQLite**,
So that **o dashboard possa ler dados dos hooks do Cursor**.

**Acceptance Criteria:**

**Given** que o projeto Next.js está inicializado
**When** instalo e configuro better-sqlite3
**Then** o arquivo `lib/db.ts` é criado com:
- Singleton pattern para conexão SQLite
- Path configurado para `.cursor/database/cursor_hooks.db`
- Função para obter conexão reutilizável
- Read-only access (apenas SELECT)

**And** a conexão é testada e funciona corretamente

**Prerequisites:** Story 1.1

**Technical Notes:**
- Instalar: `npm install better-sqlite3` e `npm install --save-dev @types/better-sqlite3`
- Seguir padrão de singleton da arquitetura (lib/db.ts)
- Verificar se banco existe antes de conectar

### Story 1.3: Validação de Banco de Dados e Tratamento de Erros Iniciais

As a **desenvolvedor**,
I want **validação de existência do banco de dados**,
So that **o sistema exiba mensagens apropriadas se o banco não for encontrado**.

**Acceptance Criteria:**

**Given** que a conexão com banco está configurada
**When** o sistema tenta conectar ao banco
**Then** o sistema valida se o arquivo existe em `.cursor/database/cursor_hooks.db`

**And** se o banco não existir, exibe mensagem clara: "Banco de dados não encontrado. Verifique se o arquivo existe em .cursor/database/cursor_hooks.db"

**And** se houver erro de conexão, exibe mensagem de erro amigável

**Prerequisites:** Story 1.2

**Technical Notes:**
- Implementar validação em `lib/db.ts`
- Criar componente de erro para exibir quando banco não encontrado
- Seguir padrão de error handling da arquitetura

### Story 1.4: Implementar Health Check Endpoint

As a **desenvolvedor**,
I want **endpoint de health check**,
So that **posso validar saúde do sistema e conectividade com banco de dados**.

**Acceptance Criteria:**

**Given** que a conexão com banco está configurada
**When** faço GET para `/api/health`
**Then** a API retorna:
- Status do sistema (healthy/unhealthy)
- Status do banco de dados (UP/DOWN)
- Tempo de resposta do banco (milissegundos)
- Timestamp da verificação

**And** retorna status 200 quando sistema saudável
**And** retorna status 503 quando banco inacessível

**Prerequisites:** Story 1.2

**Technical Notes:**
- Criar `app/api/health/route.ts`
- Validar conectividade com SQLite via query simples (ex: `SELECT 1`)
- Medir tempo de resposta do banco
- Seguir formato de resposta da arquitetura (ver ADR-005)

### Story 1.5: Implementar Observabilidade (Server-Timing e Trace IDs)

As a **desenvolvedor**,
I want **métricas de performance e trace IDs em API routes**,
So that **posso validar SLOs de performance e correlacionar requisições**.

**Acceptance Criteria:**

**Given** que as API routes estão implementadas
**When** faço requisição para qualquer API route
**Then** a resposta inclui:
- Header `Server-Timing` com métricas: `db;dur=X,total;dur=Y`
- Header `X-Trace-Id` com ID único para correlacionar requisições

**And** métricas de `db` medem tempo de execução de queries SQL
**And** métricas de `total` medem tempo total de processamento
**And** trace IDs são únicos por requisição (UUID v4)

**Prerequisites:** Story 2.1 (primeira API route)

**Technical Notes:**
- Criar `lib/utils/observability.ts` com função `withObservability()`
- Middleware para medir tempo de queries e adicionar headers
- Gerar trace IDs únicos (UUID v4)
- Aplicar em todas as API routes

### Story 1.6: Implementar Logging Estruturado

As a **desenvolvedor**,
I want **logs estruturados em formato JSON**,
So that **posso analisar logs facilmente e validar observabilidade**.

**Acceptance Criteria:**

**Given** que o sistema está em execução
**When** ocorre evento que requer logging (erro, info, warn)
**Then** o log é escrito em formato JSON estruturado com:
- Campo `level` (info, warn, error)
- Campo `traceId` (quando disponível)
- Campo `message` (descrição do evento)
- Campo `timestamp` (ISO 8601)
- Campo `error` (quando aplicável)

**And** logs de erro incluem trace ID para correlacionar com requisições
**And** logs são escritos no console em formato JSON

**Prerequisites:** Story 1.5

**Technical Notes:**
- Criar função helper `logStructured()` em `lib/utils/observability.ts`
- Substituir `console.error()` por `logStructured()` em API routes
- Incluir trace ID em logs quando disponível
- Seguir formato JSON estruturado da arquitetura

### Story 1.7: Implementar Testes de Segurança

As a **desenvolvedor**,
I want **testes automatizados de segurança**,
So that **posso validar que SQL injection é prevenido e erros não expõem estrutura do banco**.

**Acceptance Criteria:**

**Given** que as API routes estão implementadas
**When** executo testes de segurança
**Then** os testes validam:
- SQL injection em query params é bloqueado (prepared statements funcionam)
- Erros SQL não expõem estrutura do banco (schema, nomes de tabelas)
- Inputs são sanitizados corretamente

**And** testes são executados em CI pipeline
**And** testes seguem padrão OWASP Top 10

**Prerequisites:** Story 2.1 (primeira API route)

**Technical Notes:**
- Criar testes em `tests/security/` ou `tests/nfr/security.spec.ts`
- Testar SQL injection em parâmetros de busca (`?search='; DROP TABLE`)
- Validar que erros retornam mensagens genéricas (não expõem schema)
- Usar Playwright para testes E2E de segurança

---

## Epic 2: Visualização de Conversas

**Goal:** Permitir que desenvolvedores visualizem, filtrem, busquem e explorem conversas do banco de dados de forma intuitiva.

**FRs Covered:** FR4, FR5, FR6, FR7, FR8, FR9, FR10, FR30

### Story 2.1: API Route para Listar Conversas

As a **desenvolvedor**,
I want **API route que retorna lista de conversas**,
So that **posso buscar conversas do banco de dados**.

**Acceptance Criteria:**

**Given** que a conexão com banco está configurada
**When** faço GET para `/api/conversations`
**Then** a API retorna:
- Lista paginada de conversas (default: 50 por página)
- Cada conversa com: conversation_id, user_email, status, start_time, end_time
- Metadados de paginação: page, limit, total, totalPages

**And** suporta query params: `?page=1&limit=50`

**Prerequisites:** Story 1.2

**Technical Notes:**
- Criar `app/api/conversations/route.ts`
- Criar `lib/queries/conversations.ts` com função `getConversations()`
- Seguir padrão de API Route da arquitetura
- Usar prepared statements para prevenir SQL injection

### Story 2.2: Filtros de Conversas por Status

As a **desenvolvedor**,
I want **filtrar conversas por status**,
So that **posso focar em conversas ativas, concluídas, abortadas ou com erro**.

**Acceptance Criteria:**

**Given** que a API de listagem existe
**When** faço GET para `/api/conversations?status=completed`
**Then** a API retorna apenas conversas com status "completed"

**And** suporta filtros: `active`, `completed`, `aborted`, `error`

**And** se status inválido, retorna erro 400 com mensagem apropriada

**Prerequisites:** Story 2.1

**Technical Notes:**
- Adicionar query param `status` na API route
- Validar status contra valores permitidos
- Atualizar query SQL com WHERE clause quando status fornecido

### Story 2.3: Ordenação de Conversas por Data

As a **desenvolvedor**,
I want **ordenar conversas por data de início**,
So that **posso ver conversas mais recentes ou mais antigas primeiro**.

**Acceptance Criteria:**

**Given** que a API de listagem existe
**When** faço GET para `/api/conversations?sort=start_time&order=desc`
**Then** a API retorna conversas ordenadas por start_time descendente (mais recentes primeiro)

**And** suporta order: `asc` ou `desc` (default: desc)

**And** se order inválido, usa default (desc)

**Prerequisites:** Story 2.1

**Technical Notes:**
- Adicionar query params `sort` e `order`
- Validar order (asc/desc)
- Atualizar query SQL com ORDER BY

### Story 2.4: Busca de Conversas por ID ou Email

As a **desenvolvedor**,
I want **buscar conversas por ID ou email do usuário**,
So that **posso encontrar conversas específicas rapidamente**.

**Acceptance Criteria:**

**Given** que a API de listagem existe
**When** faço GET para `/api/conversations?search=user@example.com`
**Then** a API retorna conversas onde:
- conversation_id contém o termo de busca OU
- user_email contém o termo de busca

**And** a busca é case-insensitive

**And** se nenhum resultado encontrado, retorna array vazio

**Prerequisites:** Story 2.1

**Technical Notes:**
- Adicionar query param `search`
- Usar LIKE no SQL com wildcards
- Combinar com outros filtros quando aplicável

### Story 2.5: Página de Lista de Conversas

As a **desenvolvedor**,
I want **página que lista todas as conversas**,
So that **posso visualizar e navegar pelas conversas disponíveis**.

**Acceptance Criteria:**

**Given** que as API routes estão funcionando
**When** acesso `/conversations`
**Then** a página exibe:
- Lista de conversas em formato de cards ou tabela
- Para cada conversa: ID, email do usuário, status (com badge colorido), data de início formatada
- Paginação funcional (próxima/anterior, número de página)
- Loading state durante carregamento
- Mensagem se nenhuma conversa encontrada

**And** cada conversa é clicável e navega para `/conversations/[id]`

**Prerequisites:** Story 2.1

**Technical Notes:**
- Criar `app/(dashboard)/conversations/page.tsx`
- Criar componente `ConversationList.tsx`
- Usar Server Components para dados iniciais
- Implementar paginação no frontend

### Story 2.6: Filtros e Busca na Interface

As a **desenvolvedor**,
I want **interface para filtrar e buscar conversas**,
So that **posso encontrar conversas específicas facilmente**.

**Acceptance Criteria:**

**Given** que a página de lista existe
**When** acesso a página
**Then** vejo controles para:
- Dropdown de filtro por status (Todos, Active, Completed, Aborted, Error)
- Campo de busca por ID ou email
- Botão de ordenação (mais recente/mais antigo)

**And** ao selecionar filtro ou buscar, a lista atualiza automaticamente

**And** os filtros são mantidos na URL como query params

**Prerequisites:** Story 2.5

**Technical Notes:**
- Criar componentes de filtro e busca
- Usar Client Components para interatividade
- Atualizar URL com query params usando Next.js router
- Debounce na busca para performance

### Story 2.7: Página de Detalhes de Conversa

As a **desenvolvedor**,
I want **página com detalhes completos de uma conversa**,
So that **posso ver todas as informações e gerações relacionadas**.

**Acceptance Criteria:**

**Given** que a lista de conversas existe
**When** clico em uma conversa
**Then** navego para `/conversations/[id]` que exibe:
- Informações completas da conversa (ID, email, status, timestamps, cursor_version)
- Lista de workspaces associados
- Lista de todas as gerações relacionadas (com links para detalhes)
- Breadcrumb mostrando localização atual

**And** cada geração é clicável e navega para `/generations/[id]`

**Prerequisites:** Story 2.5

**Technical Notes:**
- Criar `app/(dashboard)/conversations/[id]/page.tsx`
- Criar componente `ConversationDetail.tsx`
- Criar API route `app/api/conversations/[id]/route.ts`
- Criar query `getConversationById()` em `lib/queries/conversations.ts`
- Incluir JOIN para buscar gerações relacionadas

### Story 2.8: API Route para Gerações de uma Conversa

As a **desenvolvedor**,
I want **API route que retorna gerações de uma conversa**,
So that **posso carregar gerações relacionadas**.

**Acceptance Criteria:**

**Given** que a API de detalhes de conversa existe
**When** faço GET para `/api/conversations/[id]/generations`
**Then** a API retorna:
- Lista de todas as gerações da conversa
- Cada geração com: generation_id, model, status, start_time, end_time
- Ordenadas por start_time (mais antigas primeiro)

**And** se conversa não encontrada, retorna 404

**Prerequisites:** Story 2.7

**Technical Notes:**
- Criar `app/api/conversations/[id]/generations/route.ts`
- Criar query `getGenerationsByConversationId()` em `lib/queries/generations.ts`
- Validar que conversation_id existe antes de buscar gerações

---

## Epic 3: Visualização de Gerações e Eventos

**Goal:** Permitir exploração detalhada de gerações e eventos, incluindo timeline cronológica e visualização específica por tipo de evento.

**FRs Covered:** FR11, FR12, FR13, FR14, FR15, FR16, FR17, FR18, FR19, FR20, FR21, FR22, FR31, FR32

### Story 3.1: API Route para Detalhes de Geração

As a **desenvolvedor**,
I want **API route que retorna detalhes de uma geração**,
So that **posso ver informações completas de uma geração específica**.

**Acceptance Criteria:**

**Given** que a conexão com banco está configurada
**When** faço GET para `/api/generations/[id]`
**Then** a API retorna:
- Informações da geração: generation_id, conversation_id, model, status, start_time, end_time
- Duração calculada (se end_time disponível)
- Link para conversa relacionada

**And** se geração não encontrada, retorna 404

**Prerequisites:** Story 1.2

**Technical Notes:**
- Criar `app/api/generations/[id]/route.ts`
- Criar query `getGenerationById()` em `lib/queries/generations.ts`
- Calcular duração em milissegundos (end_time - start_time)

### Story 3.2: API Route para Eventos de uma Geração

As a **desenvolvedor**,
I want **API route que retorna eventos de uma geração**,
So that **posso ver todos os eventos relacionados a uma geração**.

**Acceptance Criteria:**

**Given** que a API de detalhes de geração existe
**When** faço GET para `/api/generations/[id]/events`
**Then** a API retorna:
- Lista de todos os eventos da geração ordenados por timestamp
- Cada evento com: event_id, event_type, hook_event_name, timestamp, data_json
- Suporta filtro por tipo: `?event_type=beforeSubmitPrompt`

**And** se geração não encontrada, retorna 404

**Prerequisites:** Story 3.1

**Technical Notes:**
- Criar `app/api/generations/[id]/events/route.ts`
- Criar query `getEventsByGenerationId()` em `lib/queries/events.ts`
- Parsear data_json como objeto (não string)
- Ordenar por timestamp ASC

### Story 3.3: Página de Detalhes de Geração

As a **desenvolvedor**,
I want **página com detalhes completos de uma geração**,
So that **posso ver informações e eventos relacionados**.

**Acceptance Criteria:**

**Given** que as API routes de geração existem
**When** acesso `/generations/[id]`
**Then** a página exibe:
- Informações da geração (ID, modelo, status, timestamps, duração formatada)
- Link para conversa relacionada
- Lista de eventos da geração
- Breadcrumb mostrando: Conversas > Geração [id]

**And** cada evento é clicável para ver detalhes

**Prerequisites:** Story 3.1, Story 3.2

**Technical Notes:**
- Criar `app/(dashboard)/generations/[id]/page.tsx`
- Criar componente `GenerationDetail.tsx`
- Usar Server Components para dados iniciais
- Implementar formatação de duração (lib/utils/format.ts)

### Story 3.4: Componente de Timeline de Eventos

As a **desenvolvedor**,
I want **visualização em timeline dos eventos de uma geração**,
So that **posso ver a sequência cronológica de eventos**.

**Acceptance Criteria:**

**Given** que a página de detalhes de geração existe
**When** visualizo a timeline
**Then** vejo eventos organizados cronologicamente:
- Linha vertical representando tempo
- Cada evento como item na timeline com timestamp formatado
- Ícones diferentes por tipo de evento
- Eventos agrupados visualmente por proximidade temporal

**And** eventos são clicáveis para ver detalhes completos

**Prerequisites:** Story 3.3

**Technical Notes:**
- Criar componente `EventTimeline.tsx`
- Usar biblioteca de timeline ou criar custom
- Formatar timestamps usando lib/utils/format.ts
- Mapear event_type para ícones apropriados

### Story 3.5: Visualização de Eventos por Tipo - Prompts e Respostas

As a **desenvolvedor**,
I want **visualização específica para prompts e respostas do agente**,
So that **posso ver claramente a interação usuário-agente**.

**Acceptance Criteria:**

**Given** que a timeline de eventos existe
**When** visualizo eventos do tipo `beforeSubmitPrompt` ou `afterAgentResponse`
**Then** vejo:
- Para prompts: texto do prompt formatado, attachments se houver
- Para respostas: texto da resposta formatado, duração se disponível
- Destaque visual diferenciando prompts (usuário) de respostas (agente)

**And** textos longos são truncados com opção "Expandir"

**Prerequisites:** Story 3.4

**Technical Notes:**
- Criar componentes `PromptEvent.tsx` e `AgentResponseEvent.tsx`
- Parsear data_json para extrair texto
- Implementar truncamento de texto (Story 5.4)

### Story 3.6: Visualização de Eventos por Tipo - Pensamentos do Agente

As a **desenvolvedor**,
I want **visualizar pensamentos do agente**,
So that **posso entender o raciocínio por trás das respostas**.

**Acceptance Criteria:**

**Given** que a timeline de eventos existe
**When** visualizo eventos do tipo `afterAgentThought`
**Then** vejo:
- Texto do pensamento formatado
- Duração do pensamento em formato legível
- Destaque visual indicando que é raciocínio interno

**And** textos são truncados com opção de expandir

**Prerequisites:** Story 3.4

**Technical Notes:**
- Criar componente `AgentThoughtEvent.tsx`
- Extrair text e duration_ms de data_json
- Formatar duração usando lib/utils/format.ts

### Story 3.7: Visualização de Eventos por Tipo - Execuções Shell

As a **desenvolvedor**,
I want **visualizar comandos shell executados**,
So that **posso ver quais comandos foram executados pelo agente**.

**Acceptance Criteria:**

**Given** que a timeline de eventos existe
**When** visualizo eventos do tipo `afterShellExecution`
**Then** vejo:
- Comando executado com syntax highlighting
- Diretório de trabalho (cwd)
- Saída do comando (truncada se muito longa)
- Duração da execução formatada

**And** comando é copiável para clipboard

**Prerequisites:** Story 3.4

**Technical Notes:**
- Criar componente `ShellExecutionEvent.tsx`
- Usar biblioteca de syntax highlighting (ex: react-syntax-highlighter)
- Buscar dados de shell_executions table via JOIN
- Implementar botão de copiar

### Story 3.8: Visualização de Eventos por Tipo - Execuções MCP

As a **desenvolvedor**,
I want **visualizar execuções de ferramentas MCP**,
So that **posso ver quais ferramentas foram usadas**.

**Acceptance Criteria:**

**Given** que a timeline de eventos existe
**When** visualizo eventos do tipo `afterMCPExecution`
**Then** vejo:
- Nome da ferramenta MCP
- Parâmetros de entrada (JSON formatado)
- Resultado (JSON formatado, truncado se muito longo)
- Duração da execução formatada

**Prerequisites:** Story 3.4

**Technical Notes:**
- Criar componente `MCPExecutionEvent.tsx`
- Buscar dados de mcp_executions table via JOIN
- Formatar JSON com syntax highlighting
- Truncar resultados grandes

### Story 3.9: Visualização de Eventos por Tipo - Edições de Arquivos

As a **desenvolvedor**,
I want **visualizar edições de arquivos feitas pelo agente**,
So que **posso ver quais arquivos foram modificados**.

**Acceptance Criteria:**

**Given** que a timeline de eventos existe
**When** visualizo eventos do tipo `afterFileEdit`
**Then** vejo:
- Caminho do arquivo editado
- Número de edições realizadas
- Preview das edições (diff visual se possível)
- Link para ver todas as edições em detalhes

**Prerequisites:** Story 3.4

**Technical Notes:**
- Criar componente `FileEditEvent.tsx`
- Buscar dados de file_edits e file_edit_details tables via JOIN
- Implementar diff visual básico ou link para detalhes expandidos

### Story 3.10: Visualização de Eventos por Tipo - Finalização do Loop

As a **desenvolvedor**,
I want **visualizar quando o loop do agente finaliza**,
So that **posso ver o status final e contagem de loops**.

**Acceptance Criteria:**

**Given** que a timeline de eventos existe
**When** visualizo eventos do tipo `stop`
**Then** vejo:
- Status da finalização (completed, aborted, error)
- Contagem de loops executados
- Mensagem de followup se disponível

**Prerequisites:** Story 3.4

**Technical Notes:**
- Criar componente `StopEvent.tsx`
- Buscar dados de generation_stops table via JOIN
- Exibir badge colorido baseado no status

### Story 3.11: Navegação de Evento para Geração/Conversa

As a **desenvolvedor**,
I want **navegar de um evento para sua geração/conversa relacionada**,
So that **posso explorar o contexto completo**.

**Acceptance Criteria:**

**Given** que estou visualizando um evento
**When** clico em link "Ver geração" ou "Ver conversa"
**Then** navego para a página correspondente

**And** breadcrumb mostra o caminho completo

**Prerequisites:** Story 3.3, Story 2.7

**Technical Notes:**
- Adicionar links de navegação nos componentes de evento
- Usar Next.js Link para navegação
- Manter breadcrumb atualizado

---

## Epic 4: Análise de Decisões de Reexecução

**Goal:** Permitir análise detalhada das decisões do agente sobre continuar ou finalizar tarefas, incluindo filtros, estatísticas e navegação para contexto relacionado.

**FRs Covered:** FR23, FR24, FR25, FR26, FR27, FR28, FR29, FR33

### Story 4.1: API Route para Listar Decisões de Reexecução

As a **desenvolvedor**,
I want **API route que retorna lista de decisões de reexecução**,
So that **posso buscar decisões do banco de dados**.

**Acceptance Criteria:**

**Given** que a conexão com banco está configurada
**When** faço GET para `/api/decisions`
**Then** a API retorna:
- Lista paginada de decisões (default: 50 por página)
- Cada decisão com: decision_id, conversation_id, generation_id, finish, reason, followup_message, timestamp
- Metadados de paginação

**And** suporta query params: `?page=1&limit=50&finish=true`

**Prerequisites:** Story 1.2

**Technical Notes:**
- Criar `app/api/decisions/route.ts`
- Criar `lib/queries/decisions.ts` com função `getDecisions()`
- Suportar filtro por finish (true/false)

### Story 4.2: Filtros de Decisões por Finish

As a **desenvolvedor**,
I want **filtrar decisões por finish (concluída/continuar)**,
So that **posso focar em decisões específicas**.

**Acceptance Criteria:**

**Given** que a API de listagem existe
**When** faço GET para `/api/decisions?finish=true`
**Then** a API retorna apenas decisões onde finish = true (tarefa concluída)

**And** suporta `finish=false` para tarefas que precisam continuar

**And** se finish não fornecido, retorna todas as decisões

**Prerequisites:** Story 4.1

**Technical Notes:**
- Adicionar query param `finish` na API route
- Validar que finish é boolean
- Atualizar query SQL com WHERE clause quando finish fornecido

### Story 4.3: Página de Lista de Decisões

As a **desenvolvedor**,
I want **página que lista todas as decisões de reexecução**,
So that **posso visualizar e analisar decisões do agente**.

**Acceptance Criteria:**

**Given** que a API route existe
**When** acesso `/decisions`
**Then** a página exibe:
- Lista de decisões em formato de cards
- Para cada decisão: finish (badge verde/vermelho), reason resumido, timestamp formatado
- Filtro por finish (Todos, Concluídas, Continuar)
- Paginação funcional
- Estatísticas: total concluídas vs continuadas

**And** cada decisão é clicável para ver detalhes

**Prerequisites:** Story 4.1

**Technical Notes:**
- Criar `app/(dashboard)/decisions/page.tsx`
- Criar componente `DecisionList.tsx`
- Calcular estatísticas no servidor ou cliente
- Implementar filtros na interface

### Story 4.4: Visualização Detalhada de Decisão

As a **desenvolvedor**,
I want **ver detalhes completos de uma decisão**,
So that **posso entender o contexto e razão da decisão**.

**Acceptance Criteria:**

**Given** que a lista de decisões existe
**When** clico em uma decisão
**Then** vejo página de detalhes com:
- Informações completas: finish, reason, followup_message, timestamp
- Prompt relacionado à decisão (se disponível)
- Resumo da resposta do agente relacionada (se disponível)
- Links para conversa e geração relacionadas
- Breadcrumb mostrando localização

**Prerequisites:** Story 4.3

**Technical Notes:**
- Criar página de detalhes (ou modal)
- Buscar prompt e resposta relacionadas via queries
- Implementar navegação para conversa/geração

### Story 4.5: Navegação de Decisão para Conversa/Geração

As a **desenvolvedor**,
I want **navegar de uma decisão para sua conversa/geração relacionada**,
So that **posso ver o contexto completo da decisão**.

**Acceptance Criteria:**

**Given** que estou visualizando uma decisão
**When** clico em "Ver conversa" ou "Ver geração"
**Then** navego para a página correspondente

**And** o contexto da decisão é preservado (breadcrumb mostra origem)

**Prerequisites:** Story 4.4, Story 2.7, Story 3.3

**Technical Notes:**
- Adicionar links de navegação no componente de decisão
- Usar Next.js Link
- Manter breadcrumb atualizado

### Story 4.6: Estatísticas de Decisões

As a **desenvolvedor**,
I want **ver estatísticas sobre decisões de reexecução**,
So that **posso entender padrões de comportamento do agente**.

**Acceptance Criteria:**

**Given** que a página de decisões existe
**When** visualizo a página
**Then** vejo estatísticas:
- Total de decisões
- Total concluídas (finish=true)
- Total que precisam continuar (finish=false)
- Taxa de conclusão (percentual)
- Razões mais comuns (top 5)

**And** estatísticas são atualizadas quando filtros são aplicados

**Prerequisites:** Story 4.3

**Technical Notes:**
- Criar componente `DecisionStats.tsx`
- Calcular estatísticas via query SQL agregada
- Exibir em cards ou gráficos simples

---

## Epic 5: Formatação e Navegação de Dados

**Goal:** Garantir que dados sejam formatados de forma legível e que navegação entre entidades relacionadas seja intuitiva.

**FRs Covered:** FR34, FR35, FR36, FR37, FR38, FR39

### Story 5.1: Breadcrumbs de Navegação

As a **desenvolvedor**,
I want **breadcrumbs mostrando minha localização atual**,
So that **posso navegar facilmente na hierarquia de dados**.

**Acceptance Criteria:**

**Given** que estou em qualquer página do dashboard
**When** visualizo a página
**Then** vejo breadcrumb mostrando:
- Home > [página atual]
- Para conversas: Home > Conversas > [ID da conversa]
- Para gerações: Home > Conversas > [ID] > Gerações > [ID]
- Para eventos: Home > Conversas > [ID] > Gerações > [ID] > Eventos

**And** cada item do breadcrumb é clicável para navegar

**Prerequisites:** Story 2.5

**Technical Notes:**
- Criar componente `Breadcrumbs.tsx` reutilizável
- Passar path como prop para cada página
- Usar Next.js Link para navegação

### Story 5.2: Formatação de JSON

As a **desenvolvedor**,
I want **dados JSON formatados de forma legível**,
So that **posso ler facilmente estruturas de dados complexas**.

**Acceptance Criteria:**

**Given** que estou visualizando dados JSON
**When** os dados são exibidos
**Then** vejo JSON formatado com:
- Indentação apropriada
- Syntax highlighting
- Colapsar/expandir objetos aninhados
- Números de linha (opcional)

**Prerequisites:** Story 3.4

**Technical Notes:**
- Criar função `formatJSON()` em `lib/utils/format.ts`
- Usar biblioteca de syntax highlighting
- Criar componente `JSONViewer.tsx` reutilizável

### Story 5.3: Formatação de Timestamps

As a **desenvolvedor**,
I want **timestamps formatados em formato legível**,
So that **posso entender facilmente quando eventos ocorreram**.

**Acceptance Criteria:**

**Given** que estou visualizando timestamps
**When** os timestamps são exibidos
**Then** vejo formato legível:
- Data: "29 Nov 2025"
- Hora: "19:52"
- Data completa: "29 Nov 2025, 19:52"
- Relativo: "há 2 horas" (para eventos recentes)

**And** formato usa locale pt-BR

**Prerequisites:** Story 2.5

**Technical Notes:**
- Criar função `formatTimestamp()` em `lib/utils/format.ts`
- Usar `Intl.DateTimeFormat` com locale pt-BR
- Implementar formatação relativa para eventos recentes (< 24h)

### Story 5.4: Formatação de Durações

As a **desenvolvedor**,
I want **durações formatadas em formato legível**,
So that **posso entender facilmente quanto tempo operações levaram**.

**Acceptance Criteria:**

**Given** que estou visualizando durações
**When** as durações são exibidas
**Then** vejo formato legível:
- < 1s: "500ms"
- < 1min: "45s"
- < 1h: "12min 30s"
- >= 1h: "2h 15min"

**And** valores são arredondados apropriadamente

**Prerequisites:** Story 3.3

**Technical Notes:**
- Criar função `formatDuration()` em `lib/utils/format.ts`
- Converter milissegundos para formato legível
- Implementar lógica de arredondamento

### Story 5.5: Truncamento de Textos Longos

As a **desenvolvedor**,
I want **textos longos truncados com opção de expandir**,
So that **a interface não fique sobrecarregada mas eu possa ver conteúdo completo**.

**Acceptance Criteria:**

**Given** que estou visualizando texto longo
**When** o texto excede limite (ex: 500 caracteres)
**Then** vejo:
- Texto truncado com "..." no final
- Botão "Expandir" para ver texto completo
- Botão "Recolher" quando expandido

**And** truncamento preserva palavras (não corta no meio)

**Prerequisites:** Story 3.5

**Technical Notes:**
- Criar componente `TruncatedText.tsx` reutilizável
- Usar estado para controlar expandido/recolhido
- Implementar lógica de truncamento inteligente

### Story 5.6: Syntax Highlighting para Código

As a **desenvolvedor**,
I want **código exibido com syntax highlighting**,
So that **posso ler facilmente comandos shell e JSON**.

**Acceptance Criteria:**

**Given** que estou visualizando código (shell, JSON)
**When** o código é exibido
**Then** vejo:
- Syntax highlighting apropriado para o tipo de código
- Numeração de linhas (opcional)
- Botão "Copiar" para copiar código
- Tema de cores legível

**Prerequisites:** Story 3.7

**Technical Notes:**
- Usar biblioteca react-syntax-highlighter
- Configurar temas apropriados
- Implementar botão de copiar para clipboard

---

## Epic 6: Tratamento de Erros e Validação

**Goal:** Garantir experiência robusta mesmo quando ocorrem erros, com mensagens claras e tratamento gracioso de dados ausentes ou corrompidos.

**FRs Covered:** FR40, FR41, FR42, FR43

### Story 6.1: Detecção e Mensagem para Banco Não Encontrado

As a **desenvolvedor**,
I want **mensagem clara quando banco não é encontrado**,
So that **sei exatamente o que fazer para corrigir o problema**.

**Acceptance Criteria:**

**Given** que o sistema tenta conectar ao banco
**When** o arquivo `.cursor/database/cursor_hooks.db` não existe
**Then** vejo mensagem:
- Título: "Banco de dados não encontrado"
- Descrição: "O arquivo cursor_hooks.db não foi encontrado em .cursor/database/"
- Instruções: "Verifique se o caminho está correto e se o arquivo existe"
- Caminho completo exibido

**And** a mensagem é exibida em página dedicada ou componente de erro

**Prerequisites:** Story 1.3

**Technical Notes:**
- Melhorar validação em `lib/db.ts`
- Criar componente `DatabaseNotFoundError.tsx`
- Exibir em página de erro ou componente global

### Story 6.2: Tratamento de Erros de Conexão

As a **desenvolvedor**,
I want **mensagem clara quando há erro de conexão com banco**,
So that **posso diagnosticar problemas de acesso ao banco**.

**Acceptance Criteria:**

**Given** que o sistema tenta conectar ao banco
**When** ocorre erro de conexão (permissões, arquivo corrompido, etc.)
**Then** vejo mensagem de erro:
- Título: "Erro ao conectar com banco de dados"
- Descrição do erro específico
- Sugestões de solução quando aplicável

**And** erro é logado no servidor para debug

**Prerequisites:** Story 1.3

**Technical Notes:**
- Implementar try/catch em `lib/db.ts`
- Criar componente `DatabaseConnectionError.tsx`
- Logar erros com console.error

### Story 6.3: Mensagens de Erro Amigáveis para Consultas SQL

As a **desenvolvedor**,
I want **mensagens de erro amigáveis quando consultas SQL falham**,
So that **posso entender o problema sem ver detalhes técnicos brutos**.

**Acceptance Criteria:**

**Given** que uma API route executa consulta SQL
**When** a consulta falha
**Then** vejo mensagem de erro:
- Amigável ao usuário (não mostra SQL ou stack trace)
- Indica o que estava sendo feito ("Erro ao buscar conversas")
- Sugere ação quando possível ("Tente novamente ou verifique o banco de dados")

**And** erro completo é logado no servidor para debug

**Prerequisites:** Story 2.1

**Technical Notes:**
- Implementar try/catch em todas as API routes
- Criar função helper `handleDatabaseError()` em `lib/utils/errors.ts`
- Mapear erros SQL para mensagens amigáveis
- Retornar status code apropriado (400, 500)

### Story 6.4: Tratamento Gracioso de Dados Ausentes ou Corrompidos

As a **desenvolvedor**,
I want **sistema que lida graciosamente com dados ausentes ou corrompidos**,
So that **a experiência não seja quebrada por dados inválidos**.

**Acceptance Criteria:**

**Given** que o sistema busca dados do banco
**When** dados estão ausentes (NULL) ou corrompidos (JSON inválido)
**Then** o sistema:
- Não quebra ou mostra erros técnicos
- Exibe valores padrão apropriados ("N/A", "Não disponível")
- Continua funcionando para outros dados válidos
- Loga problema no servidor para investigação

**And** campos opcionais são tratados como opcionais (não causam erro)

**Prerequisites:** Story 2.1

**Technical Notes:**
- Implementar validação de dados em queries
- Criar função `safeParseJSON()` em `lib/utils/format.ts`
- Usar valores padrão quando dados ausentes
- Validar tipos antes de usar dados

---

## FR Coverage Matrix

| FR | Epic | Story | Status |
|----|------|------|--------|
| FR1 | Epic 1 | Story 1.1 | Covered |
| FR2 | Epic 1 | Story 1.2 | Covered |
| FR3 | Epic 1 | Story 1.3 | Covered |
| FR4 | Epic 2 | Story 2.1 | Covered |
| FR5 | Epic 2 | Story 2.2 | Covered |
| FR6 | Epic 2 | Story 2.3 | Covered |
| FR7 | Epic 2 | Story 2.4 | Covered |
| FR8 | Epic 2 | Story 2.7 | Covered |
| FR9 | Epic 2 | Story 2.8 | Covered |
| FR10 | Epic 2 | Story 2.7 | Covered |
| FR11 | Epic 3 | Story 3.1 | Covered |
| FR12 | Epic 3 | Story 3.2 | Covered |
| FR13 | Epic 3 | Story 3.1 | Covered |
| FR14 | Epic 3 | Story 3.5 | Covered |
| FR15 | Epic 3 | Story 3.5 | Covered |
| FR16 | Epic 3 | Story 3.6 | Covered |
| FR17 | Epic 3 | Story 3.7 | Covered |
| FR18 | Epic 3 | Story 3.8 | Covered |
| FR19 | Epic 3 | Story 3.9 | Covered |
| FR20 | Epic 3 | Story 3.10 | Covered |
| FR21 | Epic 3 | Story 3.4 | Covered |
| FR22 | Epic 3 | Stories 3.5-3.10 | Covered |
| FR23 | Epic 4 | Story 4.1 | Covered |
| FR24 | Epic 4 | Story 4.2 | Covered |
| FR25 | Epic 4 | Story 4.4 | Covered |
| FR26 | Epic 4 | Story 4.4 | Covered |
| FR27 | Epic 4 | Story 4.4 | Covered |
| FR28 | Epic 4 | Story 4.5 | Covered |
| FR29 | Epic 4 | Story 4.6 | Covered |
| FR30 | Epic 2 | Story 2.7 | Covered |
| FR31 | Epic 3 | Story 3.3 | Covered |
| FR32 | Epic 3 | Story 3.11 | Covered |
| FR33 | Epic 4 | Story 4.5 | Covered |
| FR34 | Epic 5 | Story 5.1 | Covered |
| FR35 | Epic 5 | Story 5.2 | Covered |
| FR36 | Epic 5 | Story 5.3 | Covered |
| FR37 | Epic 5 | Story 5.4 | Covered |
| FR38 | Epic 5 | Story 5.5 | Covered |
| FR39 | Epic 5 | Story 5.6 | Covered |
| FR40 | Epic 6 | Story 6.1 | Covered |
| FR41 | Epic 6 | Story 6.2 | Covered |
| FR42 | Epic 6 | Story 6.3 | Covered |
| FR43 | Epic 6 | Story 6.4 | Covered |

**Coverage:** 43/43 FRs (100%)

---

## Summary

Este breakdown de épicos e histórias cobre todos os 43 Functional Requirements do PRD, organizados em 6 épicos que entregam valor incremental:

1. **Epic 1: Foundation & Setup** (3 stories) - Base técnica do projeto
2. **Epic 2: Visualização de Conversas** (8 stories) - Capacidade de visualizar e navegar conversas
3. **Epic 3: Visualização de Gerações e Eventos** (11 stories) - Exploração detalhada de gerações e eventos
4. **Epic 4: Análise de Decisões de Reexecução** (6 stories) - Análise de decisões do agente
5. **Epic 5: Formatação e Navegação de Dados** (6 stories) - Formatação legível e navegação intuitiva
6. **Epic 6: Tratamento de Erros e Validação** (4 stories) - Experiência robusta mesmo com erros

**Total:** 38 histórias implementáveis, cada uma completável por um agente de desenvolvimento em uma sessão focada.

Cada história inclui:
- User story format (As a... I want... So that...)
- Acceptance criteria detalhados (Given/When/Then)
- Prerequisites claros
- Technical notes com referências à arquitetura

---

_For implementation: Use the `create-story` workflow to generate individual story implementation plans from this epic breakdown._

_This document will be updated after UX Design and Architecture workflows to incorporate interaction details and technical decisions._

