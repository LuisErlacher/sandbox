#!/bin/bash

# query-examples.sh - Scripts de exemplo para consultas comuns no banco de dados

# Detectar PROJECT_ROOT
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DB_FILE="${PROJECT_ROOT}/.cursor/database/cursor_hooks.db"

if [ ! -f "$DB_FILE" ]; then
    echo "ERRO: Banco de dados não encontrado em $DB_FILE"
    exit 1
fi

echo "=== Exemplos de Consultas SQL ==="
echo ""

# Função para executar e mostrar consulta
run_query() {
    local title="$1"
    local sql="$2"
    
    echo "--- $title ---"
    echo "SQL: $sql"
    echo ""
    sqlite3 -header -column "$DB_FILE" "$sql"
    echo ""
    echo ""
}

# 1. Recuperar todas as conversas de um workspace
WORKSPACE_ROOT="${PROJECT_ROOT}"
run_query "Todas as conversas do workspace atual" \
    "SELECT DISTINCT c.* 
     FROM conversations c
     JOIN conversation_workspaces cw ON c.conversation_id = cw.conversation_id
     WHERE cw.workspace_root = '$WORKSPACE_ROOT'
     ORDER BY c.start_time DESC
     LIMIT 10;"

# 2. Buscar comandos shell executados em uma conversa específica
CONVERSATION_ID=$(sqlite3 "$DB_FILE" "SELECT conversation_id FROM conversations ORDER BY start_time DESC LIMIT 1;" 2>/dev/null)
if [ -n "$CONVERSATION_ID" ]; then
    run_query "Comandos shell executados na última conversa" \
        "SELECT 
            e.timestamp,
            se.command,
            se.cwd,
            se.duration,
            LEFT(se.output, 100) as output_preview
         FROM events e
         JOIN shell_executions se ON e.event_id = se.event_id
         WHERE e.conversation_id = '$CONVERSATION_ID'
         ORDER BY e.timestamp DESC
         LIMIT 10;"
fi

# 3. Buscar arquivos editados em uma generation específica
GENERATION_ID=$(sqlite3 "$DB_FILE" "SELECT generation_id FROM generations ORDER BY start_time DESC LIMIT 1;" 2>/dev/null)
if [ -n "$GENERATION_ID" ]; then
    run_query "Arquivos editados na última generation" \
        "SELECT 
            e.timestamp,
            fe.file_path,
            json_array_length(fe.edits_json) as num_edits
         FROM events e
         JOIN file_edits fe ON e.event_id = fe.event_id
         WHERE e.generation_id = '$GENERATION_ID'
         ORDER BY e.timestamp DESC;"
fi

# 4. Estatísticas de eventos por tipo
run_query "Estatísticas de eventos por tipo" \
    "SELECT 
        hook_event_name,
        COUNT(*) as total,
        MIN(timestamp) as primeiro_evento,
        MAX(timestamp) as ultimo_evento
     FROM events
     GROUP BY hook_event_name
     ORDER BY total DESC;"

# 5. Respostas do agente ordenadas por timestamp
run_query "Últimas respostas do agente" \
    "SELECT 
        e.timestamp,
        e.conversation_id,
        e.generation_id,
        LEFT(ar.text, 200) as response_preview
     FROM events e
     JOIN agent_responses ar ON e.event_id = ar.event_id
     ORDER BY e.timestamp DESC
     LIMIT 5;"

# 6. Generations por conversa
run_query "Generations por conversa" \
    "SELECT 
        c.conversation_id,
        COUNT(g.generation_id) as num_generations,
        MIN(g.start_time) as primeira_generation,
        MAX(g.end_time) as ultima_generation
     FROM conversations c
     LEFT JOIN generations g ON c.conversation_id = g.conversation_id
     GROUP BY c.conversation_id
     ORDER BY num_generations DESC
     LIMIT 10;"

# 7. Execuções MCP por ferramenta
run_query "Execuções MCP por ferramenta" \
    "SELECT 
        me.tool_name,
        COUNT(*) as total_execucoes,
        AVG(me.duration) as duracao_media_ms
     FROM mcp_executions me
     JOIN events e ON me.event_id = e.event_id
     GROUP BY me.tool_name
     ORDER BY total_execucoes DESC;"

# 8. Contexto completo de uma generation (exemplo)
if [ -n "$GENERATION_ID" ]; then
    echo "--- Contexto completo da última generation (primeiros 5 eventos) ---"
    echo ""
    sqlite3 -header -column "$DB_FILE" <<EOF
SELECT 
    e.event_id,
    e.hook_event_name,
    e.timestamp,
    CASE 
        WHEN e.hook_event_name = 'afterShellExecution' THEN se.command
        WHEN e.hook_event_name = 'afterFileEdit' THEN fe.file_path
        WHEN e.hook_event_name = 'afterAgentResponse' THEN LEFT(ar.text, 50)
        WHEN e.hook_event_name = 'beforeSubmitPrompt' THEN LEFT(p.prompt_text, 50)
        ELSE 'N/A'
    END as resumo
FROM events e
LEFT JOIN shell_executions se ON e.event_id = se.event_id AND e.hook_event_name = 'afterShellExecution'
LEFT JOIN file_edits fe ON e.event_id = fe.event_id AND e.hook_event_name = 'afterFileEdit'
LEFT JOIN agent_responses ar ON e.event_id = ar.event_id AND e.hook_event_name = 'afterAgentResponse'
LEFT JOIN prompts p ON e.event_id = p.event_id AND e.hook_event_name = 'beforeSubmitPrompt'
WHERE e.generation_id = '$GENERATION_ID'
ORDER BY e.timestamp
LIMIT 5;
EOF
fi

echo ""
echo "=== Para mais consultas, veja DATABASE.md ==="

