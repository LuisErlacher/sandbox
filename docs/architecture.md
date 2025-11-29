# Architecture

## Executive Summary

Esta arquitetura define um dashboard web Next.js para visualização de dados dos hooks do Cursor armazenados em SQLite. A arquitetura utiliza Next.js 15 com App Router, TypeScript, Tailwind CSS, e better-sqlite3 para acesso ao banco de dados. O foco está em leitura eficiente de dados, visualização clara de relacionamentos hierárquicos (conversas → gerações → eventos), e navegação intuitiva entre entidades relacionadas.

## Project Initialization

Primeira story de implementação deve executar:

```bash
npx create-next-app@latest dashboard --typescript --tailwind --app --no-src-dir --import-alias "@/*"
```

Este comando estabelece a arquitetura base com estas decisões:
- Framework: Next.js 15 (App Router)
- Linguagem: TypeScript
- Estilização: Tailwind CSS
- Linting: ESLint
- Estrutura: App Router (app/ directory)

## Decision Summary

| Category | Decision | Version | Affects FR Categories | Rationale |
| -------- | -------- | ------- | --------------------- | --------- |
| Framework | Next.js | 15.x | All | App Router moderno, SSR/SSG, API routes integradas |
| Language | TypeScript | 5.x | All | Type safety, melhor DX, padrão Next.js |
| Styling | Tailwind CSS | 3.x | All | Utility-first, rápido desenvolvimento, incluído no starter |
| Database Access | better-sqlite3 | Latest | Conversation Management, Generation Viewing, Event Visualization, Reexecution Decisions | Síncrono, rápido para leitura, ideal para dashboard read-only |
| API Pattern | REST (Next.js API Routes) | - | All | Padrão Next.js, simples para CRUD de dados |
| Data Format | JSON (objetos aninhados) | - | Data Display | Estrutura natural para dados relacionais |
| Pagination | Query params (?page=1&limit=50) | - | Conversation Management, Event Visualization | Padrão REST comum, fácil de implementar |
| Error Handling | Try/catch com mensagens amigáveis | - | Error Handling | Consistência e UX melhorada |
| Date Format | ISO 8601 (formatar no frontend) | - | Data Display | Padrão universal, flexibilidade de formatação |
| Duration Format | Milissegundos (converter no frontend) | - | Data Display | Precisão mantida, formatação flexível |

## Project Structure

```
dashboard/
├── app/
│   ├── api/
│   │   ├── conversations/
│   │   │   ├── route.ts              # GET /api/conversations (lista com filtros)
│   │   │   └── [id]/
│   │   │       ├── route.ts          # GET /api/conversations/[id] (detalhes)
│   │   │       └── generations/
│   │   │           └── route.ts      # GET /api/conversations/[id]/generations
│   │   ├── generations/
│   │   │   ├── route.ts              # GET /api/generations (lista)
│   │   │   └── [id]/
│   │   │       ├── route.ts          # GET /api/generations/[id] (detalhes)
│   │   │       └── events/
│   │   │           └── route.ts      # GET /api/generations/[id]/events
│   │   ├── events/
│   │   │   └── route.ts              # GET /api/events (lista com filtros)
│   │   ├── decisions/
│   │   │   └── route.ts              # GET /api/decisions (lista com filtros)
│   │   └── health/
│   │       └── route.ts              # GET /api/health (health check)
│   ├── (dashboard)/
│   │   ├── page.tsx                  # Dashboard home (lista de conversas)
│   │   ├── conversations/
│   │   │   ├── page.tsx              # Lista de conversas
│   │   │   └── [id]/
│   │   │       └── page.tsx          # Detalhes da conversa
│   │   ├── generations/
│   │   │   └── [id]/
│   │   │       └── page.tsx          # Detalhes da geração
│   │   └── decisions/
│   │       └── page.tsx              # Lista de decisões de reexecução
│   ├── layout.tsx                    # Root layout
│   └── globals.css                   # Global styles (Tailwind)
├── lib/
│   ├── db.ts                         # SQLite connection singleton
│   ├── queries/
│   │   ├── conversations.ts          # Queries para conversas
│   │   ├── generations.ts            # Queries para gerações
│   │   ├── events.ts                  # Queries para eventos
│   │   └── decisions.ts              # Queries para decisões
│   └── utils/
│       ├── format.ts                 # Formatação de dados (datas, durações)
│       ├── pagination.ts              # Helpers de paginação
│       ├── observability.ts           # Server-Timing, trace IDs, logging estruturado
│       └── test-utils/
│           └── factories.ts           # Factories de dados para testes
├── components/
│   ├── ui/                           # Componentes UI reutilizáveis
│   │   ├── Button.tsx
│   │   ├── Card.tsx
│   │   ├── Table.tsx
│   │   └── Badge.tsx
│   ├── conversations/
│   │   ├── ConversationList.tsx
│   │   ├── ConversationCard.tsx
│   │   └── ConversationDetail.tsx
│   ├── generations/
│   │   ├── GenerationList.tsx
│   │   └── GenerationDetail.tsx
│   ├── events/
│   │   ├── EventList.tsx
│   │   ├── EventCard.tsx
│   │   └── EventTimeline.tsx
│   └── decisions/
│       ├── DecisionList.tsx
│       └── DecisionCard.tsx
├── types/
│   └── database.ts                   # TypeScript types para entidades do banco
├── public/                           # Static assets
├── package.json
├── tsconfig.json
├── tailwind.config.ts
└── next.config.js
```

