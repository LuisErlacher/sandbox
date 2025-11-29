#!/bin/bash

# Teste do script refatorado

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DB_FILE="${PROJECT_ROOT}/.cursor/database/cursor_hooks.db"

echo "=== TESTE DO SCRIPT REFATORADO ==="
echo ""

# Teste 1: Evento fornecido pelo usuário
echo "TESTE 1: Evento simulado fornecido"
echo "-----------------------------------"
test_event1='{
  "conversation_id": "17111106-6b1d-4e9d-9dae-60b0843a32c1",
  "generation_id": "b4bd707a-8af6-4a94-a1a2-3ff65ea71b8a",
  "model": "composer-1",
  "status": "completed",
  "loop_count": 1,
  "hook_event_name": "stop",
  "cursor_version": "2.1.39",
  "workspace_roots": ["/home/luis/projetos/sandbox"],
  "user_email": "cursor1@unlkd.com.br"
}'

result1=$(echo "$test_event1" | bash "$SCRIPT_DIR/task-completion-checker.sh" 2>&1)
echo "Resultado:"
echo "$result1" | jq . 2>/dev/null || echo "$result1"
echo ""

# Verificar se o resultado é válido
if echo "$result1" | jq -e '.followup_message' > /dev/null 2>&1; then
    followup=$(echo "$result1" | jq -r '.followup_message')
    if [ -z "$followup" ]; then
        echo "✅ Agente retornou followup_message vazio (tarefa concluída)"
    else
        echo "✅ Agente retornou followup_message com conteúdo (${#followup} caracteres)"
        echo "   Preview: ${followup:0:150}..."
    fi
else
    echo "❌ Resultado inválido ou erro na execução"
fi

echo ""
echo "=== VERIFICAÇÕES ==="
echo ""

# Verificar se está usando prompt inicial da conversa
if [ -n "$(echo "$test_event1" | jq -r '.conversation_id')" ]; then
    conv_id=$(echo "$test_event1" | jq -r '.conversation_id')
    prompt_inicial=$(sqlite3 "$DB_FILE" <<EOF
SELECT p.prompt_text
FROM prompts p
JOIN events e ON p.event_id = e.event_id
WHERE e.conversation_id = '$conv_id' 
  AND e.hook_event_name = 'beforeSubmitPrompt'
ORDER BY e.timestamp ASC
LIMIT 1;
EOF
)
    if [ -n "$prompt_inicial" ]; then
        echo "✅ Prompt inicial da conversa encontrado (${#prompt_inicial} caracteres)"
    else
        echo "⚠ Prompt inicial não encontrado"
    fi
fi

# Verificar histórico de respostas
if [ -n "$conv_id" ]; then
    response_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM agent_responses ar JOIN events e ON ar.event_id = e.event_id WHERE e.conversation_id = '$conv_id' AND e.hook_event_name = 'afterAgentResponse';" 2>/dev/null)
    echo "✅ Total de respostas na conversa: $response_count"
fi

echo ""
echo "=== TESTE CONCLUÍDO ==="

