# Documentação do Banco de Dados SQLite - Hooks do Cursor

Este documento descreve o schema do banco de dados SQLite usado para armazenar eventos dos hooks do Cursor, organizados por conversa (`conversation_id`) e geração (`generation_id`).

## Visão Geral

O banco de dados armazena todos os eventos capturados pelos hooks do Cursor, permitindo recuperação contextual completa de cada geração dentro de uma conversa específica. Os dados são organizados hierarquicamente:

- **Conversations**: Conversas completas do usuário
- **Generations**: Gerações/respostas do agente dentro de uma conversa
- **Events**: Eventos individuais (prompts, respostas, execuções, edições, etc.)
- **Tabelas Especializadas**: Dados específicos de cada tipo de evento

## Estrutura do Banco de Dados

### Tabela: `conversations`

Armazena informações sobre cada conversa completa.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `conversation_id` | TEXT (PK) | ID único da conversa |
| `user_email` | TEXT | Email do usuário |
| `cursor_version` | TEXT | Versão do Cursor usada |
| `start_time` | TEXT | Timestamp ISO 8601 do início da conversa |
| `end_time` | TEXT | Timestamp ISO 8601 do fim da conversa (NULL se ativa) |
| `status` | TEXT | Status: 'active', 'completed', 'aborted', 'error' |
| `created_at` | TEXT | Timestamp de criação do registro |

**Índices:**
- `idx_conversations_user`: Por `user_email`
- `idx_conversations_time`: Por `start_time`
- `idx_conversations_status`: Por `status`

### Tabela: `conversation_workspaces`

Relaciona conversas com seus workspaces (um workspace pode ter múltiplas conversas).

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `conversation_id` | TEXT (PK, FK) | ID da conversa |
| `workspace_root` | TEXT (PK) | Caminho raiz do workspace |

**Relacionamentos:**
- `conversation_id` → `conversations.conversation_id` (ON DELETE CASCADE)

**Índices:**
- `idx_conv_workspaces_root`: Por `workspace_root`

### Tabela: `generations`

Armazena informações sobre cada geração/resposta do agente dentro de uma conversa.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `generation_id` | TEXT (PK) | ID único da geração |
| `conversation_id` | TEXT (FK) | ID da conversa pai |
| `model` | TEXT | Modelo usado (ex: "composer-1") |
| `start_time` | TEXT | Timestamp ISO 8601 do início da geração |
| `end_time` | TEXT | Timestamp ISO 8601 do fim da geração (NULL se ativa) |
| `status` | TEXT | Status: 'active', 'completed', 'aborted', 'error' |

**Relacionamentos:**
- `conversation_id` → `conversations.conversation_id` (ON DELETE CASCADE)

**Índices:**
- `idx_generations_conversation`: Por `conversation_id`
- `idx_generations_time`: Por `start_time`
- `idx_generations_model`: Por `model`

### Tabela: `events`

Tabela principal que armazena todos os eventos, com referências a conversation e generation.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `event_id` | INTEGER (PK, AUTO) | ID único do evento |
| `conversation_id` | TEXT (FK) | ID da conversa |
| `generation_id` | TEXT (FK) | ID da geração |
| `event_type` | TEXT | Tipo do evento (igual a `hook_event_name`) |
| `hook_event_name` | TEXT | Nome do hook que disparou o evento |
| `model` | TEXT | Modelo usado nesta geração |
| `cursor_version` | TEXT | Versão do Cursor |
| `timestamp` | TEXT | Timestamp ISO 8601 do evento |
| `data_json` | TEXT | JSON completo dos dados específicos do evento |

**Relacionamentos:**
- `conversation_id` → `conversations.conversation_id` (ON DELETE CASCADE)
- `generation_id` → `generations.generation_id` (ON DELETE CASCADE)

**Índices:**
- `idx_events_conversation`: Por `conversation_id`
- `idx_events_generation`: Por `generation_id`
- `idx_events_type`: Por `event_type`
- `idx_events_hook_name`: Por `hook_event_name`
- `idx_events_timestamp`: Por `timestamp`
- `idx_events_model`: Por `model`

### Tabela: `shell_executions`

Dados específicos de comandos shell executados (eventos `afterShellExecution`).

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `event_id` | INTEGER (PK, FK) | ID do evento |
| `command` | TEXT | Comando executado |
| `cwd` | TEXT | Diretório de trabalho (pode ser NULL) |
| `output` | TEXT | Saída do comando |
| `duration` | INTEGER | Duração em milissegundos (pode ser NULL) |