## FR Category to Architecture Mapping

| FR Category | Component Location | API Route | Database Query |
| ---------- | ------------------ | --------- | -------------- |
| User Account & Access | app/(dashboard)/page.tsx | N/A (local tool) | N/A |
| Conversation Management | app/(dashboard)/conversations/, components/conversations/ | /api/conversations | lib/queries/conversations.ts |
| Generation Viewing | app/(dashboard)/generations/, components/generations/ | /api/generations | lib/queries/generations.ts |
| Event Visualization | components/events/, EventTimeline.tsx | /api/events | lib/queries/events.ts |
| Reexecution Decisions Analysis | app/(dashboard)/decisions/, components/decisions/ | /api/decisions | lib/queries/decisions.ts |
| Data Navigation | Components com links/breadcrumbs | Nested routes | JOIN queries |
| Data Display | lib/utils/format.ts, components | N/A | N/A |
| Error Handling | app/api/**/route.ts | All API routes | lib/db.ts |

## Technology Stack Details

### Core Technologies

- **Next.js 15.x**: Framework React com App Router, SSR, API Routes
- **TypeScript 5.x**: Type safety e melhor developer experience
- **Tailwind CSS 3.x**: Utility-first CSS framework
- **better-sqlite3**: Biblioteca síncrona para acesso ao SQLite (read-only)
- **React 18.x**: Biblioteca UI (incluída no Next.js)

### Integration Points

1. **Database Connection**: `lib/db.ts` cria singleton connection ao SQLite
   - Path: `{project-root}/.cursor/database/cursor_hooks.db`
   - Read-only access (apenas SELECT queries)
   - Singleton pattern para reutilizar conexão

2. **API Routes → Database**: API routes chamam queries de `lib/queries/`
   - Cada query retorna dados tipados
   - Erros são capturados e retornados como JSON

3. **Frontend → API**: Componentes React fazem fetch para API routes
   - Server Components para dados iniciais (SSR)
   - Client Components com useState/useEffect para interatividade

## Implementation Patterns

Estes padrões garantem implementação consistente entre todos os agentes de IA:

### API Route Pattern

```typescript
// app/api/[resource]/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { getResource } from '@/lib/queries/resource';
import { withObservability } from '@/lib/utils/observability';

export async function GET(request: NextRequest) {
  return withObservability(request, async (traceId) => {
    try {
      const startTime = performance.now();
      const { searchParams } = new URL(request.url);
      const page = parseInt(searchParams.get('page') || '1');
      const limit = parseInt(searchParams.get('limit') || '50');
      
      const data = await getResource({ page, limit });
      const dbTime = performance.now() - startTime;
      
      const response = NextResponse.json(data);
      
      // Server-Timing header para métricas de performance
      response.headers.set('Server-Timing', `db;dur=${dbTime.toFixed(2)},total;dur=${(performance.now() - startTime).toFixed(2)}`);
      
      // Trace ID para correlacionar requisições
      response.headers.set('X-Trace-Id', traceId);
      
      return response;
    } catch (error) {
      // Logging estruturado para erros
      console.error(JSON.stringify({
        level: 'error',
        traceId,
        message: 'Error fetching resource',
        error: error instanceof Error ? error.message : String(error),
        timestamp: new Date().toISOString()
      }));
      
      return NextResponse.json(
        { error: { message: 'Failed to fetch resource' } },
        { status: 500 }
      );
    }
  });
}
```

### Database Query Pattern

