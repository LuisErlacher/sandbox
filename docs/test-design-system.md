# System-Level Test Design

**Date:** 2025-11-29T22:00:00-03:00
**Author:** Luis
**Status:** Draft

---

## Executive Summary

Este documento apresenta a revisão de testabilidade da arquitetura do projeto **sandbox** - um dashboard web Next.js para visualização de dados dos hooks do Cursor. A revisão avalia a capacidade da arquitetura de suportar testes automatizados eficazes, identifica requisitos arquiteturalmente significativos (ASRs), define estratégia de níveis de teste, e avalia abordagem de testes para requisitos não-funcionais (NFRs).

**Escopo:** Revisão completa de testabilidade em nível de sistema antes do gate de solutioning.

---

## Testability Assessment

### Controllability: PASS ✅

**Avaliação:** A arquitetura demonstra boa capacidade de controle do estado do sistema para testes.

**Pontos Fortes:**

1. **Banco de Dados SQLite (Read-Only)**
   - ✅ Acesso direto ao banco permite seeding de dados de teste via API ou diretamente
   - ✅ Padrão singleton em `lib/db.ts` facilita injeção de dependência para testes
   - ✅ Read-only garante que testes não modifiquem dados de produção
   - ✅ Estrutura de queries separadas (`lib/queries/`) permite mock/stub fácil

2. **API Routes (Next.js)**
   - ✅ API Routes permitem testes diretos via `request` object (Playwright/Cypress)
   - ✅ Padrão REST facilita setup de dados via POST antes de testes E2E
   - ✅ Estrutura modular permite mock de rotas individuais

3. **Componentes React**
   - ✅ Server Components e Client Components bem separados
   - ✅ Componentes organizados por feature facilitam testes isolados
   - ✅ TypeScript garante type safety para testes

**Recomendações:**

- Implementar factories de dados (`lib/test-utils/factories.ts`) para criação rápida de conversas, gerações e eventos
- Criar fixtures Playwright para setup comum (ex: `conversationFixture`, `generationFixture`)
- Considerar in-memory database para testes unitários de queries

**Score:** PASS - Arquitetura permite controle adequado do estado do sistema.

---

### Observability: CONCERNS ⚠️

**Avaliação:** A arquitetura tem observabilidade limitada para validação de NFRs e debugging de testes.

**Pontos Fortes:**

1. **Logging Básico**
   - ✅ Console.error em API routes para erros
   - ✅ Estrutura de erro padronizada (`{ error: { message: string } }`)

**Gaps Identificados:**

1. **Métricas de Performance**
   - ⚠️ Não há Server-Timing headers para medir latência de queries SQL
   - ⚠️ Não há métricas de tempo de resposta por endpoint
   - ⚠️ Não há rastreamento de queries lentas

2. **Rastreamento de Erros**
   - ⚠️ Não há integração com serviços de monitoramento (Sentry, Datadog)
   - ⚠️ Não há trace IDs para correlacionar requisições
   - ⚠️ Logs não são estruturados (JSON)

3. **Validação de NFRs**
   - ⚠️ Não há endpoints de health check (`/api/health`)
   - ⚠️ Não há métricas expostas para validação de performance
   - ⚠️ Não há logs de auditoria para validação de segurança

**Recomendações:**

- Adicionar Server-Timing headers em API routes para medir latência de queries
- Implementar endpoint `/api/health` com status de banco de dados
- Adicionar trace IDs (`x-trace-id`) em headers de resposta
- Considerar logging estruturado (JSON) para facilitar análise
- Para produção futura: integrar com serviço de monitoramento (Sentry para erros, Datadog para métricas)

**Score:** CONCERNS - Observabilidade básica presente, mas insuficiente para validação completa de NFRs.

---

### Reliability: PASS ✅

**Avaliação:** A arquitetura suporta testes isolados e reproduzíveis.

**Pontos Fortes:**

1. **Isolamento de Testes**
   - ✅ Banco read-only garante que testes não interferem entre si
   - ✅ Queries preparadas (`prepared statements`) previnem race conditions
   - ✅ Estrutura de componentes permite testes isolados

2. **Reprodutibilidade**
   - ✅ Queries SQL são determinísticas (sem dependências externas variáveis)
   - ✅ Dados do banco são estáveis (não mudam durante execução de testes)
   - ✅ TypeScript garante type safety reduzindo erros de runtime

