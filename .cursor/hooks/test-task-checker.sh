#!/bin/bash

# Script de teste para task-completion-checker.sh
# Simula a execução do hook stop com dados reais do banco

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DB_FILE="${PROJECT_ROOT}/.cursor/database/cursor_hooks.db"
DEBUG_LOG="${HOME}/.cursor/hooks-debug.log"

echo "=== TESTE DO TASK-COMPLETION-CHECKER ==="
echo ""

# Buscar a última conversa do banco
last_conversation=$(sqlite3 "$DB_FILE" "SELECT conversation_id FROM events ORDER BY timestamp DESC LIMIT 1;" 2>/dev/null)

if [ -z "$last_conversation" ]; then
    echo "ERRO: Nenhuma conversa encontrada no banco de dados"
    exit 1
fi

echo "Conversa encontrada: $last_conversation"
echo ""

# Buscar a última generation dessa conversa
last_generation=$(sqlite3 "$DB_FILE" "SELECT generation_id FROM events WHERE conversation_id = '$last_conversation' ORDER BY timestamp DESC LIMIT 1;" 2>/dev/null)

if [ -z "$last_generation" ]; then
    echo "ERRO: Nenhuma generation encontrada para a conversa"
    exit 1
fi

echo "Generation encontrada: $last_generation"
echo ""

# Buscar prompt inicial da conversa
conversation_prompt=$(sqlite3 "$DB_FILE" <<EOF
SELECT p.prompt_text
FROM prompts p
JOIN events e ON p.event_id = e.event_id
WHERE e.conversation_id = '$last_conversation' 
  AND e.hook_event_name = 'beforeSubmitPrompt'
ORDER BY e.timestamp ASC
LIMIT 1;
EOF
)

echo "=== PROMPT INICIAL DA CONVERSA ==="
echo "${conversation_prompt:0:500}..."
echo ""

# Buscar todas as respostas da conversa
all_responses=$(sqlite3 "$DB_FILE" <<EOF
SELECT ar.text || '\n\n---\n\n'
FROM agent_responses ar
JOIN events e ON ar.event_id = e.event_id
WHERE e.conversation_id = '$last_conversation' 
  AND e.hook_event_name = 'afterAgentResponse'
ORDER BY e.timestamp ASC;
EOF
)

response_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM agent_responses ar JOIN events e ON ar.event_id = e.event_id WHERE e.conversation_id = '$last_conversation' AND e.hook_event_name = 'afterAgentResponse';" 2>/dev/null)

echo "=== HISTÓRICO DE RESPOSTAS ==="
echo "Total de respostas: $response_count"
echo ""

if [ -n "$all_responses" ]; then
    echo "Primeiras 500 caracteres da primeira resposta:"
    echo "${all_responses:0:500}..."
    echo ""
    
    if [ "$response_count" -gt 1 ]; then
        echo "Últimas 500 caracteres da última resposta:"
        echo "${all_responses: -500}"
        echo ""
    fi
else
    echo "Nenhuma resposta encontrada"
fi

# Criar JSON de teste simulando o hook stop
test_json=$(jq -n \
    --arg conversation_id "$last_conversation" \
    --arg generation_id "$last_generation" \
    --arg status "completed" \
    --arg loop_count "0" \
    '{
        conversation_id: $conversation_id,
        generation_id: $generation_id,
        status: $status,
        loop_count: ($loop_count | tonumber)
    }')

echo "=== JSON DE TESTE (simulando hook stop) ==="
echo "$test_json" | jq .
echo ""

# Testar o hook
echo "=== EXECUTANDO TASK-COMPLETION-CHECKER ==="
echo ""

result=$(echo "$test_json" | bash "$SCRIPT_DIR/task-completion-checker.sh" 2>&1)

echo "=== RESULTADO ==="
echo "$result" | jq . 2>/dev/null || echo "$result"
echo ""

# Verificar logs recentes
echo "=== ÚLTIMAS LINHAS DO LOG ==="
tail -n 30 "$DEBUG_LOG" 2>/dev/null || echo "Log não encontrado"
echo ""

echo "=== TESTE CONCLUÍDO ==="