```typescript
// lib/queries/resource.ts
import db from '@/lib/db';

export function getResource({ page, limit }: { page: number; limit: number }) {
  const offset = (page - 1) * limit;
  const data = db.prepare(`
    SELECT * FROM resource
    LIMIT ? OFFSET ?
  `).all(limit, offset);
  
  const total = db.prepare('SELECT COUNT(*) as count FROM resource').get() as { count: number };
  
  return {
    data,
    pagination: {
      page,
      limit,
      total: total.count,
      totalPages: Math.ceil(total.count / limit)
    }
  };
}
```

### Component Pattern

```typescript
// components/resource/ResourceList.tsx
'use client';

import { useEffect, useState } from 'react';

export function ResourceList() {
  const [data, setData] = useState([]);
  const [loading, setLoading] = useState(true);
  
  useEffect(() => {
    fetch('/api/resource')
      .then(res => res.json())
      .then(data => {
        setData(data.data);
        setLoading(false);
      });
  }, []);
  
  if (loading) return <div>Loading...</div>;
  
  return (
    <div>
      {data.map(item => (
        <ResourceCard key={item.id} data={item} />
      ))}
    </div>
  );
}
```

## Consistency Rules

### Naming Conventions

- **Files**: kebab-case para arquivos, PascalCase para componentes React
  - `conversation-list.tsx` → componente
  - `ConversationList.tsx` → componente React
  - `conversations.ts` → query/utility

- **API Routes**: kebab-case no path, `route.ts` sempre
  - `/api/conversations/route.ts`
  - `/api/conversations/[id]/route.ts`

- **Database Tables**: snake_case (já definido no schema)
  - `conversations`, `generations`, `events`

- **TypeScript Types**: PascalCase com sufixo Type ou Interface
  - `ConversationType`, `GenerationInterface`

- **Variables**: camelCase
  - `conversationId`, `generationData`

- **Constants**: UPPER_SNAKE_CASE
  - `DEFAULT_PAGE_SIZE`, `MAX_ITEMS_PER_PAGE`

### Code Organization

- **Components**: Organizados por feature/domain
  - `components/conversations/` → tudo relacionado a conversas
  - `components/ui/` → componentes genéricos reutilizáveis

- **Queries**: Uma função por query, agrupadas por entidade
  - `lib/queries/conversations.ts` → todas queries de conversas

- **Utils**: Funções puras, sem dependências de React
  - `lib/utils/format.ts` → formatação de dados

- **Types**: Centralizados em `types/database.ts`
  - Types derivados do schema SQLite

### Error Handling

**API Routes:**
- Sempre usar try/catch
- Retornar `{ error: { message: string } }` em caso de erro
- Status code apropriado (400 para bad request, 500 para server error)
- Log de erros no servidor (console.error)

**Frontend:**
- Tratar erros de fetch com mensagens amigáveis
- Mostrar estados de loading
- Exibir mensagens de erro quando apropriado

**Database:**
- Validar existência do banco antes de queries
- Retornar mensagem clara se banco não encontrado
- Tratar dados ausentes/null graciosamente

### Logging Strategy

- **Development**: Logging estruturado (JSON) para facilitar análise e debugging
- **Production**: Logging estruturado com níveis (info, warn, error)
- **API Errors**: Sempre logar no servidor antes de retornar ao cliente com trace ID
- **Format**: JSON estruturado com campos: `level`, `traceId`, `message`, `timestamp`, `error` (opcional)

**Exemplo de Log Estruturado:**
```typescript
{
  level: 'error',
  traceId: 'abc123',
  message: 'Database query failed',
  error: 'SQLITE_ERROR: no such table',
  timestamp: '2025-11-29T22:00:00.000Z',
  endpoint: '/api/conversations'
}
```

## Data Architecture

### Database Schema (Read-Only)

O dashboard conecta ao banco SQLite existente em `.cursor/database/cursor_hooks.db`:

**Hierarquia de Dados:**
```
conversations (1) ──→ (N) generations ──→ (N) events
                              │
                              └──→ (N) reexecute_decisions
```

**Principais Tabelas:**
- `conversations`: Informações de conversas completas
- `generations`: Gerações/respostas do agente dentro de conversas
- `events`: Eventos individuais (prompts, respostas, execuções, etc.)
- `reexecute_decisions`: Decisões de reexecução do agente
- Tabelas especializadas por tipo de evento (shell_executions, file_edits, etc.)

