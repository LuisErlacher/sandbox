#!/bin/bash

# task-completion-checker.sh - Verifica se task foi concluída usando Cursor CLI headless
# Executado no hook 'stop' para analisar se a resposta do agente completa o prompt inicial

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
DEBUG_LOG="${HOME}/.cursor/hooks-debug.log"
CURSOR_AGENT_TIMEOUT=60  # Timeout em segundos para execução do cursor-agent

# Função para buscar CURSOR_API_KEY de diferentes fontes
get_cursor_api_key() {
    local api_key=""
    
    # 1. Tentar variável de ambiente direta
    if [ -n "$CURSOR_API_KEY" ]; then
        api_key="$CURSOR_API_KEY"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] CURSOR_API_KEY encontrada em variável de ambiente" >> "$DEBUG_LOG" 2>&1
        echo "$api_key"
        return 0
    fi
    
    # 1.5. TESTE TEMPORÁRIO: Chave hardcoded para testes (REMOVER EM PRODUÇÃO)
    # TODO: Remover esta chave após testes
    local test_api_key="key_8704ca6515a950e3e9dd5615c0500976ce340ec3d179309812a00a46fac3f4f6"
    if [ -n "$test_api_key" ]; then
        api_key="$test_api_key"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] AVISO: Usando chave de teste hardcoded (REMOVER EM PRODUÇÃO)" >> "$DEBUG_LOG" 2>&1
        echo "$api_key"
        return 0
    fi
    
    # 2. Tentar buscar de secrets do Cloud Agents (disponíveis como variáveis de ambiente)
    # Cloud Agents disponibiliza secrets como variáveis de ambiente
    # Verificar se estamos em um cloud agent (indicadores comuns)
    if [ -n "$CLOUD_AGENT" ] || [ -n "$CURSOR_CLOUD_AGENT" ] || [ -f "/.cursor-cloud-agent" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Ambiente Cloud Agent detectado" >> "$DEBUG_LOG" 2>&1
        
        # Tentar buscar de variáveis de ambiente comuns para secrets
        # Cloud Agents disponibiliza secrets como variáveis de ambiente com o mesmo nome
        if [ -n "${CURSOR_API_KEY:-}" ]; then
            api_key="${CURSOR_API_KEY}"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] CURSOR_API_KEY encontrada em secrets do Cloud Agent" >> "$DEBUG_LOG" 2>&1
            echo "$api_key"
            return 0
        fi
    fi
    
    # 3. Tentar buscar de arquivo de configuração local (se existir)
    local config_file="${PROJECT_ROOT}/.cursor/api-key.txt"
    if [ -f "$config_file" ] && [ -r "$config_file" ]; then
        api_key=$(cat "$config_file" | tr -d '[:space:]')
        if [ -n "$api_key" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] CURSOR_API_KEY encontrada em arquivo de configuração local" >> "$DEBUG_LOG" 2>&1
            echo "$api_key"
            return 0
        fi
    fi
    
    # 4. Tentar buscar de ~/.cursor/api-key (configuração global do usuário)
    local global_config="${HOME}/.cursor/api-key"
    if [ -f "$global_config" ] && [ -r "$global_config" ]; then
        api_key=$(cat "$global_config" | tr -d '[:space:]')
        if [ -n "$api_key" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] CURSOR_API_KEY encontrada em configuração global do usuário" >> "$DEBUG_LOG" 2>&1
            echo "$api_key"
            return 0
        fi
    fi
    
    # Não encontrou em nenhuma fonte
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] CURSOR_API_KEY não encontrada em nenhuma fonte" >> "$DEBUG_LOG" 2>&1
    echo ""
    return 1
}

# Ler JSON do stdin (hook stop)
json_input=$(cat)

# Log inicial
echo "[$(date '+%Y-%m-%d %H:%M:%S')] === task-completion-checker.sh executado ===" >> "$DEBUG_LOG" 2>&1