3. **Acoplamento**
   - ✅ Separação clara entre camadas (API routes → queries → database)
   - ✅ Componentes React são desacoplados (props-based)
   - ✅ Queries são funções puras (fáceis de testar isoladamente)

**Recomendações:**

- Garantir que fixtures de teste sempre limpem dados criados (auto-cleanup)
- Usar faker para dados únicos em testes paralelos
- Implementar testes de integração com banco de teste isolado

**Score:** PASS - Arquitetura suporta testes isolados e reproduzíveis.

---

## Architecturally Significant Requirements (ASRs)

### ASR-001: Performance - Tempo de Resposta de Consultas SQL

**Descrição:** Sistema deve responder consultas SQL em < 1 segundo para até 10.000 registros (PRD: Performance - Tempo de resposta de consultas).

**Impacto na Arquitetura:**
- Decisão de usar SQLite (read-only) é adequada para volumes esperados
- Queries preparadas (`prepared statements`) otimizam performance
- Paginação implementada reduz carga de dados transferidos

**Desafios de Testabilidade:**
- ⚠️ Não há métricas de performance expostas (Server-Timing headers ausentes)
- ⚠️ Não há testes de carga (k6) definidos para validar SLO
- ⚠️ Não há baseline de performance estabelecido

**Score de Risco:**
- **Probabilidade:** 2 (Possível - queries podem degradar com crescimento de dados)
- **Impacto:** 2 (Degradado - afeta experiência do usuário mas não bloqueia uso)
- **Score Total:** 4 (Médio)

**Mitigação:**
- Implementar Server-Timing headers em API routes
- Criar testes de performance com k6 para validar < 1s para 10K registros
- Estabelecer baseline de performance e monitorar degradação

**Owner:** Tech Lead
**Timeline:** Sprint 0 (antes de implementação)

---

### ASR-002: Performance - Renderização de Listas Grandes

**Descrição:** Sistema deve renderizar listas com 1000+ itens usando virtualização (PRD: Performance - Renderização de listas grandes).

**Impacto na Arquitetura:**
- Frontend precisa de biblioteca de virtualização (react-window ou react-virtual)
- API deve suportar paginação eficiente
- Componentes de lista devem ser otimizados para performance

**Desafios de Testabilidade:**
- ⚠️ Testes E2E podem ser lentos para validar virtualização
- ⚠️ Não há testes de performance visual (Lighthouse) definidos
- ⚠️ Validação de virtualização requer dados reais (1000+ itens)

**Score de Risco:**
- **Probabilidade:** 2 (Possível - virtualização pode não funcionar corretamente)
- **Impacto:** 2 (Degradado - UX degradada mas funcionalidade mantida)
- **Score Total:** 4 (Médio)

**Mitigação:**
- Criar testes de componente para validação de virtualização
- Implementar testes E2E com dados reais (1000+ conversas)
- Validar Core Web Vitals com Lighthouse em CI

**Owner:** Frontend Lead
**Timeline:** Epic 2 (Visualização de Conversas)

---

### ASR-003: Segurança - Validação de Entrada SQL

**Descrição:** Sistema deve validar e sanitizar todas as consultas SQL para prevenir SQL injection (PRD: Security - Validação de entrada).

**Impacto na Arquitetura:**
- Uso de prepared statements é obrigatório (não string interpolation)
- Validação de query params deve ser implementada em todas as API routes
- Erros SQL não devem expor estrutura do banco

**Desafios de Testabilidade:**
- ✅ Prepared statements previnem SQL injection (arquitetura correta)
- ⚠️ Não há testes de segurança definidos (OWASP Top 10)
- ⚠️ Não há validação de sanitização de inputs

**Score de Risco:**
- **Probabilidade:** 1 (Improvável - prepared statements protegem)
- **Impacto:** 3 (Crítico - SQL injection pode expor dados)
- **Score Total:** 3 (Médio-Baixo)

**Mitigação:**
- Implementar testes de segurança validando que SQL injection é bloqueado
- Adicionar testes OWASP Top 10 (SQL injection, XSS)
- Validar que erros SQL não expõem estrutura do banco

**Owner:** Security Lead / Tech Lead
**Timeline:** Epic 1 (Foundation & Setup)