**Relacionamentos:**
- `generations.conversation_id` → `conversations.conversation_id`
- `events.generation_id` → `generations.generation_id`
- `reexecute_decisions.conversation_id` → `conversations.conversation_id`
- `reexecute_decisions.generation_id` → `generations.generation_id`

### Data Access Pattern

- **Singleton Connection**: Uma única conexão SQLite reutilizada
- **Prepared Statements**: Usar prepared statements para performance
- **Read-Only**: Apenas SELECT queries, nunca INSERT/UPDATE/DELETE
- **Type Safety**: Types TypeScript derivados do schema

## API Contracts

### GET /api/conversations

**Query Parameters:**
- `page` (number, default: 1): Número da página
- `limit` (number, default: 50): Itens por página
- `status` (string, optional): Filtrar por status (active, completed, aborted, error)
- `search` (string, optional): Buscar por ID ou email

**Response:**
```json
{
  "data": [
    {
      "conversation_id": "string",
      "user_email": "string",
      "status": "string",
      "start_time": "ISO 8601",
      "end_time": "ISO 8601 | null"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 50,
    "total": 100,
    "totalPages": 2
  }
}
```

### GET /api/conversations/[id]

**Response:**
```json
{
  "conversation_id": "string",
  "user_email": "string",
  "cursor_version": "string",
  "start_time": "ISO 8601",
  "end_time": "ISO 8601 | null",
  "status": "string",
  "workspaces": ["string"],
  "generations": [
    {
      "generation_id": "string",
      "model": "string",
      "status": "string",
      "start_time": "ISO 8601",
      "end_time": "ISO 8601 | null"
    }
  ]
}
```

### GET /api/generations/[id]/events

**Query Parameters:**
- `event_type` (string, optional): Filtrar por tipo de evento

**Response:**
```json
{
  "data": [
    {
      "event_id": "number",
      "event_type": "string",
      "hook_event_name": "string",
      "timestamp": "ISO 8601",
      "data_json": "object"
    }
  ]
}
```

### GET /api/decisions

**Query Parameters:**
- `page` (number, default: 1)
- `limit` (number, default: 50)
- `finish` (boolean, optional): Filtrar por finish (true/false)

**Response:**
```json
{
  "data": [
    {
      "decision_id": "number",
      "conversation_id": "string",
      "generation_id": "string",
      "finish": "boolean",
      "reason": "string | null",
      "followup_message": "string | null",
      "timestamp": "ISO 8601"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 50,
    "total": 50,
    "totalPages": 1
  }
}
```

### GET /api/health

**Response:**
```json
{
  "status": "healthy" | "unhealthy",
  "timestamp": "ISO 8601",
  "services": {
    "database": {
      "status": "UP" | "DOWN",
      "responseTime": 12.5
    }
  }
}
```

**Status Codes:**
- `200`: Sistema saudável
- `503`: Sistema não saudável (banco inacessível)

### Error Response Format

```json
{
  "error": {
    "message": "Error description",
    "code": "ERROR_CODE" // optional
  }
}
```

**Headers:**
- `Server-Timing`: Métricas de performance (`db;dur=12.5,total;dur=45.2`)
- `X-Trace-Id`: ID único para correlacionar requisições (`abc123def456`)

## Security Architecture

- **Local Access Only**: Dashboard roda em localhost, não exposto publicamente
- **No Authentication**: Ferramenta de desenvolvedor local, sem necessidade de auth
- **Read-Only Database**: Apenas SELECT queries, nunca modifica dados
- **Input Validation**: Validar e sanitizar todos os query parameters
- **SQL Injection Prevention**: Usar prepared statements sempre, nunca string interpolation

## Observability Architecture

### Server-Timing Headers

Todas as API routes devem incluir headers `Server-Timing` para métricas de performance:
- `db;dur=X`: Tempo de execução de queries SQL (milissegundos)
- `total;dur=Y`: Tempo total de processamento da requisição (milissegundos)

**Uso:** Validação de SLOs de performance via testes automatizados (Playwright, k6)

### Trace IDs

Todas as respostas de API devem incluir header `X-Trace-Id` para correlacionar requisições:
- Gerado automaticamente por middleware `withObservability`
- UUID v4 ou hash único por requisição
- Incluído em logs estruturados para rastreamento

**Uso:** Debugging, correlação de logs, validação de observabilidade em testes E2E

### Health Check Endpoint

Endpoint `/api/health` para validação de saúde do sistema:
- Verifica conectividade com banco de dados
- Retorna status UP/DOWN de serviços críticos
- Inclui tempo de resposta de cada serviço

