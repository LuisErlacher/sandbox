-- Schema do Banco de Dados SQLite para Hooks do Cursor
-- Este arquivo contém todas as definições de tabelas, índices e relacionamentos

-- Tabela: conversations
-- Armazena informações sobre cada conversa completa
CREATE TABLE IF NOT EXISTS conversations (
    conversation_id TEXT PRIMARY KEY,
    user_email TEXT NOT NULL,
    cursor_version TEXT,
    start_time TEXT NOT NULL,
    end_time TEXT,
    status TEXT DEFAULT 'active', -- 'active', 'completed', 'aborted', 'error'
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_conversations_user ON conversations(user_email);
CREATE INDEX IF NOT EXISTS idx_conversations_time ON conversations(start_time);
CREATE INDEX IF NOT EXISTS idx_conversations_status ON conversations(status);

-- Tabela: conversation_workspaces
-- Relaciona conversas com seus workspaces (workspace_roots é um array)
CREATE TABLE IF NOT EXISTS conversation_workspaces (
    conversation_id TEXT NOT NULL,
    workspace_root TEXT NOT NULL,
    PRIMARY KEY (conversation_id, workspace_root),
    FOREIGN KEY (conversation_id) REFERENCES conversations(conversation_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_conv_workspaces_root ON conversation_workspaces(workspace_root);

-- Tabela: generations
-- Armazena informações sobre cada geração/resposta do agente dentro de uma conversa
CREATE TABLE IF NOT EXISTS generations (
    generation_id TEXT PRIMARY KEY,
    conversation_id TEXT NOT NULL,
    model TEXT NOT NULL,
    start_time TEXT NOT NULL,
    end_time TEXT,
    status TEXT DEFAULT 'active', -- 'active', 'completed', 'aborted', 'error'
    FOREIGN KEY (conversation_id) REFERENCES conversations(conversation_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_generations_conversation ON generations(conversation_id);
CREATE INDEX IF NOT EXISTS idx_generations_time ON generations(start_time);
CREATE INDEX IF NOT EXISTS idx_generations_model ON generations(model);

-- Tabela: events
-- Tabela principal que armazena todos os eventos, com referências a conversation e generation
CREATE TABLE IF NOT EXISTS events (
    event_id INTEGER PRIMARY KEY AUTOINCREMENT,
    conversation_id TEXT NOT NULL,
    generation_id TEXT NOT NULL,
    event_type TEXT NOT NULL, -- 'beforeSubmitPrompt', 'afterAgentResponse', etc.
    hook_event_name TEXT NOT NULL, -- Nome do hook que disparou
    model TEXT, -- Modelo usado nesta geração
    cursor_version TEXT,
    timestamp TEXT NOT NULL,
    data_json TEXT NOT NULL, -- JSON completo dos dados específicos do evento
    FOREIGN KEY (conversation_id) REFERENCES conversations(conversation_id) ON DELETE CASCADE,
    FOREIGN KEY (generation_id) REFERENCES generations(generation_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_events_conversation ON events(conversation_id);
CREATE INDEX IF NOT EXISTS idx_events_generation ON events(generation_id);
CREATE INDEX IF NOT EXISTS idx_events_type ON events(event_type);
CREATE INDEX IF NOT EXISTS idx_events_hook_name ON events(hook_event_name);
CREATE INDEX IF NOT EXISTS idx_events_timestamp ON events(timestamp);
CREATE INDEX IF NOT EXISTS idx_events_model ON events(model);

-- Tabela: shell_executions
-- Dados específicos de comandos shell executados
CREATE TABLE IF NOT EXISTS shell_executions (
    event_id INTEGER PRIMARY KEY,
    command TEXT NOT NULL,
    cwd TEXT,
    output TEXT,
    duration INTEGER, -- em milissegundos (pode ser NULL)
    FOREIGN KEY (event_id) REFERENCES events(event_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_shell_executions_command ON shell_executions(command);
CREATE INDEX IF NOT EXISTS idx_shell_executions_cwd ON shell_executions(cwd);

-- Tabela: file_edits
-- Dados específicos de edições de arquivos
CREATE TABLE IF NOT EXISTS file_edits (
    event_id INTEGER PRIMARY KEY,
    file_path TEXT NOT NULL,
    edits_json TEXT NOT NULL, -- JSON array de edições [{old_string, new_string, ...}]
    FOREIGN KEY (event_id) REFERENCES events(event_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_file_edits_path ON file_edits(file_path);

-- Tabela: file_edit_details
-- Detalhes individuais de cada edição (normalização do array edits)
CREATE TABLE IF NOT EXISTS file_edit_details (
    edit_id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_id INTEGER NOT NULL,
    old_string TEXT,
    new_string TEXT,
    edit_order INTEGER NOT NULL, -- Ordem da edição no array
    FOREIGN KEY (event_id) REFERENCES file_edits(event_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_edit_details_event ON file_edit_details(event_id);

-- Tabela: mcp_executions
-- Dados específicos de execuções MCP
CREATE TABLE IF NOT EXISTS mcp_executions (
    event_id INTEGER PRIMARY KEY,
    tool_name TEXT NOT NULL,
    tool_input TEXT, -- JSON string
    result_json TEXT, -- JSON string
    duration INTEGER,
    FOREIGN KEY (event_id) REFERENCES events(event_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_mcp_executions_tool ON mcp_executions(tool_name);

-- Tabela: agent_responses
-- Dados específicos de respostas do agente
CREATE TABLE IF NOT EXISTS agent_responses (
    event_id INTEGER PRIMARY KEY,
    text TEXT NOT NULL,
    FOREIGN KEY (event_id) REFERENCES events(event_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_agent_responses_text ON agent_responses(text);

-- Tabela: agent_thoughts
-- Dados específicos de pensamentos/raciocínio do agente
CREATE TABLE IF NOT EXISTS agent_thoughts (
    event_id INTEGER PRIMARY KEY,
    text TEXT, -- Pode estar vazio
    duration_ms INTEGER NOT NULL,
    FOREIGN KEY (event_id) REFERENCES events(event_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_agent_thoughts_duration ON agent_thoughts(duration_ms);

-- Tabela: prompts
-- Dados específicos de prompts do usuário
CREATE TABLE IF NOT EXISTS prompts (
    event_id INTEGER PRIMARY KEY,
    prompt_text TEXT NOT NULL,
    attachments_json TEXT, -- JSON array de attachments
    FOREIGN KEY (event_id) REFERENCES events(event_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_prompts_text ON prompts(prompt_text);

-- Tabela: generation_stops
-- Dados específicos de finalização de geração
CREATE TABLE IF NOT EXISTS generation_stops (
    event_id INTEGER PRIMARY KEY,
    status TEXT NOT NULL, -- 'completed', 'aborted', 'error'
    loop_count INTEGER NOT NULL,
    FOREIGN KEY (event_id) REFERENCES events(event_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_generation_stops_status ON generation_stops(status);

-- Tabela: reexecute_decisions
-- Armazena decisões de não reexecutar o agente quando finish=true
CREATE TABLE IF NOT EXISTS reexecute_decisions (
    decision_id INTEGER PRIMARY KEY AUTOINCREMENT,
    conversation_id TEXT NOT NULL,
    generation_id TEXT NOT NULL,
    finish BOOLEAN NOT NULL, -- true = tarefa concluída, false = precisa continuar
    reason TEXT, -- Motivo da decisão quando finish=true (para auditoria)
    followup_message TEXT, -- Mensagem de followup quando finish=false
    prompt_text TEXT, -- Prompt inicial que foi avaliado
    agent_response_summary TEXT, -- Resumo da resposta do agente avaliada
    timestamp TEXT NOT NULL, -- Timestamp ISO 8601 da decisão
    FOREIGN KEY (conversation_id) REFERENCES conversations(conversation_id) ON DELETE CASCADE,
    FOREIGN KEY (generation_id) REFERENCES generations(generation_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_reexecute_decisions_conversation ON reexecute_decisions(conversation_id);
CREATE INDEX IF NOT EXISTS idx_reexecute_decisions_generation ON reexecute_decisions(generation_id);
CREATE INDEX IF NOT EXISTS idx_reexecute_decisions_finish ON reexecute_decisions(finish);
CREATE INDEX IF NOT EXISTS idx_reexecute_decisions_timestamp ON reexecute_decisions(timestamp);

