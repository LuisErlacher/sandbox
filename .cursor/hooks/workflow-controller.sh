#!/bin/bash

# workflow-controller.sh - Hook 'stop' para controle de workflow
# O Cursor envia automaticamente o followup_message como próxima mensagem
# Agora integrado com task-completion-checker.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOW_STATUS_FILE="${HOME}/workflow-status.yaml"
MAX_LOOPS=5  # Aumentado para permitir mais iterações com o checker automático
DEBUG_LOG="${HOME}/.cursor/hooks-debug.log"

# Ler JSON do stdin
json_input=$(cat)

# Extrair campos
status=$(echo "$json_input" | jq -r '.status // "unknown"')
loop_count=$(echo "$json_input" | jq -r '.loop_count // 0')
generation_id=$(echo "$json_input" | jq -r '.generation_id // empty')

# Se abortado/erro, não continuar
if [ "$status" = "aborted" ] || [ "$status" = "error" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] workflow-controller: Status é $status, não continuando" >> "$DEBUG_LOG" 2>&1
    echo '{}'
    exit 0
fi

# Verificar limite de loops
if [ "$loop_count" -ge "$MAX_LOOPS" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] workflow-controller: Limite de loops atingido ($loop_count >= $MAX_LOOPS)" >> "$DEBUG_LOG" 2>&1
    echo '{}'
    exit 0
fi

# Verificar se workflow-status.yaml tem finishing=true (backward compatibility)
if [ -f "$WORKFLOW_STATUS_FILE" ]; then
    if grep -q 'finishing:\s*true' "$WORKFLOW_STATUS_FILE" 2>/dev/null; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] workflow-controller: workflow-status.yaml indica finishing=true" >> "$DEBUG_LOG" 2>&1
        echo '{}'
        exit 0
    fi
fi

# Verificar se task-completion-checker.sh já executou e deixou resultado
# (ele é executado antes no hooks.json)
RESULT_FILE="${HOME}/.cursor/task-checker-result-${generation_id}.json"
if [ -f "$RESULT_FILE" ] && [ -s "$RESULT_FILE" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] workflow-controller: Lendo resultado do task-completion-checker" >> "$DEBUG_LOG" 2>&1
    
    checker_result=$(cat "$RESULT_FILE" 2>/dev/null)
    
    if [ -n "$checker_result" ] && echo "$checker_result" | jq . > /dev/null 2>&1; then
        # Verificar se o checker retornou followup_message
        followup_msg=$(echo "$checker_result" | jq -r '.followup_message // "NOT_SET"' 2>/dev/null)
        
        if [ "$followup_msg" != "NOT_SET" ]; then
            # O checker retornou um resultado válido
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] workflow-controller: Usando resultado do task-completion-checker (followup_message: ${followup_msg:0:50}...)" >> "$DEBUG_LOG" 2>&1
            
            # Limpar arquivo temporário
            rm -f "$RESULT_FILE"
            
            echo "$checker_result"
            exit 0
        fi
    fi
    
    # Limpar arquivo se inválido
    rm -f "$RESULT_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] workflow-controller: Resultado do task-completion-checker inválido, usando fallback" >> "$DEBUG_LOG" 2>&1
fi

# Fallback: Retornar followup_message padrão se o checker não funcionar
cat << 'EOF'
{
  "followup_message": "Verifique se finalizou a tarefa. Se sim, atualize ~/workflow-status.yaml com finishing: true. Se não, continue."
}
EOF
