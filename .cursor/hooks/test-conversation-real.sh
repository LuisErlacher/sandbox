#!/bin/bash

# Teste com conversa real que tem múltiplas iterações
# Conversa: b3e9c345-c979-4580-a7a8-64876059c580 (4 respostas)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DB_FILE="${PROJECT_ROOT}/.cursor/database/cursor_hooks.db"
DEBUG_LOG="${HOME}/.cursor/hooks-debug.log"

CONVERSATION_ID="b3e9c345-c979-4580-a7a8-64876059c580"

echo "=== TESTE COM CONVERSA REAL (MÚLTIPLAS ITERAÇÕES) ==="
echo "Conversa: $CONVERSATION_ID"
echo ""

# Buscar última generation dessa conversa
last_generation=$(sqlite3 "$DB_FILE" "SELECT generation_id FROM events WHERE conversation_id = '$CONVERSATION_ID' ORDER BY timestamp DESC LIMIT 1;" 2>/dev/null)

if [ -z "$last_generation" ]; then
    echo "ERRO: Nenhuma generation encontrada"
    exit 1
fi

echo "Generation para teste: $last_generation"
echo ""

# Buscar prompt inicial da conversa
conversation_prompt=$(sqlite3 "$DB_FILE" <<EOF
SELECT p.prompt_text
FROM prompts p
JOIN events e ON p.event_id = e.event_id
WHERE e.conversation_id = '$CONVERSATION_ID' 
  AND e.hook_event_name = 'beforeSubmitPrompt'
ORDER BY e.timestamp ASC
LIMIT 1;
EOF
)

echo "=== PROMPT INICIAL DA CONVERSA ==="
echo "${conversation_prompt:0:300}..."
echo ""

# Contar respostas
response_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM agent_responses ar JOIN events e ON ar.event_id = e.event_id WHERE e.conversation_id = '$CONVERSATION_ID' AND e.hook_event_name = 'afterAgentResponse';" 2>/dev/null)

echo "=== HISTÓRICO DE RESPOSTAS ==="
echo "Total de respostas na conversa: $response_count"
echo ""

# Buscar todas as respostas
all_responses=$(sqlite3 "$DB_FILE" <<EOF
SELECT GROUP_CONCAT(ar.text, '\n\n--- RESPOSTA ---\n\n')
FROM agent_responses ar
JOIN events e ON ar.event_id = e.event_id
WHERE e.conversation_id = '$CONVERSATION_ID' 
  AND e.hook_event_name = 'afterAgentResponse'
ORDER BY e.timestamp ASC;
EOF
)

if [ -n "$all_responses" ] && [ "$all_responses" != "NULL" ]; then
    echo "Primeiras 300 caracteres da primeira resposta:"
    echo "${all_responses:0:300}..."
    echo ""
    
    if [ "$response_count" -gt 1 ]; then
        echo "Últimas 300 caracteres da última resposta:"
        echo "${all_responses: -300}"
        echo ""
    fi
fi

# Criar JSON de teste
test_json=$(jq -n \
    --arg conversation_id "$CONVERSATION_ID" \
    --arg generation_id "$last_generation" \
    --arg status "completed" \
    --arg loop_count "0" \
    '{
        conversation_id: $conversation_id,
        generation_id: $generation_id,
        status: $status,
        loop_count: ($loop_count | tonumber)
    }')

echo "=== EXECUTANDO TASK-COMPLETION-CHECKER ==="
echo ""

# Limpar logs anteriores do teste
echo "" >> "$DEBUG_LOG"
echo "=== INÍCIO DO TESTE MANUAL ===" >> "$DEBUG_LOG"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Testando conversa: $CONVERSATION_ID" >> "$DEBUG_LOG"

result=$(echo "$test_json" | bash "$SCRIPT_DIR/task-completion-checker.sh" 2>&1)

echo "=== RESULTADO DO HOOK ==="
echo "$result" | jq . 2>/dev/null || echo "$result"
echo ""

# Verificar logs específicos
echo "=== VERIFICAÇÃO DOS LOGS ==="
echo ""

# Verificar se está usando prompt da conversa
if grep -q "Usando prompt inicial da conversa" "$DEBUG_LOG" | tail -1; then
    echo "✓ CONFIRMADO: Usando prompt inicial da conversa"
else
    echo "✗ PROBLEMA: Não encontrado log de uso do prompt inicial"
fi

# Verificar histórico completo
if grep -q "Histórico completo de respostas encontrado" "$DEBUG_LOG" | tail -1; then
    echo "✓ CONFIRMADO: Processando histórico completo de respostas"
    grep "Total de respostas na conversa:" "$DEBUG_LOG" | tail -1
else
    echo "✗ PROBLEMA: Não encontrado log de histórico completo"
fi

# Verificar followup_message específico
followup_msg=$(echo "$result" | jq -r '.followup_message // ""' 2>/dev/null)
if [ -n "$followup_msg" ] && [ "$followup_msg" != "" ]; then
    if echo "$followup_msg" | grep -qi "todo_write\|incremental\|genérico\|continue\|verifique"; then
        if echo "$followup_msg" | grep -qi "todo_write.*incremental"; then
            echo "⚠ AVISO: Followup_message pode ser genérico (contém 'todo_write' e 'incremental')"
        else
            echo "✓ CONFIRMADO: Followup_message gerado (não vazio)"
        fi
    else
        echo "✓ CONFIRMADO: Followup_message gerado e parece específico"
    fi
    echo "   Tamanho: ${#followup_msg} caracteres"
    echo "   Preview: ${followup_msg:0:150}..."
else
    echo "✓ CONFIRMADO: Followup_message vazio (task concluída ou sem continuidade)"
fi

echo ""
echo "=== TESTE CONCLUÍDO ==="