**Relacionamentos:**
- `event_id` → `events.event_id` (ON DELETE CASCADE)

**Índices:**
- `idx_shell_executions_command`: Por `command`
- `idx_shell_executions_cwd`: Por `cwd`

### Tabela: `file_edits`

Dados específicos de edições de arquivos (eventos `afterFileEdit`).

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `event_id` | INTEGER (PK, FK) | ID do evento |
| `file_path` | TEXT | Caminho do arquivo editado |
| `edits_json` | TEXT | JSON array de edições `[{old_string, new_string, ...}]` |

**Relacionamentos:**
- `event_id` → `events.event_id` (ON DELETE CASCADE)

**Índices:**
- `idx_file_edits_path`: Por `file_path`

### Tabela: `file_edit_details`

Detalhes individuais de cada edição (normalização do array `edits`).

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `edit_id` | INTEGER (PK, AUTO) | ID único da edição |
| `event_id` | INTEGER (FK) | ID do evento |
| `old_string` | TEXT | String antiga (antes da edição) |
| `new_string` | TEXT | String nova (após a edição) |
| `edit_order` | INTEGER | Ordem da edição no array original |

**Relacionamentos:**
- `event_id` → `file_edits.event_id` (ON DELETE CASCADE)

**Índices:**
- `idx_edit_details_event`: Por `event_id`

### Tabela: `mcp_executions`

Dados específicos de execuções MCP (eventos `afterMCPExecution`).

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `event_id` | INTEGER (PK, FK) | ID do evento |
| `tool_name` | TEXT | Nome da ferramenta MCP executada |
| `tool_input` | TEXT | JSON string com entrada da ferramenta |
| `result_json` | TEXT | JSON string com resultado da execução |
| `duration` | INTEGER | Duração em milissegundos (pode ser NULL) |

**Relacionamentos:**
- `event_id` → `events.event_id` (ON DELETE CASCADE)

**Índices:**
- `idx_mcp_executions_tool`: Por `tool_name`

### Tabela: `agent_responses`

Dados específicos de respostas do agente (eventos `afterAgentResponse`).

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `event_id` | INTEGER (PK, FK) | ID do evento |
| `text` | TEXT | Texto completo da resposta do agente |

**Relacionamentos:**
- `event_id` → `events.event_id` (ON DELETE CASCADE)

**Índices:**
- `idx_agent_responses_text`: Por `text` (full-text search)

### Tabela: `agent_thoughts`

Dados específicos de pensamentos/raciocínio do agente (eventos `afterAgentThought`).

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `event_id` | INTEGER (PK, FK) | ID do evento |
| `text` | TEXT | Texto do raciocínio (pode estar vazio) |
| `duration_ms` | INTEGER | Duração do bloco de raciocínio em milissegundos |

**Relacionamentos:**
- `event_id` → `events.event_id` (ON DELETE CASCADE)

**Índices:**
- `idx_agent_thoughts_duration`: Por `duration_ms`

### Tabela: `prompts`

Dados específicos de prompts do usuário (eventos `beforeSubmitPrompt`).

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `event_id` | INTEGER (PK, FK) | ID do evento |
| `prompt_text` | TEXT | Texto do prompt do usuário |
| `attachments_json` | TEXT | JSON array de attachments `[{type, file_path, ...}]` |

**Relacionamentos:**
- `event_id` → `events.event_id` (ON DELETE CASCADE)

**Índices:**
- `idx_prompts_text`: Por `prompt_text` (full-text search)

### Tabela: `generation_stops`

Dados específicos de finalização de geração (eventos `stop`).

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `event_id` | INTEGER (PK, FK) | ID do evento |
| `status` | TEXT | Status final: 'completed', 'aborted', 'error' |
| `loop_count` | INTEGER | Número de loops executados |

**Relacionamentos:**
- `event_id` → `events.event_id` (ON DELETE CASCADE)

**Índices:**
- `idx_generation_stops_status`: Por `status`

## Relacionamentos entre Tabelas

