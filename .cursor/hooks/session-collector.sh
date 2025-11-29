#!/bin/bash

# session-collector.sh - Script de hook que coleta dados de sessão em session.json
# Este script é chamado por vários hooks do Cursor para registrar eventos da sessão

# IMPORTANTE: Este script deve ser executado a partir do diretório onde está o hooks.json (.cursor)
# O Cursor executa hooks a partir do diretório onde está o hooks.json

# Obter o diretório absoluto do script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# O script está em .cursor/hooks/, então o hooks.json está em .cursor/
# O diretório de trabalho do Cursor deve ser .cursor quando executa hooks
# Mas vamos detectar de forma robusta

# O script está em .cursor/hooks/, então subimos 2 níveis para chegar à raiz do projeto
# Ou se PWD contém .cursor, usamos isso
if [ -n "$PWD" ] && [[ "$PWD" == *"/.cursor" ]]; then
    # Se PWD está em .cursor, subir um nível
    PROJECT_ROOT="$(cd "$PWD/.." && pwd)"
elif [ -n "$PWD" ] && [[ "$PWD" != *"/.cursor"* ]]; then
    # Se PWD não está em .cursor, pode ser que estejamos na raiz do projeto
    # Verificar se existe .cursor aqui
    if [ -d "$PWD/.cursor" ]; then
        PROJECT_ROOT="$PWD"
    else
        # Fallback: usar o diretório do script
        PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
    fi
else
    # Fallback: usar o diretório do script
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

SESSION_FILE="${PROJECT_ROOT}/.cursor/session.json"
SESSIONS_FILE="${PROJECT_ROOT}/.cursor/sessions.json"
DEBUG_LOG="${HOME}/.cursor/hooks-debug.log"

# Log inicial para debug
echo "[$(date '+%Y-%m-%d %H:%M:%S')] === Hook executado ===" >> "$DEBUG_LOG" 2>&1
echo "[$(date '+%Y-%m-%d %H:%M:%S')] PWD: $PWD" >> "$DEBUG_LOG" 2>&1
echo "[$(date '+%Y-%m-%d %H:%M:%S')] PROJECT_ROOT: $PROJECT_ROOT" >> "$DEBUG_LOG" 2>&1
echo "[$(date '+%Y-%m-%d %H:%M:%S')] SESSION_FILE: $SESSION_FILE" >> "$DEBUG_LOG" 2>&1

# Ler a entrada JSON da entrada padrão (stdin)
json_input=$(cat)

# Log da entrada recebida (primeiros 200 caracteres para não encher o log)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Entrada recebida (primeiros 200 chars): ${json_input:0:200}" >> "$DEBUG_LOG" 2>&1

