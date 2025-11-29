#!/bin/bash

# verify-collection.sh - Script para verificar se todas as variáveis estão sendo coletadas corretamente

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DB_FILE="${PROJECT_ROOT}/.cursor/database/cursor_hooks.db"

echo "=== Verificação de Coleta de Variáveis ==="
echo ""

# Verificar se o banco existe
if [ ! -f "$DB_FILE" ]; then
    echo "ERRO: Banco de dados não encontrado em $DB_FILE"
    exit 1
fi

echo "1. Verificando metadados globais na tabela events:"
sqlite3 -header -column "$DB_FILE" <<EOF
SELECT 
    conversation_id,
    generation_id,
    hook_event_name,
    model,
    cursor_version,
    COUNT(*) as total_eventos
FROM events
GROUP BY conversation_id, generation_id, hook_event_name, model, cursor_version
ORDER BY total_eventos DESC
LIMIT 5;
EOF

echo ""
echo "2. Verificando dados em conversations:"
sqlite3 -header -column "$DB_FILE" <<EOF
SELECT 
    conversation_id,
    user_email,
    cursor_version,
    status,
    start_time
FROM conversations
ORDER BY start_time DESC
LIMIT 3;
EOF

echo ""
echo "3. Verificando dados em generations:"
sqlite3 -header -column "$DB_FILE" <<EOF
SELECT 
    generation_id,
    conversation_id,
    model,
    status,
    start_time
FROM generations
ORDER BY start_time DESC
LIMIT 3;
EOF

echo ""
echo "4. Verificando workspace_roots em conversation_workspaces:"
sqlite3 -header -column "$DB_FILE" <<EOF
SELECT 
    conversation_id,
    workspace_root
FROM conversation_workspaces
ORDER BY conversation_id DESC
LIMIT 5;
EOF

echo ""
echo "5. Verificando dados específicos de afterShellExecution:"
sqlite3 -header -column "$DB_FILE" <<EOF
SELECT 
    e.event_id,
    e.hook_event_name,
    se.command,
    se.cwd,
    CASE 
        WHEN length(se.output) > 50 THEN substr(se.output, 1, 50) || '...'
        ELSE se.output
    END as output_preview,
    se.duration
FROM events e
JOIN shell_executions se ON e.event_id = se.event_id
WHERE e.hook_event_name = 'afterShellExecution'
ORDER BY e.event_id DESC
LIMIT 3;
EOF

echo ""
echo "6. Verificando dados específicos de afterFileEdit:"
sqlite3 -header -column "$DB_FILE" <<EOF
SELECT 
    e.event_id,
    e.hook_event_name,
    fe.file_path,
    json_array_length(fe.edits_json) as num_edits
FROM events e
JOIN file_edits fe ON e.event_id = fe.event_id
WHERE e.hook_event_name = 'afterFileEdit'
ORDER BY e.event_id DESC
LIMIT 3;
EOF

echo ""
echo "7. Verificando dados específicos de afterAgentResponse:"
sqlite3 -header -column "$DB_FILE" <<EOF
SELECT 
    e.event_id,
    e.hook_event_name,
    CASE 
        WHEN length(ar.text) > 100 THEN substr(ar.text, 1, 100) || '...'
        ELSE ar.text
    END as text_preview
FROM events e
JOIN agent_responses ar ON e.event_id = ar.event_id
WHERE e.hook_event_name = 'afterAgentResponse'
ORDER BY e.event_id DESC
LIMIT 3;
EOF

echo ""
echo "8. Verificando dados específicos de stop:"
sqlite3 -header -column "$DB_FILE" <<EOF
SELECT 
    e.event_id,
    e.hook_event_name,
    gs.status,
    gs.loop_count
FROM events e
JOIN generation_stops gs ON e.event_id = gs.event_id
WHERE e.hook_event_name = 'stop'
ORDER BY e.event_id DESC
LIMIT 3;
EOF

echo ""
echo "9. Verificando se data_json contém todos os dados:"
sqlite3 "$DB_FILE" <<EOF
SELECT 
    event_id,
    hook_event_name,
    json_extract(data_json, '$') as data_json_preview
FROM events
WHERE hook_event_name = 'afterShellExecution'
ORDER BY event_id DESC
LIMIT 1;
EOF

echo ""
echo "=== Verificação Completa ==="
echo ""
echo "Total de eventos: $(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM events;")"
echo "Total de conversas: $(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM conversations;")"
echo "Total de generations: $(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM generations;")"
echo "Total de workspaces: $(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM conversation_workspaces;")"