```
conversations (1) ──< (N) conversation_workspaces
conversations (1) ──< (N) generations
conversations (1) ──< (N) events
generations (1) ──< (N) events

events (1) ──< (1) shell_executions (quando hook_event_name = 'afterShellExecution')
events (1) ──< (1) file_edits (quando hook_event_name = 'afterFileEdit')
events (1) ──< (N) file_edit_details (via file_edits)
events (1) ──< (1) mcp_executions (quando hook_event_name = 'afterMCPExecution')
events (1) ──< (1) agent_responses (quando hook_event_name = 'afterAgentResponse')
events (1) ──< (1) agent_thoughts (quando hook_event_name = 'afterAgentThought')
events (1) ──< (1) prompts (quando hook_event_name = 'beforeSubmitPrompt')
events (1) ──< (1) generation_stops (quando hook_event_name = 'stop')
```

## Estrutura dos Dados JSON

### Metadados Globais (presentes em TODOS os eventos)

Todos os eventos recebidos pelos hooks contêm os seguintes metadados globais:

```json
{
  "conversation_id": "6f464371-9fef-4d9f-a3b7-746cfd3d6151",
  "generation_id": "d942c794-622d-466d-b099-24ab6fe8a77b",
  "model": "composer-1",
  "workspace_roots": ["/home/luis/projetos/sandbox"],
  "user_email": "cursor1@unlkd.com.br",
  "cursor_version": "2.1.39",
  "hook_event_name": "afterShellExecution"
}
```

### Dados Específicos por Tipo de Evento

#### `afterShellExecution`
```json
{
  "command": "ls -la",
  "cwd": "/home/luis/projetos/sandbox",
  "output": "total 123\n...",
  "duration": 100
}
```

#### `afterFileEdit`
```json
{
  "file_path": "/home/luis/projetos/sandbox/file.txt",
  "edits": [
    {
      "old_string": "texto antigo",
      "new_string": "texto novo"
    }
  ]
}
```

#### `afterAgentResponse`
```json
{
  "text": "Resposta completa do agente..."
}
```

#### `afterAgentThought`
```json
{
  "text": "Texto de raciocínio...",  // Pode estar vazio
  "duration_ms": 426
}
```

#### `beforeSubmitPrompt`
```json
{
  "prompt": "Texto do prompt do usuário",
  "attachments": [
    {
      "type": "file",
      "file_path": "/path/to/file.txt"
    }
  ]
}
```

#### `stop`
```json
{
  "status": "completed",  // ou "aborted", "error"
  "loop_count": 0
}
```

#### `afterMCPExecution`
```json
{
  "tool_name": "read_file",
  "tool_input": {"path": "/path/to/file"},
  "result_json": {"content": "..."},
  "duration": 50
}
```

## Exemplos de Consultas

### 1. Recuperar contexto completo de uma generation

```sql
SELECT 
    e.event_id,
    e.event_type,
    e.hook_event_name,
    e.timestamp,
    e.model,
    c.user_email,
    c.cursor_version,
    g.status as generation_status,
    se.command,
    se.output,
    se.cwd,
    fe.file_path,
    ar.text as response_text,
    at.text as thought_text,
    at.duration_ms,
    p.prompt_text,
    gs.status as stop_status,
    gs.loop_count
FROM events e
JOIN conversations c ON e.conversation_id = c.conversation_id
JOIN generations g ON e.generation_id = g.generation_id
LEFT JOIN shell_executions se ON e.event_id = se.event_id AND e.hook_event_name = 'afterShellExecution'
LEFT JOIN file_edits fe ON e.event_id = fe.event_id AND e.hook_event_name = 'afterFileEdit'
LEFT JOIN agent_responses ar ON e.event_id = ar.event_id AND e.hook_event_name = 'afterAgentResponse'
LEFT JOIN agent_thoughts at ON e.event_id = at.event_id AND e.hook_event_name = 'afterAgentThought'
LEFT JOIN prompts p ON e.event_id = p.event_id AND e.hook_event_name = 'beforeSubmitPrompt'
LEFT JOIN generation_stops gs ON e.event_id = gs.event_id AND e.hook_event_name = 'stop'
WHERE e.generation_id = ?
ORDER BY e.timestamp;
```

**Uso com script:**
```bash
.cursor/scripts/query-context.sh <generation_id>
```

### 2. Recuperar todas as conversas de um workspace

```sql
SELECT DISTINCT c.* 
FROM conversations c
JOIN conversation_workspaces cw ON c.conversation_id = cw.conversation_id
WHERE cw.workspace_root = ?
ORDER BY c.start_time DESC;
```