---

### ASR-004: Confiabilidade - Tratamento de Banco Não Encontrado

**Descrição:** Sistema deve detectar quando banco não existe e exibir mensagem apropriada (PRD: Error Handling - FR40).

**Impacto na Arquitetura:**
- Validação de existência do banco deve ocorrer na inicialização
- Componente de erro deve ser criado para exibir mensagem clara
- Sistema deve degradar graciosamente (não crashar)

**Desafios de Testabilidade:**
- ✅ Cenário é testável (simular ausência do arquivo)
- ⚠️ Testes E2E precisam simular banco ausente
- ⚠️ Validação de mensagens de erro precisa ser implementada

**Score de Risco:**
- **Probabilidade:** 2 (Possível - banco pode não existir em novos ambientes)
- **Impacto:** 1 (Menor - mensagem de erro, não bloqueia desenvolvimento)
- **Score Total:** 2 (Baixo)

**Mitigação:**
- Implementar testes E2E validando mensagem quando banco não existe
- Validar que sistema não crasha quando banco ausente
- Testar recuperação quando banco é criado após inicialização

**Owner:** Dev Team
**Timeline:** Epic 1, Story 1.3

---

## Test Levels Strategy

### Distribuição Recomendada: 40% Unit / 30% Integration / 30% E2E

**Justificativa:**

Este é um projeto **web-first** com foco em visualização de dados. A arquitetura Next.js com API Routes e componentes React sugere distribuição equilibrada:

- **40% Unit Tests:** Lógica de formatação (`lib/utils/format.ts`), queries SQL isoladas, componentes React isolados
- **30% Integration Tests:** API routes + database (validação de contratos), queries + database (validação de lógica de negócio)
- **30% E2E Tests:** Jornadas críticas do usuário (listar conversas, ver detalhes, navegar entre entidades)

**Comparação com Outros Tipos de Projeto:**

- **API-heavy (70/20/10):** Não aplicável - projeto tem UI significativa
- **UI-heavy (40/30/30):** ✅ **Aplicável** - projeto é dashboard com foco em visualização
- **Mobile (50/30/20):** Não aplicável - projeto é web

### Test Levels por Componente

| Componente | Test Level | Justificativa |
|------------|------------|---------------|
| `lib/utils/format.ts` | Unit | Funções puras, sem dependências |
| `lib/queries/*.ts` | Integration | Validação de queries SQL + database |
| `app/api/**/route.ts` | Integration | Validação de contratos API + database |
| Componentes React isolados | Component | Validação de props, eventos, estados |
| Jornadas críticas (lista → detalhes) | E2E | Validação de experiência do usuário |
| Navegação entre entidades | E2E | Validação de fluxos completos |

### Ambientes de Teste

**Local (Desenvolvimento):**
- Banco SQLite local (`.cursor/database/cursor_hooks.db`)
- Next.js dev server (`npm run dev`)
- Playwright/Cypress rodando localmente

**Staging (Opcional - Futuro):**
- Banco SQLite com dados de teste sintéticos
- Deploy de staging para validação E2E em ambiente próximo à produção

**Ephemeral (CI/CD):**
- Banco SQLite em memória para testes de integração
- Build estático do Next.js para testes E2E
- Dados de teste gerados via factories

---

## NFR Testing Approach

### Security (Segurança)

**Abordagem:**
- **Playwright E2E** para validação de autenticação/autorização (se implementada no futuro)
- **Testes de segurança** para validação de SQL injection e sanitização de inputs
- **OWASP Top 10** validação básica (SQL injection, XSS)

**Ferramentas:**
- Playwright para testes E2E de segurança
- Testes manuais de SQL injection (validar que prepared statements protegem)
- Validação de que erros não expõem estrutura do banco

**Cenários Críticos:**
1. SQL injection em query params (`?search='; DROP TABLE`)
2. Validação de que erros SQL não expõem schema
3. Validação de sanitização de inputs em todas as API routes

**Status:** ⚠️ CONCERNS - Testes de segurança não definidos ainda

---

### Performance (Performance)

**Abordagem:**
- **k6** para testes de carga e validação de SLOs
- **Lighthouse** (via Playwright) para Core Web Vitals
- **Server-Timing headers** para métricas de latência

