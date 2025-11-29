#!/bin/bash

# query-conversation-history.sh - Recupera histórico completo de uma conversa
# Uso: ./query-conversation-history.sh [conversation_id]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DB_FILE="${PROJECT_ROOT}/.cursor/database/cursor_hooks.db"

if [ -z "$1" ]; then
    # Se não forneceu conversation_id, usar a mais recente
    CONV_ID=$(sqlite3 "$DB_FILE" "SELECT conversation_id FROM conversations ORDER BY start_time DESC LIMIT 1;" 2>/dev/null)
    if [ -z "$CONV_ID" ]; then
        echo "ERRO: Nenhuma conversa encontrada no banco de dados"
        exit 1
    fi
    echo "Usando conversa mais recente: $CONV_ID"
else
    CONV_ID="$1"
fi

echo ""
echo "=== Histórico da Conversa: $CONV_ID ==="
echo ""

# Informações da conversa
echo "--- Informações da Conversa ---"
sqlite3 -header -column "$DB_FILE" <<EOF
SELECT 
    conversation_id,
    user_email,
    cursor_version,
    status,
    start_time,
    end_time
FROM conversations
WHERE conversation_id = '$CONV_ID';
EOF

echo ""
echo "--- Workspaces ---"
sqlite3 -header -column "$DB_FILE" <<EOF
SELECT workspace_root
FROM conversation_workspaces
WHERE conversation_id = '$CONV_ID';
EOF

echo ""
echo "--- Generations ---"
sqlite3 -header -column "$DB_FILE" <<EOF
SELECT 
    generation_id,
    model,
    status,
    start_time,
    end_time
FROM generations
WHERE conversation_id = '$CONV_ID'
ORDER BY start_time ASC;
EOF

echo ""
echo "=== Timeline de Eventos ==="
echo ""

# Timeline completa em formato legível
sqlite3 -header -column "$DB_FILE" <<EOF
SELECT 
    e.event_id,
    e.timestamp,
    e.hook_event_name,
    e.generation_id,
    CASE 
        WHEN e.hook_event_name = 'beforeSubmitPrompt' THEN substr(p.prompt_text, 1, 100) || '...'
        WHEN e.hook_event_name = 'afterAgentResponse' THEN substr(ar.text, 1, 100) || '...'
        WHEN e.hook_event_name = 'afterShellExecution' THEN se.command
        WHEN e.hook_event_name = 'afterFileEdit' THEN fe.file_path
        WHEN e.hook_event_name = 'stop' THEN gs.status || ' (loops: ' || gs.loop_count || ')'
        WHEN e.hook_event_name = 'afterAgentThought' THEN 'Thought (' || at.duration_ms || 'ms)'
        ELSE 'Ver data_json'
    END as resumo
FROM events e
LEFT JOIN prompts p ON e.event_id = p.event_id AND e.hook_event_name = 'beforeSubmitPrompt'
LEFT JOIN agent_responses ar ON e.event_id = ar.event_id AND e.hook_event_name = 'afterAgentResponse'
LEFT JOIN shell_executions se ON e.event_id = se.event_id AND e.hook_event_name = 'afterShellExecution'
LEFT JOIN file_edits fe ON e.event_id = fe.event_id AND e.hook_event_name = 'afterFileEdit'
LEFT JOIN generation_stops gs ON e.event_id = gs.event_id AND e.hook_event_name = 'stop'
LEFT JOIN agent_thoughts at ON e.event_id = at.event_id AND e.hook_event_name = 'afterAgentThought'
WHERE e.conversation_id = '$CONV_ID'
ORDER BY e.timestamp ASC;
EOF

echo ""
echo "=== Dados Completos em JSON ==="
echo ""

# Dados completos em JSON
sqlite3 "$DB_FILE" <<EOF
.mode json
SELECT 
    e.event_id,
    e.timestamp,
    e.hook_event_name,
    e.model,
    e.generation_id,
    json_object(
        'conversation_id', e.conversation_id,
        'generation_id', e.generation_id,
        'model', e.model,
        'cursor_version', c.cursor_version,
        'user_email', c.user_email,
        'hook_event_name', e.hook_event_name,
        'timestamp', e.timestamp,
        'data', json(
            CASE 
                WHEN e.hook_event_name = 'beforeSubmitPrompt' THEN json_object('prompt', p.prompt_text, 'attachments', json(p.attachments_json))
                WHEN e.hook_event_name = 'afterAgentResponse' THEN json_object('text', ar.text)
                WHEN e.hook_event_name = 'afterShellExecution' THEN json_object('command', se.command, 'cwd', se.cwd, 'output', se.output, 'duration', se.duration)
                WHEN e.hook_event_name = 'afterFileEdit' THEN json_object('file_path', fe.file_path, 'edits', json(fe.edits_json))
                WHEN e.hook_event_name = 'stop' THEN json_object('status', gs.status, 'loop_count', gs.loop_count)
                WHEN e.hook_event_name = 'afterAgentThought' THEN json_object('text', at.text, 'duration_ms', at.duration_ms)
                ELSE e.data_json
            END
        )
    ) as event
FROM events e
JOIN conversations c ON e.conversation_id = c.conversation_id
LEFT JOIN prompts p ON e.event_id = p.event_id AND e.hook_event_name = 'beforeSubmitPrompt'
LEFT JOIN agent_responses ar ON e.event_id = ar.event_id AND e.hook_event_name = 'afterAgentResponse'
LEFT JOIN shell_executions se ON e.event_id = se.event_id AND e.hook_event_name = 'afterShellExecution'
LEFT JOIN file_edits fe ON e.event_id = fe.event_id AND e.hook_event_name = 'afterFileEdit'
LEFT JOIN generation_stops gs ON e.event_id = gs.event_id AND e.hook_event_name = 'stop'
LEFT JOIN agent_thoughts at ON e.event_id = at.event_id AND e.hook_event_name = 'afterAgentThought'
WHERE e.conversation_id = '$CONV_ID'
ORDER BY e.timestamp ASC;
EOF

echo ""
echo "=== Estatísticas ==="
sqlite3 -header -column "$DB_FILE" <<EOF
SELECT 
    hook_event_name,
    COUNT(*) as total,
    MIN(timestamp) as primeiro,
    MAX(timestamp) as ultimo
FROM events
WHERE conversation_id = '$CONV_ID'
GROUP BY hook_event_name
ORDER BY total DESC;
EOF