### 3. Buscar comandos shell executados em uma conversa

```sql
SELECT 
    e.timestamp,
    se.command,
    se.cwd,
    se.duration,
    se.output
FROM events e
JOIN shell_executions se ON e.event_id = se.event_id
WHERE e.conversation_id = ?
ORDER BY e.timestamp DESC;
```

### 4. Buscar arquivos editados em uma generation

```sql
SELECT 
    e.timestamp,
    fe.file_path,
    fe.edits_json,
    json_array_length(fe.edits_json) as num_edits
FROM events e
JOIN file_edits fe ON e.event_id = fe.event_id
WHERE e.generation_id = ?
ORDER BY e.timestamp DESC;
```

### 5. Estatísticas de eventos por tipo

```sql
SELECT 
    hook_event_name,
    COUNT(*) as total,
    MIN(timestamp) as primeiro_evento,
    MAX(timestamp) as ultimo_evento
FROM events
GROUP BY hook_event_name
ORDER BY total DESC;
```

### 6. Respostas do agente ordenadas por timestamp

```sql
SELECT 
    e.timestamp,
    e.conversation_id,
    e.generation_id,
    ar.text
FROM events e
JOIN agent_responses ar ON e.event_id = ar.event_id
ORDER BY e.timestamp DESC
LIMIT 10;
```

### 7. Generations por conversa

```sql
SELECT 
    c.conversation_id,
    COUNT(g.generation_id) as num_generations,
    MIN(g.start_time) as primeira_generation,
    MAX(g.end_time) as ultima_generation
FROM conversations c
LEFT JOIN generations g ON c.conversation_id = g.conversation_id
GROUP BY c.conversation_id
ORDER BY num_generations DESC;
```

### 8. Execuções MCP por ferramenta

```sql
SELECT 
    me.tool_name,
    COUNT(*) as total_execucoes,
    AVG(me.duration) as duracao_media_ms
FROM mcp_executions me
JOIN events e ON me.event_id = e.event_id
GROUP BY me.tool_name
ORDER BY total_execucoes DESC;
```

## Scripts Disponíveis

### `query-context.sh`
Recupera contexto completo de uma generation específica.

**Uso:**
```bash
.cursor/scripts/query-context.sh <generation_id>
```

### `query-examples.sh`
Executa exemplos de consultas comuns no banco de dados.

**Uso:**
```bash
.cursor/scripts/query-examples.sh
```

## Localização do Banco de Dados

O banco SQLite é criado automaticamente em:
```
.cursor/database/cursor_hooks.db
```

O schema SQL está em:
```
.cursor/database/database-schema.sql
```

## Manutenção

### Backup do Banco de Dados

```bash
# Fazer backup
cp .cursor/database/cursor_hooks.db .cursor/database/cursor_hooks.db.backup

# Restaurar backup
cp .cursor/database/cursor_hooks.db.backup .cursor/database/cursor_hooks.db
```

### Verificar Integridade

```bash
sqlite3 .cursor/database/cursor_hooks.db "PRAGMA integrity_check;"
```

### Estatísticas do Banco

```bash
sqlite3 .cursor/database/cursor_hooks.db <<EOF
SELECT 
    name as tabela,
    (SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name=tabela) as existe
FROM (
    SELECT 'conversations' as name
    UNION SELECT 'generations'
    UNION SELECT 'events'
    UNION SELECT 'shell_executions'
    UNION SELECT 'file_edits'
    UNION SELECT 'mcp_executions'
    UNION SELECT 'agent_responses'
    UNION SELECT 'agent_thoughts'
    UNION SELECT 'prompts'
    UNION SELECT 'generation_stops'
);
EOF
```

## Notas Importantes

1. **Versionamento**: O banco SQLite (`cursor_hooks.db`) pode ser versionado no repositório, mas cuidado com conflitos de merge.

2. **Performance**: Para grandes volumes de dados, considere:
   - Limpar eventos antigos periodicamente
   - Usar `VACUUM` para otimizar o banco
   - Criar índices adicionais conforme necessário

3. **Compatibilidade**: O sistema mantém compatibilidade com `session.json` (backward compatibility).

4. **Transações**: Todas as inserções são feitas dentro de transações SQLite para garantir atomicidade.

5. **Escape de Strings**: O `db-manager.sh` escapa strings SQL corretamente, mas cuidado ao executar SQL manualmente.