**Uso:** Monitoramento, testes de confiabilidade, validação de NFRs

### Logging Estruturado

Todos os logs devem seguir formato JSON estruturado:
- Campos obrigatórios: `level`, `traceId`, `message`, `timestamp`
- Campos opcionais: `error`, `endpoint`, `userId`, `metadata`
- Níveis: `info`, `warn`, `error`

**Uso:** Análise de logs, debugging, validação de observabilidade

## Performance Considerations

- **Database Connection**: Singleton pattern para reutilizar conexão
- **Prepared Statements**: Cache de prepared statements para queries frequentes
- **Pagination**: Sempre paginar listas grandes (default: 50 itens)
- **Frontend Virtualization**: Usar virtualização para listas com 1000+ itens
- **Lazy Loading**: Carregar dados sob demanda (não tudo de uma vez)
- **Caching**: Considerar cache de queries frequentes (futuro)
- **Performance Monitoring**: Server-Timing headers expõem métricas para validação de SLOs

## Deployment Architecture

- **Development**: `npm run dev` - roda em localhost:3000
- **Production**: Build estático com `npm run build`, serve com `npm start`
- **Database**: Banco SQLite local, não requer servidor de banco separado
- **Deployment**: Pode ser deployado como aplicação Node.js standalone

## Development Environment

### Prerequisites

- Node.js 18.x ou superior
- npm ou yarn
- Acesso ao banco SQLite em `.cursor/database/cursor_hooks.db`

### Setup Commands

```bash
# Criar projeto Next.js
npx create-next-app@latest dashboard --typescript --tailwind --app --no-src-dir --import-alias "@/*"

# Instalar dependências adicionais
cd dashboard
npm install better-sqlite3
npm install --save-dev @types/better-sqlite3

# Desenvolvimento
npm run dev

# Build para produção
npm run build
npm start
```

## Architecture Decision Records (ADRs)

### ADR-001: Next.js App Router

**Status**: Aceito  
**Context**: Dashboard web precisa de SSR para performance e SEO (mesmo que mínimo).  
**Decision**: Usar Next.js 15 com App Router ao invés de React puro ou outros frameworks.  
**Consequences**: 
- ✅ SSR/SSG nativo
- ✅ API Routes integradas
- ✅ Otimizações automáticas
- ⚠️ Curva de aprendizado do App Router

### ADR-002: better-sqlite3 para Database Access

**Status**: Aceito  
**Context**: Dashboard precisa ler dados do SQLite de forma eficiente.  
**Decision**: Usar better-sqlite3 (síncrono) ao invés de sqlite3 (assíncrono).  
**Consequences**:
- ✅ Performance melhor para leitura
- ✅ API mais simples
- ✅ Adequado para read-only
- ⚠️ Bloqueia thread (aceitável para dashboard)

### ADR-003: REST API Pattern

**Status**: Aceito  
**Context**: Precisa de API simples para CRUD de dados relacionais.  
**Decision**: Usar REST com Next.js API Routes ao invés de GraphQL ou tRPC.  
**Consequences**:
- ✅ Simples de implementar
- ✅ Padrão familiar
- ✅ Adequado para dados relacionais
- ⚠️ Mais endpoints que GraphQL

### ADR-004: TypeScript para Type Safety

**Status**: Aceito  
**Context**: Projeto precisa de type safety para evitar erros em runtime.  
**Decision**: Usar TypeScript ao invés de JavaScript puro.  
**Consequences**:
- ✅ Type safety
- ✅ Melhor DX
- ✅ Padrão Next.js
- ⚠️ Overhead de tipos

### ADR-005: Observability para Testabilidade

**Status**: Aceito  
**Context**: Revisão de testabilidade (TEA) identificou necessidade de observabilidade para validação de NFRs.  
**Decision**: Implementar Server-Timing headers, trace IDs, health check endpoint, e logging estruturado.  
**Consequences**:
- ✅ Métricas de performance expostas (Server-Timing)
- ✅ Rastreamento de requisições (Trace IDs)
- ✅ Validação de saúde do sistema (Health check)
- ✅ Logging estruturado facilita debugging
- ✅ Suporta validação automatizada de NFRs
- ⚠️ Overhead mínimo de processamento

**Referência**: `docs/test-design-system.md` - Recommendations for Sprint 0

---

_Generated by BMAD Decision Architecture Workflow v1.0_  
_Date: 2025-11-29T19:51:47-03:00_  
_Updated: 2025-11-29T22:00:00-03:00 (TEA Recommendations)_  
_For: Luis_

