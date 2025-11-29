# sandbox - Product Requirements Document

**Author:** Luis
**Date:** 2025-11-29T19:49:25-03:00
**Version:** 1.0

---

## Executive Summary

Este produto é um dashboard web interativo desenvolvido em Next.js para visualizar e analisar dados coletados pelos hooks do Cursor. O sistema permite que desenvolvedores e equipes monitorem conversas com o agente de IA, analisem decisões de reexecução, visualizem mensagens e eventos, e obtenham insights sobre o uso e comportamento do Cursor Agent.

O dashboard conecta-se diretamente ao banco de dados SQLite (`cursor_hooks.db`) que armazena eventos capturados pelos hooks, proporcionando uma interface visual rica para explorar dados históricos e em tempo real.

### What Makes This Special

O diferencial deste produto está na capacidade de transformar dados técnicos brutos dos hooks do Cursor em visualizações acionáveis e insights compreensíveis. Ao invés de precisar consultar diretamente o banco SQLite ou analisar logs JSON, desenvolvedores podem:

- **Visualizar conversas completas** com contexto temporal
- **Analisar decisões de reexecução** do agente para entender quando e por que tarefas são concluídas ou continuadas
- **Monitorar métricas de uso** como frequência de prompts, tipos de eventos mais comuns, e padrões de interação
- **Explorar dados relacionais** entre conversas, gerações e eventos de forma intuitiva

---

## Project Classification

**Technical Type:** web_app
**Domain:** general
**Complexity:** low

Este é um aplicativo web (SPA) desenvolvido com Next.js que funciona como ferramenta de análise e visualização de dados. O projeto é de baixa complexidade pois utiliza tecnologias bem estabelecidas (Next.js, React, SQLite) e não requer integrações complexas ou compliance regulatório especial.

O dashboard é uma ferramenta interna/desenvolvedor que não precisa atender a requisitos de alta escala, segurança crítica ou regulamentações específicas.

---

## Success Criteria

O sucesso deste produto será medido pela capacidade dos desenvolvedores de:

1. **Acessar rapidamente informações relevantes** - Encontrar conversas específicas, gerações ou decisões em menos de 3 cliques
2. **Compreender padrões de uso** - Identificar visualmente quais tipos de eventos são mais frequentes e quando ocorrem
3. **Analisar decisões do agente** - Entender claramente quando e por que o agente decide continuar ou finalizar uma tarefa
4. **Navegar dados relacionais** - Explorar facilmente a conexão entre conversas, gerações e eventos

Sucesso significa que desenvolvedores param de consultar o banco SQLite diretamente e passam a usar o dashboard como ferramenta principal de análise.

---

## Product Scope

### MVP - Minimum Viable Product

O MVP deve fornecer visualização básica e navegação dos dados principais:

1. **Lista de Conversas**
   - Visualizar todas as conversas com informações básicas (ID, usuário, status, datas)
   - Filtrar por status (active, completed, aborted, error)
   - Ordenar por data de início
   - Buscar por ID ou email do usuário

2. **Detalhes de Conversa**
   - Visualizar informações completas de uma conversa selecionada
   - Listar todas as gerações (generations) dessa conversa
   - Mostrar eventos principais (prompts, respostas do agente, pensamentos)
   - Timeline visual dos eventos

3. **Visualização de Decisões de Reexecução**
   - Listar todas as decisões de reexecução (reexecute_decisions)
   - Filtrar por finish (true/false)
   - Mostrar resumo da decisão (reason, followup_message)
   - Exibir prompt e resposta do agente relacionados

4. **Navegação Básica**
   - Links entre conversas e gerações
   - Links entre gerações e eventos
   - Links entre decisões e conversas/gerações relacionadas

### Growth Features (Post-MVP)

1. **Métricas e Estatísticas**
   - Dashboard com gráficos de uso (eventos por tipo, conversas por dia, etc.)
   - Estatísticas de decisões de reexecução (taxa de conclusão, razões mais comuns)
   - Métricas de performance (duração média de gerações, tempo de resposta)

2. **Filtros Avançados**
   - Filtrar por período de tempo
   - Filtrar por modelo de IA usado
   - Filtrar por tipo de evento
   - Filtrar por workspace

3. **Visualizações Avançadas**
   - Gráficos de linha temporal
   - Gráficos de barras por categoria
   - Heatmaps de atividade
   - Árvore de relacionamentos entre entidades

4. **Exportação de Dados**
   - Exportar conversas selecionadas em JSON
   - Exportar relatórios em PDF
   - Exportar dados filtrados em CSV

