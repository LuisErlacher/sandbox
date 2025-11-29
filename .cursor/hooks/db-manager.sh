#!/bin/bash

# db-manager.sh - Script para gerenciar inserções no banco SQLite de hooks do Cursor
# Recebe eventos via stdin (JSON completo com metadados + dados específicos)

# Obter o diretório absoluto do script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Detectar PROJECT_ROOT (mesma lógica do session-collector.sh)
if [ -n "$PWD" ] && [[ "$PWD" == *"/.cursor" ]]; then
    PROJECT_ROOT="$(cd "$PWD/.." && pwd)"
elif [ -n "$PWD" ] && [[ "$PWD" != *"/.cursor"* ]]; then
    if [ -d "$PWD/.cursor" ]; then
        PROJECT_ROOT="$PWD"
    else
        PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
    fi
else
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

DB_FILE="${PROJECT_ROOT}/.cursor/database/cursor_hooks.db"
SCHEMA_FILE="${PROJECT_ROOT}/.cursor/database/database-schema.sql"
DEBUG_LOG="${HOME}/.cursor/hooks-debug.log"

# Criar diretório do banco se não existir
mkdir -p "$(dirname "$DB_FILE")"

# Função para inicializar o schema
init_schema() {
    if [ ! -f "$DB_FILE" ] || [ ! -s "$DB_FILE" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Inicializando schema do banco de dados..." >> "$DEBUG_LOG" 2>&1
        sqlite3 "$DB_FILE" < "$SCHEMA_FILE" 2>>"$DEBUG_LOG"
        if [ $? -eq 0 ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Schema inicializado com sucesso" >> "$DEBUG_LOG" 2>&1
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERRO ao inicializar schema" >> "$DEBUG_LOG" 2>&1
            return 1
        fi
    fi
    return 0
}

# Função para executar SQL e capturar erros
execute_sql() {
    local sql="$1"
    local error_output=$(sqlite3 "$DB_FILE" "$sql" 2>&1)
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERRO SQL: $error_output" >> "$DEBUG_LOG" 2>&1
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] SQL: $sql" >> "$DEBUG_LOG" 2>&1
    fi
    return $exit_code
}

# Ler JSON do stdin
json_input=$(cat)

# Verificar se recebeu entrada
if [ -z "$json_input" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERRO: Nenhuma entrada recebida no stdin (db-manager.sh)" >> "$DEBUG_LOG" 2>&1
    exit 1
fi

# Verificar se é JSON válido
if ! echo "$json_input" | jq . > /dev/null 2>&1; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERRO: JSON inválido recebido (db-manager.sh): ${json_input:0:200}" >> "$DEBUG_LOG" 2>&1
    exit 1
fi

# Inicializar schema se necessário
if ! init_schema; then
    exit 1
fi

# Extrair metadados globais
conversation_id=$(echo "$json_input" | jq -r '.conversation_id // empty')
generation_id=$(echo "$json_input" | jq -r '.generation_id // empty')
model=$(echo "$json_input" | jq -r '.model // empty')
user_email=$(echo "$json_input" | jq -r '.user_email // empty')
cursor_version=$(echo "$json_input" | jq -r '.cursor_version // empty')
hook_event_name=$(echo "$json_input" | jq -r '.hook_event_name // empty')
workspace_roots=$(echo "$json_input" | jq -c '.workspace_roots // []')

# Criar timestamp ISO 8601
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Se não tiver conversation_id ou generation_id, não podemos inserir
if [ -z "$conversation_id" ] || [ -z "$generation_id" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] AVISO: Evento sem conversation_id ou generation_id, ignorando inserção no banco" >> "$DEBUG_LOG" 2>&1
    exit 0
fi

# Extrair dados específicos do evento (remover metadados globais)
event_data_json=$(echo "$json_input" | jq -c 'del(.conversation_id, .generation_id, .model, .user_email, .cursor_version, .hook_event_name, .workspace_roots)')

# Determinar event_type baseado no hook_event_name
event_type="$hook_event_name"

# Escapar strings para SQL (substituir ' por '')
conversation_id_escaped=$(echo "$conversation_id" | sed "s/'/''/g")
generation_id_escaped=$(echo "$generation_id" | sed "s/'/''/g")
user_email_escaped=$(echo "$user_email" | sed "s/'/''/g")
cursor_version_escaped=$(echo "$cursor_version" | sed "s/'/''/g")
hook_event_name_escaped=$(echo "$hook_event_name" | sed "s/'/''/g")
model_escaped=$(echo "$model" | sed "s/'/''/g")
event_type_escaped=$(echo "$event_type" | sed "s/'/''/g")
event_data_json_escaped=$(echo "$event_data_json" | sed "s/'/''/g")

# Extrair status do evento stop se aplicável
stop_status=""
if [ "$hook_event_name" = "stop" ]; then
    stop_status=$(echo "$json_input" | jq -r '.status // ""' | sed "s/'/''/g")
fi

# Criar arquivo SQL temporário para execução segura
SQL_TEMP=$(mktemp)
cat > "$SQL_TEMP" <<EOF
BEGIN TRANSACTION;

-- Criar ou atualizar registro em conversations
INSERT OR IGNORE INTO conversations (conversation_id, user_email, cursor_version, start_time, status)
VALUES ('$conversation_id_escaped', '$user_email_escaped', '$cursor_version_escaped', '$timestamp', 'active');

-- Se for evento 'stop', atualizar end_time e status da conversation
EOF

if [ "$hook_event_name" = "stop" ] && [ -n "$stop_status" ]; then
    cat >> "$SQL_TEMP" <<EOF
UPDATE conversations 
SET end_time = '$timestamp', 
    status = '$stop_status'
WHERE conversation_id = '$conversation_id_escaped';
EOF
fi

cat >> "$SQL_TEMP" <<EOF

-- Criar ou atualizar registro em generations
INSERT OR IGNORE INTO generations (generation_id, conversation_id, model, start_time, status)
VALUES ('$generation_id_escaped', '$conversation_id_escaped', '$model_escaped', '$timestamp', 'active');

-- Se for evento 'stop', atualizar end_time e status da generation
EOF

if [ "$hook_event_name" = "stop" ] && [ -n "$stop_status" ]; then
    cat >> "$SQL_TEMP" <<EOF
UPDATE generations 
SET end_time = '$timestamp', 
    status = '$stop_status'
WHERE generation_id = '$generation_id_escaped';
EOF
fi

# Inserir workspaces (workspace_roots é um array)
echo "$workspace_roots" | jq -r '.[]' | while read -r workspace_root; do
    workspace_root_escaped=$(echo "$workspace_root" | sed "s/'/''/g")
    echo "INSERT OR IGNORE INTO conversation_workspaces (conversation_id, workspace_root) VALUES ('$conversation_id_escaped', '$workspace_root_escaped');" >> "$SQL_TEMP"
done

cat >> "$SQL_TEMP" <<EOF

-- Inserir evento em events
INSERT INTO events (conversation_id, generation_id, event_type, hook_event_name, model, cursor_version, timestamp, data_json)
VALUES ('$conversation_id_escaped', '$generation_id_escaped', '$event_type_escaped', '$hook_event_name_escaped', '$model_escaped', '$cursor_version_escaped', '$timestamp', '$event_data_json_escaped');

COMMIT;
EOF

# Executar SQL
sqlite3 "$DB_FILE" < "$SQL_TEMP" 2>>"$DEBUG_LOG"
sql_exit_code=$?
rm -f "$SQL_TEMP"

if [ $sql_exit_code -ne 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERRO ao executar transação SQL (código: $sql_exit_code)" >> "$DEBUG_LOG" 2>&1
    exit 1
fi

# Capturar o event_id recém-inserido (usar valores escapados)
event_id=$(sqlite3 "$DB_FILE" "SELECT event_id FROM events WHERE conversation_id = '$conversation_id_escaped' AND generation_id = '$generation_id_escaped' AND timestamp = '$timestamp' ORDER BY event_id DESC LIMIT 1;" 2>/dev/null)

if [ -z "$event_id" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERRO: Não foi possível obter event_id após inserção" >> "$DEBUG_LOG" 2>&1
    exit 1
fi

# Inserir dados específicos na tabela apropriada baseado em hook_event_name
case "$hook_event_name" in
    "afterShellExecution")
        command=$(echo "$json_input" | jq -r '.command // ""')
        cwd=$(echo "$json_input" | jq -r '.cwd // ""')
        output=$(echo "$json_input" | jq -r '.output // ""')
        duration=$(echo "$json_input" | jq -r '.duration // null')
        
        # Escapar aspas para SQL
        command=$(echo "$command" | sed "s/'/''/g")
        cwd=$(echo "$cwd" | sed "s/'/''/g")
        output=$(echo "$output" | sed "s/'/''/g")
        
        if [ "$duration" = "null" ] || [ -z "$duration" ]; then
            duration_sql="NULL"
        else
            duration_sql="$duration"
        fi
        
        execute_sql "INSERT INTO shell_executions (event_id, command, cwd, output, duration) VALUES ($event_id, '$command', '$cwd', '$output', $duration_sql);"
        ;;
        
    "afterFileEdit")
        file_path=$(echo "$json_input" | jq -r '.file_path // ""')
        edits_json=$(echo "$json_input" | jq -c '.edits // []')
        
        # Escapar aspas para SQL
        file_path=$(echo "$file_path" | sed "s/'/''/g")
        edits_json=$(echo "$edits_json" | sed "s/'/''/g")
        
        execute_sql "INSERT INTO file_edits (event_id, file_path, edits_json) VALUES ($event_id, '$file_path', '$edits_json');"
        
        # Inserir detalhes individuais de cada edição
        edit_order=0
        echo "$edits_json" | jq -c '.[]' | while read -r edit; do
            old_string=$(echo "$edit" | jq -r '.old_string // ""')
            new_string=$(echo "$edit" | jq -r '.new_string // ""')
            
            # Escapar aspas para SQL
            old_string=$(echo "$old_string" | sed "s/'/''/g")
            new_string=$(echo "$new_string" | sed "s/'/''/g")
            
            execute_sql "INSERT INTO file_edit_details (event_id, old_string, new_string, edit_order) VALUES ($event_id, '$old_string', '$new_string', $edit_order);"
            edit_order=$((edit_order + 1))
        done
        ;;
        
    "afterAgentResponse")
        text=$(echo "$json_input" | jq -r '.text // ""')
        
        # Escapar aspas para SQL
        text=$(echo "$text" | sed "s/'/''/g")
        
        execute_sql "INSERT INTO agent_responses (event_id, text) VALUES ($event_id, '$text');"
        ;;
        
    "afterAgentThought")
        text=$(echo "$json_input" | jq -r '.text // ""')
        duration_ms=$(echo "$json_input" | jq -r '.duration_ms // 0')
        
        # Escapar aspas para SQL
        text=$(echo "$text" | sed "s/'/''/g")
        
        execute_sql "INSERT INTO agent_thoughts (event_id, text, duration_ms) VALUES ($event_id, '$text', $duration_ms);"
        ;;
        
    "beforeSubmitPrompt")
        prompt_text=$(echo "$json_input" | jq -r '.prompt // ""')
        attachments_json=$(echo "$json_input" | jq -c '.attachments // []')
        
        # Escapar aspas para SQL
        prompt_text=$(echo "$prompt_text" | sed "s/'/''/g")
        attachments_json=$(echo "$attachments_json" | sed "s/'/''/g")
        
        execute_sql "INSERT INTO prompts (event_id, prompt_text, attachments_json) VALUES ($event_id, '$prompt_text', '$attachments_json');"
        ;;
        
    "stop")
        status=$(echo "$json_input" | jq -r '.status // ""')
        loop_count=$(echo "$json_input" | jq -r '.loop_count // 0')
        
        # Escapar aspas para SQL
        status=$(echo "$status" | sed "s/'/''/g")
        
        execute_sql "INSERT INTO generation_stops (event_id, status, loop_count) VALUES ($event_id, '$status', $loop_count);"
        ;;
        
    "afterMCPExecution")
        tool_name=$(echo "$json_input" | jq -r '.tool_name // ""')
        tool_input=$(echo "$json_input" | jq -c '.tool_input // {}')
        result_json=$(echo "$json_input" | jq -c '.result_json // {}')
        duration=$(echo "$json_input" | jq -r '.duration // null')
        
        # Escapar aspas para SQL
        tool_name=$(echo "$tool_name" | sed "s/'/''/g")
        tool_input=$(echo "$tool_input" | sed "s/'/''/g")
        result_json=$(echo "$result_json" | sed "s/'/''/g")
        
        if [ "$duration" = "null" ] || [ -z "$duration" ]; then
            duration_sql="NULL"
        else
            duration_sql="$duration"
        fi
        
        execute_sql "INSERT INTO mcp_executions (event_id, tool_name, tool_input, result_json, duration) VALUES ($event_id, '$tool_name', '$tool_input', '$result_json', $duration_sql);"
        ;;
esac

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Evento inserido no banco: event_id=$event_id, hook=$hook_event_name, conversation=$conversation_id, generation=$generation_id" >> "$DEBUG_LOG" 2>&1

exit 0