# Verificar se recebeu entrada
if [ -z "$json_input" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERRO: Nenhuma entrada recebida no stdin" >> "$DEBUG_LOG" 2>&1
    exit 1
fi

# Verificar se é JSON válido
if ! echo "$json_input" | jq . > /dev/null 2>&1; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERRO: JSON inválido recebido: $json_input" >> "$DEBUG_LOG" 2>&1
    # Tentar salvar mesmo assim como fallback
    json_input="{\"raw_input\":\"$(echo "$json_input" | sed 's/"/\\"/g')\"}"
fi

# Criar carimbo de data/hora ISO 8601
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
timestamp_readable=$(date '+%Y-%m-%d %H:%M:%S')

# Extrair hook_event_name se disponível, senão detectar baseado no conteúdo
hook_event_name=$(echo "$json_input" | jq -r '.hook_event_name // empty')

# Detectar o tipo de hook baseado no conteúdo do JSON se hook_event_name não estiver disponível
hook_type="unknown"
event_data="{}"

if [ -n "$hook_event_name" ]; then
    # Se hook_event_name está disponível, usar ele
    hook_type="$hook_event_name"
else
    # Caso contrário, detectar baseado no conteúdo (backward compatibility)
    if echo "$json_input" | jq -e '.prompt' > /dev/null 2>&1; then
        hook_type="beforeSubmitPrompt"
    elif echo "$json_input" | jq -e '.duration_ms' > /dev/null 2>&1; then
        hook_type="afterAgentThought"
    elif echo "$json_input" | jq -e '.text' > /dev/null 2>&1; then
        hook_type="afterAgentResponse"
    elif echo "$json_input" | jq -e '.command' > /dev/null 2>&1 && echo "$json_input" | jq -e '.output' > /dev/null 2>&1; then
        hook_type="afterShellExecution"
    elif echo "$json_input" | jq -e '.tool_name' > /dev/null 2>&1 && echo "$json_input" | jq -e '.result_json' > /dev/null 2>&1; then
        hook_type="afterMCPExecution"
    elif echo "$json_input" | jq -e '.file_path' > /dev/null 2>&1 && echo "$json_input" | jq -e '.edits' > /dev/null 2>&1; then
        hook_type="afterFileEdit"
    elif echo "$json_input" | jq -e '.status' > /dev/null 2>&1; then
        hook_type="stop"
    fi
fi

# Extrair dados específicos do evento (preservar estrutura original para session.json)
# IMPORTANTE: afterAgentThought tem duration_ms, afterAgentResponse não tem
if [ "$hook_type" = "beforeSubmitPrompt" ]; then
    event_data=$(echo "$json_input" | jq -c '{prompt: .prompt, attachments: (.attachments // [])}')
elif [ "$hook_type" = "afterAgentThought" ]; then
    event_data=$(echo "$json_input" | jq -c '{text: (.text // ""), duration_ms: .duration_ms}')
elif [ "$hook_type" = "afterAgentResponse" ]; then
    event_data=$(echo "$json_input" | jq -c '{text: .text}')
elif [ "$hook_type" = "afterShellExecution" ]; then
    event_data=$(echo "$json_input" | jq -c '{command: .command, cwd: (.cwd // ""), output: .output, duration: .duration}')
elif [ "$hook_type" = "afterMCPExecution" ]; then
    event_data=$(echo "$json_input" | jq -c '{tool_name: .tool_name, tool_input: .tool_input, result_json: .result_json, duration: .duration}')
elif [ "$hook_type" = "afterFileEdit" ]; then
    event_data=$(echo "$json_input" | jq -c '{file_path: .file_path, edits: .edits}')
elif [ "$hook_type" = "stop" ]; then
    event_data=$(echo "$json_input" | jq -c '{status: .status, loop_count: .loop_count}')
else
    # Fallback: armazenar JSON completo
    event_data="$json_input"
fi

# Criar o diretório se ele não existir
mkdir -p "$(dirname "$SESSION_FILE")"

# Criar objeto de evento estruturado
event_json=$(jq -n \
    --arg type "$hook_type" \
    --arg timestamp "$timestamp" \
    --argjson data "$event_data" \
    '{type: $type, timestamp: $timestamp, data: $data}')

# Se o arquivo não existe ou está vazio, criar array vazio
if [ ! -f "$SESSION_FILE" ] || [ ! -s "$SESSION_FILE" ]; then
    echo "[]" > "$SESSION_FILE"
fi

# Adicionar evento ao array JSON
# Usar arquivo temporário para garantir atomicidade
temp_file="${SESSION_FILE}.tmp"
jq_error=$(jq --argjson event "$event_json" '. + [$event]' "$SESSION_FILE" > "$temp_file" 2>&1)
jq_exit_code=$?

# Se jq falhou, tentar adicionar manualmente
if [ $jq_exit_code -ne 0 ] || [ ! -s "$temp_file" ]; then
    echo "[$timestamp_readable] ERRO jq: $jq_error" >> "$DEBUG_LOG" 2>&1
    echo "[$timestamp_readable] Tentando fallback - adicionando como linha JSON" >> "$DEBUG_LOG" 2>&1
    
    # Fallback: adicionar como linha JSON (formato mais simples)
    # Se o arquivo não é um array válido, criar um novo
    if ! jq . "$SESSION_FILE" > /dev/null 2>&1; then
        echo "[]" > "$SESSION_FILE"
    fi
    echo "$event_json" >> "$SESSION_FILE"
else
    mv "$temp_file" "$SESSION_FILE"
    echo "[$timestamp_readable] Hook: $hook_type - Evento registrado com sucesso em $SESSION_FILE" >> "$DEBUG_LOG" 2>&1
fi

# Se for afterAgentResponse, também salvar em sessions.json organizado por sessão
if [ "$hook_type" = "afterAgentResponse" ]; then
    # Extrair conversation_id se disponível (pode vir no JSON de entrada)
    conversation_id=$(echo "$json_input" | jq -r '.conversation_id // empty')
    
    # Se não tiver conversation_id no input, tentar extrair do último evento stop
    if [ -z "$conversation_id" ] && [ -f "$SESSION_FILE" ]; then
        conversation_id=$(jq -r '[.[] | select(.type == "stop") | .data.conversation_id] | last // empty' "$SESSION_FILE" 2>/dev/null)
    fi
    
    # Se ainda não tiver, usar timestamp como identificador temporário
    if [ -z "$conversation_id" ]; then
        conversation_id="session-$(date +%s)"
    fi
    
    # Criar ou atualizar sessions.json
    if [ ! -f "$SESSIONS_FILE" ]; then
        echo '{"sessions": []}' > "$SESSIONS_FILE"
    fi
    
    # Adicionar evento à sessão correspondente
    temp_sessions="${SESSIONS_FILE}.tmp"
    jq --arg cid "$conversation_id" \
       --argjson event "$event_json" \
       '.sessions |= (
           if any(.[]; .session_id == $cid) then
               map(if .session_id == $cid then .events += [$event] else . end)
           else
               . + [{
                   session_id: $cid,
                   start_time: $event.timestamp,
                   end_time: $event.timestamp,
                   status: "active",
                   events: [$event]
               }]
           end
       )' "$SESSIONS_FILE" > "$temp_sessions" 2>/dev/null
    
    if [ $? -eq 0 ] && [ -s "$temp_sessions" ]; then
        mv "$temp_sessions" "$SESSIONS_FILE"
        echo "[$timestamp_readable] Evento afterAgentResponse também salvo em $SESSIONS_FILE (sessão: $conversation_id)" >> "$DEBUG_LOG" 2>&1
    fi
fi

# Chamar db-manager.sh para inserir no SQLite
# Passar o JSON completo via stdin para preservar todos os metadados
DB_MANAGER="${SCRIPT_DIR}/db-manager.sh"
if [ -f "$DB_MANAGER" ] && [ -x "$DB_MANAGER" ]; then
    # Garantir que hook_event_name está presente no JSON antes de passar para db-manager
    # Se já existe, manter o valor original; senão, usar o detectado
    json_for_db=$(echo "$json_input" | jq --arg hook_name "$hook_type" 'if .hook_event_name then . else . + {hook_event_name: $hook_name} end')
    echo "$json_for_db" | "$DB_MANAGER" 2>>"$DEBUG_LOG"
    db_exit_code=$?
    if [ $db_exit_code -ne 0 ]; then
        echo "[$timestamp_readable] AVISO: Falha ao inserir no banco SQLite (código: $db_exit_code)" >> "$DEBUG_LOG" 2>&1
    fi
else
    echo "[$timestamp_readable] AVISO: db-manager.sh não encontrado ou não executável" >> "$DEBUG_LOG" 2>&1
fi

# Sair com sucesso
exit 0