**Ferramentas:**
- k6 para load testing (validar < 1s para 10K registros)
- Lighthouse para Core Web Vitals (LCP, FID, CLS)
- Playwright para validação de Server-Timing headers

**SLOs a Validar:**
- Tempo de resposta de consultas: < 1 segundo (p95) para até 10K registros
- Carregamento inicial: < 2 segundos
- Navegação entre páginas: < 500ms

**Cenários Críticos:**
1. Load test de `/api/conversations` com 10K registros
2. Load test de `/api/conversations/[id]/generations` com múltiplas gerações
3. Validação de Core Web Vitals em páginas principais

**Status:** ⚠️ CONCERNS - Testes de performance não implementados, métricas não expostas

---

### Reliability (Confiabilidade)

**Abordagem:**
- **Playwright E2E** para validação de tratamento de erros
- **API Tests** para validação de health checks e retries
- **Testes de degradação graciosa** quando banco não disponível

**Ferramentas:**
- Playwright para testes E2E de tratamento de erros
- API tests para validação de health checks
- Testes de simulação de falhas (banco ausente, queries falhando)

**Cenários Críticos:**
1. Sistema exibe mensagem clara quando banco não encontrado
2. Sistema não crasha quando queries SQL falham
3. Health check endpoint retorna status correto

**Status:** ⚠️ CONCERNS - Health check endpoint não implementado, testes de erro não definidos

---

### Maintainability (Manutenibilidade)

**Abordagem:**
- **CI Tools** (GitHub Actions) para cobertura de código e qualidade
- **Playwright** para validação de observabilidade (telemetria, logs)
- **Testes de qualidade de código** (ESLint, TypeScript)

**Ferramentas:**
- GitHub Actions para cobertura de código (target: ≥80%)
- jscpd para detecção de duplicação (target: <5%)
- npm audit para vulnerabilidades (target: 0 critical/high)
- Playwright para validação de telemetria (trace IDs, Server-Timing)

**Métricas:**
- Cobertura de código: ≥80% (CI)
- Duplicação de código: <5% (CI)
- Vulnerabilidades: 0 critical/high (CI)
- Observabilidade: Trace IDs presentes em headers (E2E)

**Status:** ⚠️ CONCERNS - CI pipeline não configurado, métricas não estabelecidas

---

## Test Environment Requirements

### Infraestrutura Necessária

**Desenvolvimento Local:**
- Node.js 18.x+
- SQLite (banco existente em `.cursor/database/cursor_hooks.db`)
- Next.js dev server
- Playwright/Cypress instalado

**CI/CD (GitHub Actions):**
- Ubuntu latest
- Node.js 18.x+
- SQLite (banco de teste em memória ou arquivo temporário)
- Playwright com browsers (Chromium, Firefox, WebKit)
- k6 para testes de performance

**Dados de Teste:**
- Factories para criação de conversas, gerações, eventos
- Fixtures para setup comum (ex: conversa com 10 gerações)
- Dados sintéticos para testes de performance (10K+ registros)

### Dependências Externas

**Nenhuma** - Projeto é self-contained:
- ✅ Banco SQLite local (sem servidor de banco)
- ✅ Next.js standalone (sem serviços externos)
- ✅ Sem autenticação (ferramenta local)

**Vantagem:** Ambiente de teste simples, sem dependências externas complexas.

---

## Testability Concerns

### ⚠️ CONCERNS Identificados

1. **Observabilidade Limitada**
   - **Problema:** Não há métricas de performance expostas (Server-Timing headers ausentes)
   - **Impacto:** Impossível validar SLOs de performance via testes automatizados
   - **Recomendação:** Implementar Server-Timing headers em todas as API routes
   - **Prioridade:** Alta (bloqueia validação de NFRs de performance)

2. **Health Check Ausente**
   - **Problema:** Não há endpoint `/api/health` para validação de saúde do sistema
   - **Impacto:** Impossível validar confiabilidade via testes automatizados
   - **Recomendação:** Implementar endpoint `/api/health` retornando status do banco
   - **Prioridade:** Média (bloqueia validação de NFRs de confiabilidade)

3. **Testes de Segurança Não Definidos**
   - **Problema:** Não há testes de segurança (SQL injection, OWASP Top 10)
   - **Impacto:** Risco de vulnerabilidades não detectadas
   - **Recomendação:** Implementar testes de segurança no Epic 1
   - **Prioridade:** Alta (segurança é crítica)