5. **Busca Avançada**
   - Busca full-text em prompts e respostas
   - Busca por conteúdo de mensagens
   - Busca por padrões em comandos shell

### Vision (Future)

1. **Análise Preditiva**
   - Identificar padrões que levam a tarefas não concluídas
   - Sugerir melhorias em prompts baseado em histórico
   - Alertas proativos sobre problemas comuns

2. **Integração com Cursor**
   - Plugin/extensão do Cursor que mostra dados diretamente no IDE
   - Notificações em tempo real sobre eventos importantes

3. **Colaboração**
   - Compartilhamento de conversas entre membros da equipe
   - Comentários e anotações em conversas
   - Tags e categorização personalizada

---

## Web App Specific Requirements

### Browser Support

- Chrome/Edge (últimas 2 versões)
- Firefox (últimas 2 versões)
- Safari (últimas 2 versões)

### Responsive Design

- Desktop-first approach
- Layout adaptável para tablets (opcional)
- Mobile não é prioridade inicial (ferramenta de desenvolvedor)

### Performance Targets

- Carregamento inicial < 2 segundos
- Navegação entre páginas < 500ms
- Renderização de listas grandes (1000+ itens) com virtualização

### SEO Strategy

- SEO não é necessário (ferramenta interna)
- Meta tags básicas para identificação

### Accessibility Level

- Nível básico de acessibilidade (WCAG AA mínimo)
- Navegação por teclado funcional
- Contraste adequado de cores
- Labels descritivos em elementos interativos

---

## Functional Requirements

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

## Non-Functional Requirements

### Performance

- **Tempo de carregamento inicial:** < 2 segundos
- **Tempo de navegação entre páginas:** < 500ms
- **Tempo de resposta de consultas:** < 1 segundo para até 10.000 registros
- **Renderização de listas grandes:** Usar virtualização para listas com 1000+ itens
- **Lazy loading:** Carregar dados sob demanda quando possível
- **Métricas de performance:** API routes devem expor Server-Timing headers para validação de SLOs
- **Observabilidade:** Sistema deve expor métricas de latência de queries SQL via Server-Timing headers

### Security

- **Acesso local:** Apenas acessível localmente (localhost)
- **Sem autenticação:** Não requer autenticação (ferramenta de desenvolvedor local)
- **Validação de entrada:** Validar e sanitizar todas as consultas SQL para prevenir SQL injection
- **Leitura apenas:** Dashboard não modifica o banco de dados (apenas leitura)
- **Testes de segurança:** Implementar testes automatizados para validação de SQL injection e OWASP Top 10
- **Logs de segurança:** Erros SQL não devem expor estrutura do banco de dados

### Scalability

- **Volume de dados:** Suportar até 100.000 conversas e 1.000.000 de eventos
- **Paginação:** Implementar paginação para listas grandes
- **Cache:** Cachear consultas frequentes quando apropriado

### Accessibility

- **Navegação por teclado:** Todas as funcionalidades acessíveis via teclado
- **Contraste:** Contraste mínimo WCAG AA (4.5:1 para texto normal)
- **Labels:** Todos os elementos interativos têm labels descritivos
- **Foco visível:** Indicadores claros de foco em elementos interativos

### Integration

- **SQLite:** Conectar ao banco SQLite usando biblioteca apropriada (better-sqlite3 ou similar)
- **Next.js API Routes:** Usar API routes do Next.js para consultas ao banco
- **Formato de dados:** Retornar dados em JSON para consumo pelo frontend

### Observability

- **Health check:** Endpoint `/api/health` deve retornar status do sistema e conectividade com banco
- **Trace IDs:** Todas as respostas de API devem incluir header `X-Trace-Id` para correlacionar requisições
- **Server-Timing headers:** API routes devem expor métricas de performance via headers Server-Timing
- **Logging estruturado:** Logs devem seguir formato JSON estruturado com campos: level, traceId, message, timestamp
- **Métricas de performance:** Sistema deve expor tempo de execução de queries SQL e tempo total de requisição

### Reliability

- **Health check endpoint:** Sistema deve expor endpoint `/api/health` para validação de saúde
- **Tratamento de erros:** Sistema deve degradar graciosamente quando banco não disponível
- **Validação de conectividade:** Health check deve validar conectividade com banco de dados

---

_This PRD captures the essence of sandbox - Um dashboard web para visualizar e analisar dados dos hooks do Cursor, transformando dados técnicos em insights acionáveis para desenvolvedores._

_Created through collaborative discovery between Luis and AI facilitator._

