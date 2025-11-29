#!/bin/bash

# query-context.sh - Script para recuperar contexto completo de uma generation
# Uso: ./query-context.sh <generation_id>

if [ -z "$1" ]; then
    echo "Uso: $0 <generation_id>"
    echo "Exemplo: $0 d942c794-622d-466d-b099-24ab6fe8a77b"
    exit 1
fi

GENERATION_ID="$1"

# Detectar PROJECT_ROOT
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DB_FILE="${PROJECT_ROOT}/.cursor/database/cursor_hooks.db"

if [ ! -f "$DB_FILE" ]; then
    echo "ERRO: Banco de dados não encontrado em $DB_FILE"
    exit 1
fi

# Consulta SQL para recuperar contexto completo
sqlite3 -header -column "$DB_FILE" <<EOF
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
WHERE e.generation_id = '$GENERATION_ID'
ORDER BY e.timestamp;
EOF

# Também mostrar o JSON completo dos dados
echo ""
echo "=== Dados JSON completos ==="
sqlite3 "$DB_FILE" <<EOF
SELECT 
    e.event_id,
    e.hook_event_name,
    e.timestamp,
    e.data_json
FROM events e
WHERE e.generation_id = '$GENERATION_ID'
ORDER BY e.timestamp;
EOF