4. **CI Pipeline Não Configurado**
   - **Problema:** Não há CI pipeline para validação de qualidade (cobertura, duplicação)
   - **Impacto:** Impossível validar manutenibilidade via testes automatizados
   - **Recomendação:** Configurar GitHub Actions com jobs de cobertura, duplicação, audit
   - **Prioridade:** Média (bloqueia validação de NFRs de manutenibilidade)

### ✅ PASS - Sem Blockers Críticos

Nenhum blocker crítico identificado. Arquitetura é testável, mas requer melhorias em observabilidade e testes de segurança.

---

## Recommendations for Sprint 0

### Ações Imediatas (Antes de Implementação)

1. **Implementar Server-Timing Headers**
   - Adicionar middleware em API routes para medir latência de queries
   - Expor métricas de tempo de resposta por endpoint
   - **Workflow:** `*framework` ou `*ci`

2. **Criar Endpoint `/api/health`**
   - Retornar status do banco de dados (UP/DOWN)
   - Validar conectividade com SQLite
   - **Workflow:** `*framework` ou implementação manual

3. **Configurar CI Pipeline**
   - GitHub Actions com jobs de cobertura (target: ≥80%)
   - Job de detecção de duplicação (target: <5%)
   - Job de npm audit (target: 0 critical/high)
   - **Workflow:** `*ci`

4. **Implementar Testes de Segurança**
   - Testes de SQL injection (validar que prepared statements protegem)
   - Validação de que erros não expõem estrutura do banco
   - **Workflow:** `*test-design` (epic-level) ou `*automate`

5. **Criar Factories de Dados**
   - `lib/test-utils/factories.ts` com funções para criar conversas, gerações, eventos
   - Usar faker para dados únicos
   - **Workflow:** `*framework` ou `*atdd`

### Workflows Recomendados

- **`*framework`**: Inicializar estrutura de testes (Playwright/Cypress), factories, fixtures
- **`*ci`**: Configurar CI pipeline com jobs de qualidade
- **`*test-design`** (epic-level): Criar testes de segurança e performance por épico
- **`*atdd`**: Gerar testes E2E para P0 scenarios antes de implementação

---

## Summary

**Testability Assessment:**
- ✅ **Controllability:** PASS - Arquitetura permite controle adequado do estado
- ⚠️ **Observability:** CONCERNS - Métricas limitadas, health check ausente
- ✅ **Reliability:** PASS - Arquitetura suporta testes isolados e reproduzíveis

**ASRs Identificados:** 4 requisitos arquiteturalmente significativos
- ASR-001: Performance de consultas SQL (Score: 4 - Médio)
- ASR-002: Renderização de listas grandes (Score: 4 - Médio)
- ASR-003: Segurança de SQL injection (Score: 3 - Médio-Baixo)
- ASR-004: Tratamento de banco não encontrado (Score: 2 - Baixo)

**Test Levels Strategy:** 40% Unit / 30% Integration / 30% E2E (distribuição adequada para projeto web-first)

**NFR Testing Approach:**
- ⚠️ Security: CONCERNS - Testes não definidos
- ⚠️ Performance: CONCERNS - Métricas não expostas, testes não implementados
- ⚠️ Reliability: CONCERNS - Health check ausente
- ⚠️ Maintainability: CONCERNS - CI pipeline não configurado

**Testability Concerns:** 4 concerns identificados (nenhum blocker crítico)
- Observabilidade limitada (alta prioridade)
- Health check ausente (média prioridade)
- Testes de segurança não definidos (alta prioridade)
- CI pipeline não configurado (média prioridade)

**Gate Decision:** ⚠️ **CONCERNS** - Arquitetura é testável, mas requer melhorias em observabilidade e testes de segurança antes do gate de solutioning.

**Recomendações:** Implementar Server-Timing headers, health check endpoint, testes de segurança, e CI pipeline no Sprint 0 antes de iniciar implementação.

---

**Generated by**: BMad TEA Agent - Test Architect Module
**Workflow**: `.bmad/bmm/testarch/test-design`
**Version**: 4.0 (BMad v6)
**Mode**: System-Level (Phase 3 - Testability Review)