# Verificar se recebeu entrada
if [ -z "$json_input" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERRO: Nenhuma entrada recebida no stdin" >> "$DEBUG_LOG" 2>&1
    echo '{}'
    exit 0
fi

# Verificar se é JSON válido
if ! echo "$json_input" | jq . > /dev/null 2>&1; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERRO: JSON inválido recebido" >> "$DEBUG_LOG" 2>&1
    echo '{}'
    exit 0
fi

# Extrair campos do hook stop
status=$(echo "$json_input" | jq -r '.status // "unknown"')
loop_count=$(echo "$json_input" | jq -r '.loop_count // 0')
generation_id=$(echo "$json_input" | jq -r '.generation_id // empty')
conversation_id=$(echo "$json_input" | jq -r '.conversation_id // empty')

# Se abortado/erro, não verificar conclusão
if [ "$status" = "aborted" ] || [ "$status" = "error" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Status é $status, não verificando conclusão" >> "$DEBUG_LOG" 2>&1
    echo '{}'
    exit 0
fi

# Se não tiver generation_id, não podemos verificar
if [ -z "$generation_id" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] AVISO: Sem generation_id, não é possível verificar conclusão" >> "$DEBUG_LOG" 2>&1
    echo '{}'
    exit 0
fi

# Verificar se banco de dados existe PRIMEIRO (antes de verificar API key)
if [ ! -f "$DB_FILE" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERRO: Banco de dados não encontrado em $DB_FILE" >> "$DEBUG_LOG" 2>&1
    echo '{}'
    exit 0
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Verificando conclusão para generation_id: $generation_id" >> "$DEBUG_LOG" 2>&1
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Banco de dados: $DB_FILE" >> "$DEBUG_LOG" 2>&1

# Buscar prompt inicial (beforeSubmitPrompt) - primeiro evento da generation
prompt_text=$(sqlite3 "$DB_FILE" <<EOF
SELECT p.prompt_text
FROM prompts p
JOIN events e ON p.event_id = e.event_id
WHERE e.generation_id = '$generation_id' 
  AND e.hook_event_name = 'beforeSubmitPrompt'
ORDER BY e.timestamp ASC
LIMIT 1;
EOF
)

prompt_exit_code=$?

# Buscar resposta final (afterAgentResponse) - último evento da generation
agent_response=$(sqlite3 "$DB_FILE" <<EOF
SELECT ar.text
FROM agent_responses ar
JOIN events e ON ar.event_id = e.event_id
WHERE e.generation_id = '$generation_id' 
  AND e.hook_event_name = 'afterAgentResponse'
ORDER BY e.timestamp DESC
LIMIT 1;
EOF
)

response_exit_code=$?

# Log detalhado do que foi encontrado
if [ $prompt_exit_code -eq 0 ] && [ -n "$prompt_text" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ Prompt inicial encontrado (${#prompt_text} caracteres)" >> "$DEBUG_LOG" 2>&1
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Preview prompt: ${prompt_text:0:100}..." >> "$DEBUG_LOG" 2>&1
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✗ Prompt inicial NÃO encontrado (exit_code: $prompt_exit_code)" >> "$DEBUG_LOG" 2>&1
fi

if [ $response_exit_code -eq 0 ] && [ -n "$agent_response" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ Resposta do agente encontrada (${#agent_response} caracteres)" >> "$DEBUG_LOG" 2>&1
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Preview resposta: ${agent_response:0:100}..." >> "$DEBUG_LOG" 2>&1
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✗ Resposta do agente NÃO encontrada (exit_code: $response_exit_code)" >> "$DEBUG_LOG" 2>&1
fi

# Verificar se encontrou prompt e resposta
if [ -z "$prompt_text" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERRO: Prompt inicial não encontrado para generation $generation_id" >> "$DEBUG_LOG" 2>&1
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Verificando eventos disponíveis para esta generation..." >> "$DEBUG_LOG" 2>&1
    sqlite3 "$DB_FILE" <<EOF >> "$DEBUG_LOG" 2>&1
SELECT hook_event_name, COUNT(*) as count 
FROM events 
WHERE generation_id = '$generation_id' 
GROUP BY hook_event_name;
EOF
    echo '{}'
    exit 0
fi

if [ -z "$agent_response" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERRO: Resposta do agente não encontrada para generation $generation_id" >> "$DEBUG_LOG" 2>&1
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Verificando eventos disponíveis para esta generation..." >> "$DEBUG_LOG" 2>&1
    sqlite3 "$DB_FILE" <<EOF >> "$DEBUG_LOG" 2>&1
SELECT hook_event_name, COUNT(*) as count 
FROM events 
WHERE generation_id = '$generation_id' 
GROUP BY hook_event_name;
EOF
    echo '{}'
    exit 0
fi

# Agora que temos os dados, verificar requisitos para análise
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Dados encontrados! Verificando requisitos para análise..." >> "$DEBUG_LOG" 2>&1

# Verificar se cursor-agent está disponível
if ! command -v cursor-agent > /dev/null 2>&1; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERRO: cursor-agent não encontrado no PATH" >> "$DEBUG_LOG" 2>&1
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] PATH atual: $PATH" >> "$DEBUG_LOG" 2>&1
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Pulando verificação de conclusão (cursor-agent necessário)" >> "$DEBUG_LOG" 2>&1
    echo '{}'
    exit 0
fi

# Buscar CURSOR_API_KEY de diferentes fontes
CURSOR_API_KEY=$(get_cursor_api_key)

# Verificar se CURSOR_API_KEY foi encontrada
if [ -z "$CURSOR_API_KEY" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERRO: CURSOR_API_KEY não configurada" >> "$DEBUG_LOG" 2>&1
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Fontes verificadas:" >> "$DEBUG_LOG" 2>&1
    echo "[$(date '+%Y-%m-%d %H:%M:%S')]   1. Variável de ambiente CURSOR_API_KEY" >> "$DEBUG_LOG" 2>&1
    echo "[$(date '+%Y-%m-%d %H:%M:%S')]   2. Secrets do Cloud Agents (se aplicável)" >> "$DEBUG_LOG" 2>&1
    echo "[$(date '+%Y-%m-%d %H:%M:%S')]   3. Arquivo .cursor/api-key.txt (local)" >> "$DEBUG_LOG" 2>&1
    echo "[$(date '+%Y-%m-%d %H:%M:%S')]   4. Arquivo ~/.cursor/api-key (global)" >> "$DEBUG_LOG" 2>&1
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Para usar task-completion-checker:" >> "$DEBUG_LOG" 2>&1
    echo "[$(date '+%Y-%m-%d %H:%M:%S')]   - Configure como variável de ambiente: export CURSOR_API_KEY=your_api_key" >> "$DEBUG_LOG" 2>&1
    echo "[$(date '+%Y-%m-%d %H:%M:%S')]   - Ou adicione como secret no Cloud Agents (Cursor Settings → Cloud Agents → Secrets)" >> "$DEBUG_LOG" 2>&1
    echo "[$(date '+%Y-%m-%d %H:%M:%S')]   - Ou salve em .cursor/api-key.txt ou ~/.cursor/api-key" >> "$DEBUG_LOG" 2>&1
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] RESUMO: Prompt e resposta encontrados, mas análise não pode ser executada sem CURSOR_API_KEY" >> "$DEBUG_LOG" 2>&1
    echo "[$(date '+%Y-%m-%d %H:%M:%S')]   - Prompt encontrado: ${#prompt_text} caracteres" >> "$DEBUG_LOG" 2>&1
    echo "[$(date '+%Y-%m-%d %H:%M:%S')]   - Resposta encontrada: ${#agent_response} caracteres" >> "$DEBUG_LOG" 2>&1
    echo '{}'
    exit 0
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] CURSOR_API_KEY encontrada e configurada (${#CURSOR_API_KEY} caracteres)" >> "$DEBUG_LOG" 2>&1
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Todos os requisitos atendidos, prosseguindo com análise..." >> "$DEBUG_LOG" 2>&1

# Limitar tamanho do prompt e resposta para evitar problemas com cursor-agent
# Manter primeiros 8000 caracteres de cada (limite razoável)
prompt_text_limited="${prompt_text:0:8000}"
agent_response_limited="${agent_response:0:8000}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Prompt encontrado (${#prompt_text} chars), Resposta encontrada (${#agent_response} chars)" >> "$DEBUG_LOG" 2>&1

# Criar prompt para cursor-agent
analysis_prompt=$(cat <<EOF
Analise se a resposta do agente abaixo completa satisfatoriamente o prompt do usuário.

PROMPT DO USUÁRIO:
$prompt_text_limited

RESPOSTA DO AGENTE:
$agent_response_limited

Analise se a tarefa foi concluída completamente. Considere:
- Se todos os requisitos do prompt foram atendidos
- Se há tarefas pendentes mencionadas na resposta
- Se a resposta indica conclusão ou necessidade de continuidade
- Se há indicações explícitas de que a tarefa foi finalizada

IMPORTANTE: Se a tarefa NÃO foi concluída (finish: false), você DEVE identificar especificamente o que está faltando ser realizado e criar uma mensagem de follow-up clara e acionável que oriente o agente a continuar de onde parou.

Responda APENAS em JSON válido no formato exato abaixo (sem texto adicional antes ou depois):

Se a tarefa foi concluída:
{
  "finish": true,
  "reason": "explicação breve do motivo"
}

Se a tarefa NÃO foi concluída:
{
  "finish": false,
  "reason": "explicação breve do motivo",
  "missing_tasks": "lista específica e detalhada do que está faltando ser realizado",
  "followup_message": "mensagem clara e acionável para o agente continuar, focando especificamente no que falta fazer. Não repita o prompt original, mas sim indique o que precisa ser completado baseado na análise."
}
EOF
)

# Executar cursor-agent com timeout
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Executando cursor-agent para análise..." >> "$DEBUG_LOG" 2>&1
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Prompt length: ${#analysis_prompt} caracteres" >> "$DEBUG_LOG" 2>&1

# Criar arquivo temporário para capturar stderr separadamente
ERROR_TEMP=$(mktemp)

# Executar cursor-agent passando o prompt como argumento (não via stdin)
# Usar --output-format json para obter resposta estruturada
cursor_output=$(timeout "$CURSOR_AGENT_TIMEOUT" cursor-agent -p --output-format json "$analysis_prompt" 2>"$ERROR_TEMP")
cursor_exit_code=$?

# Capturar stderr para análise
cursor_stderr=$(cat "$ERROR_TEMP" 2>/dev/null)
rm -f "$ERROR_TEMP"

# Log detalhado do que aconteceu
echo "[$(date '+%Y-%m-%d %H:%M:%S')] cursor-agent exit code: $cursor_exit_code" >> "$DEBUG_LOG" 2>&1
if [ -n "$cursor_stderr" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] cursor-agent stderr: ${cursor_stderr:0:500}" >> "$DEBUG_LOG" 2>&1
fi
if [ -n "$cursor_output" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] cursor-agent stdout (primeiros 500 chars): ${cursor_output:0:500}" >> "$DEBUG_LOG" 2>&1
fi

# Verificar se timeout ocorreu
if [ $cursor_exit_code -eq 124 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERRO: cursor-agent timeout após ${CURSOR_AGENT_TIMEOUT}s" >> "$DEBUG_LOG" 2>&1
    echo '{}'
    exit 0
fi

# Verificar se cursor-agent executou com sucesso
if [ $cursor_exit_code -ne 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERRO: cursor-agent falhou (código: $cursor_exit_code)" >> "$DEBUG_LOG" 2>&1
    
    # Verificar se é erro de API/autenticação
    if echo "$cursor_stderr" | grep -qi "api\|error\|unauthorized\|invalid\|key" 2>/dev/null; then
        error_summary=$(echo "$cursor_stderr" | grep -i "warning\|error" | head -1 | sed 's/\x1b\[[0-9;]*m//g' | tr -d '\n' | head -c 200)
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERRO: Erro de API/autenticação do cursor-agent" >> "$DEBUG_LOG" 2>&1
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Resumo do erro: $error_summary" >> "$DEBUG_LOG" 2>&1
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Ação necessária: Verifique se a CURSOR_API_KEY está correta e válida" >> "$DEBUG_LOG" 2>&1
        
        # Se for erro de API key inválida, retornar vazio (não continuar)
        if echo "$cursor_stderr" | grep -qi "invalid.*key\|key.*invalid" 2>/dev/null; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERRO CRÍTICO: API key inválida. Não é possível continuar." >> "$DEBUG_LOG" 2>&1
            echo '{}'
            exit 0
        fi
    fi
    
    # Se houver saída mesmo com erro, tentar usar
    if [ -n "$cursor_output" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] AVISO: cursor-agent retornou erro mas há saída, tentando processar..." >> "$DEBUG_LOG" 2>&1
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERRO: cursor-agent não retornou saída e falhou com código $cursor_exit_code" >> "$DEBUG_LOG" 2>&1
        echo '{}'
        exit 0
    fi
fi

if [ -z "$cursor_output" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERRO: cursor-agent não retornou saída" >> "$DEBUG_LOG" 2>&1
    if [ -n "$cursor_stderr" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] stderr completo: $cursor_stderr" >> "$DEBUG_LOG" 2>&1
    fi
    echo '{}'
    exit 0
fi

# Verificar se a resposta contém erro
if echo "$cursor_output" | jq -e '.is_error == true' > /dev/null 2>&1; then
    error_msg=$(echo "$cursor_output" | jq -r '.error // .result // "Erro desconhecido"' 2>/dev/null)
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERRO: cursor-agent retornou erro no JSON: $error_msg" >> "$DEBUG_LOG" 2>&1
    echo '{}'
    exit 0
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Resposta do cursor-agent recebida (${#cursor_output} chars)" >> "$DEBUG_LOG" 2>&1
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Resposta: ${cursor_output:0:500}" >> "$DEBUG_LOG" 2>&1

# Tentar extrair JSON da resposta do cursor-agent
# O cursor-agent retorna JSON no formato: {"type":"result","result":"...", ...}
# O JSON que queremos pode estar no campo "result" ou diretamente na resposta
json_result=""

# Tentar 1: verificar se a resposta é um objeto JSON com campo "result"
if echo "$cursor_output" | jq -e '.result' > /dev/null 2>&1; then
    result_content=$(echo "$cursor_output" | jq -r '.result // empty')
    
    # Tentar extrair JSON do conteúdo do result
    # O result pode conter texto com JSON embutido em markdown code blocks
    # Extrair conteúdo entre ```json e ``` ou entre ``` e ```
    if echo "$result_content" | grep -q '```json'; then
        # Extrair JSON de bloco markdown com ```json
        json_match=$(echo "$result_content" | sed -n '/```json/,/```/p' | grep -v '```' | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    elif echo "$result_content" | grep -q '```'; then
        # Extrair JSON de bloco markdown genérico ```
        json_match=$(echo "$result_content" | sed -n '/```/,/```/p' | grep -v '```' | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    else
        # Tentar extrair JSON diretamente do texto (sem markdown)
        json_match=$(echo "$result_content" | grep -oP '\{[\s\S]*?"finish"[\s\S]*?\}' | head -1)
    fi
    
    # Validar se o JSON extraído é válido
    if [ -n "$json_match" ] && echo "$json_match" | jq . > /dev/null 2>&1; then
        json_result="$json_match"
    elif echo "$result_content" | jq . > /dev/null 2>&1; then
        # O result já é JSON válido
        json_result="$result_content"
    fi
fi

# Tentar 2: se não encontrou no result, verificar se a resposta completa é JSON válido
if [ -z "$json_result" ] || ! echo "$json_result" | jq -e '.finish' > /dev/null 2>&1; then
    if echo "$cursor_output" | jq . > /dev/null 2>&1; then
        # Tentar usar a resposta completa se for JSON válido
        if echo "$cursor_output" | jq -e '.finish' > /dev/null 2>&1; then
            json_result="$cursor_output"
        fi
    fi
fi

# Tentar 3: extrair JSON de dentro de texto markdown ou texto simples
if [ -z "$json_result" ] || ! echo "$json_result" | jq -e '.finish' > /dev/null 2>&1; then
    # Procurar por bloco JSON no texto completo
    json_match=$(echo "$cursor_output" | grep -oP '\{[\s\S]*"finish"[\s\S]*?\}' | head -1)
    if [ -n "$json_match" ] && echo "$json_match" | jq . > /dev/null 2>&1; then
        json_result="$json_match"
    fi
fi

# Tentar 4: extrair campos diretamente usando grep/sed como último recurso
if [ -z "$json_result" ] || ! echo "$json_result" | jq -e '.finish' > /dev/null 2>&1; then
    finish_value=$(echo "$cursor_output" | grep -i '"finish"' | grep -oP '(true|false)' | head -1)
    reason_value=$(echo "$cursor_output" | grep -i '"reason"' | sed 's/.*"reason"\s*:\s*"\([^"]*\)".*/\1/' | head -1)
    
    if [ -n "$finish_value" ]; then
        json_result=$(jq -n --arg finish "$finish_value" --arg reason "${reason_value:-Sem motivo especificado}" '{finish: ($finish == "true"), reason: $reason}')
    fi
fi

# Verificar se conseguiu extrair resultado válido
if [ -z "$json_result" ] || ! echo "$json_result" | jq . > /dev/null 2>&1; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERRO: Não foi possível extrair JSON válido da resposta do cursor-agent" >> "$DEBUG_LOG" 2>&1
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Resposta completa (primeiros 1000 chars): ${cursor_output:0:1000}" >> "$DEBUG_LOG" 2>&1
    
    # Tentar fallback: assumir que não foi concluído se não conseguir determinar
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Usando fallback: assumindo task não concluída" >> "$DEBUG_LOG" 2>&1
    finish="false"
    reason="Não foi possível analisar conclusão automaticamente"
else
    # Extrair campos do JSON
    finish=$(echo "$json_result" | jq -r '.finish // false')
    reason=$(echo "$json_result" | jq -r '.reason // "Sem motivo especificado"')
    missing_tasks=$(echo "$json_result" | jq -r '.missing_tasks // ""' 2>/dev/null)
    followup_from_agent=$(echo "$json_result" | jq -r '.followup_message // ""' 2>/dev/null)
    
    # Validar que finish é boolean válido
    if [ "$finish" != "true" ] && [ "$finish" != "false" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] AVISO: Valor inválido de finish ($finish), assumindo false" >> "$DEBUG_LOG" 2>&1
        finish="false"
        reason="Valor inválido retornado pelo cursor-agent"
    fi
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Análise concluída: finish=$finish, reason=${reason:0:100}..." >> "$DEBUG_LOG" 2>&1

# Log dos campos adicionais se finish=false
if [ "$finish" = "false" ]; then
    if [ -n "$missing_tasks" ] && [ "$missing_tasks" != "null" ] && [ "$missing_tasks" != "" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] missing_tasks extraído: ${missing_tasks:0:200}..." >> "$DEBUG_LOG" 2>&1
    fi
    if [ -n "$followup_from_agent" ] && [ "$followup_from_agent" != "null" ] && [ "$followup_from_agent" != "" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] followup_message extraído: ${followup_from_agent:0:200}..." >> "$DEBUG_LOG" 2>&1
    fi
fi

# Criar arquivo temporário para armazenar resultado (para workflow-controller.sh ler)
RESULT_TEMP="${HOME}/.cursor/task-checker-result-${generation_id}.json"

# Determinar followup_message baseado no resultado
if [ "$finish" = "true" ]; then
    # Task concluída - retornar followup_message vazio para parar
    result_json='{"followup_message": ""}'
    echo "$result_json" > "$RESULT_TEMP"
    echo "$result_json"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Task concluída, retornando followup_message vazio" >> "$DEBUG_LOG" 2>&1
else
    # Task não concluída - usar análise do cursor-agent para criar followup_message
    # Os campos missing_tasks e followup_from_agent já foram extraídos acima (linha ~447)
    
    if [ -n "$followup_from_agent" ] && [ "$followup_from_agent" != "null" ] && [ "$followup_from_agent" != "" ]; then
        # Usar followup_message gerado pelo cursor-agent
        continuation_prompt="$followup_from_agent"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Usando followup_message do cursor-agent" >> "$DEBUG_LOG" 2>&1
        if [ -n "$missing_tasks" ] && [ "$missing_tasks" != "null" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Tarefas faltantes identificadas: ${missing_tasks:0:200}..." >> "$DEBUG_LOG" 2>&1
        fi
    else
        # Fallback: criar followup baseado na análise do que falta
        if [ -n "$missing_tasks" ] && [ "$missing_tasks" != "null" ] && [ "$missing_tasks" != "" ]; then
            # Usar missing_tasks para criar followup específico
            continuation_prompt="Complete a tarefa. O que está faltando: $missing_tasks"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Criando followup baseado em missing_tasks identificado" >> "$DEBUG_LOG" 2>&1
        else
            # Último fallback: usar reason para criar followup
            if [ -n "$reason" ] && [ "$reason" != "null" ] && [ "$reason" != "" ] && [ "$reason" != "Sem motivo especificado" ]; then
                continuation_prompt="Continue a tarefa. $reason Complete o que está faltando."
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Criando followup baseado em reason" >> "$DEBUG_LOG" 2>&1
            else
                # Fallback final: mensagem genérica
                continuation_prompt="Continue a tarefa. Verifique o que está faltando e complete."
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Usando fallback genérico para followup" >> "$DEBUG_LOG" 2>&1
            fi
        fi
    fi
    
    # Limitar tamanho do followup_message (máximo 2000 caracteres)
    if [ ${#continuation_prompt} -gt 2000 ]; then
        continuation_prompt="${continuation_prompt:0:2000}..."
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Followup truncado para 2000 caracteres" >> "$DEBUG_LOG" 2>&1
    fi
    
    result_json=$(jq -n --arg msg "$continuation_prompt" '{followup_message: $msg}')
    echo "$result_json" > "$RESULT_TEMP"
    echo "$result_json"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Task não concluída, retornando followup_message específico (${#continuation_prompt} caracteres)" >> "$DEBUG_LOG" 2>&1
fi

exit 0

