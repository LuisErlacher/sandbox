#!/bin/bash

# task-completion-checker.sh - Verifica se task foi concluída usando Cursor CLI headless
# Executado no hook 'stop' para analisar se a resposta do agente completa o prompt inicial

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Detectar PROJECT_ROOT
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
CURSOR_AGENT_TIMEOUT=60

# Função para buscar CURSOR_API_KEY
get_cursor_api_key() {
    if [ -n "$CURSOR_API_KEY" ]; then
        echo "$CURSOR_API_KEY"
        return 0
    fi
    
    # TESTE TEMPORÁRIO: Chave hardcoded (REMOVER EM PRODUÇÃO)
    local test_api_key="key_8704ca6515a950e3e9dd5615c0500976ce340ec3d179309812a00a46fac3f4f6"
    if [ -n "$test_api_key" ]; then
        echo "$test_api_key"
        return 0
    fi
    
    local config_file="${PROJECT_ROOT}/.cursor/api-key.txt"
    if [ -f "$config_file" ] && [ -r "$config_file" ]; then
        cat "$config_file" | tr -d '[:space:]'
        return 0
    fi
    
    local global_config="${HOME}/.cursor/api-key"
    if [ -f "$global_config" ] && [ -r "$global_config" ]; then
        cat "$global_config" | tr -d '[:space:]'
        return 0
    fi
    
    echo ""
    return 1
}

# Ler JSON do stdin
json_input=$(cat)

# Verificar entrada
if [ -z "$json_input" ] || ! echo "$json_input" | jq . > /dev/null 2>&1; then
    echo '{}'
    exit 0
fi

# Extrair campos
status=$(echo "$json_input" | jq -r '.status // "unknown"')
generation_id=$(echo "$json_input" | jq -r '.generation_id // empty')
conversation_id=$(echo "$json_input" | jq -r '.conversation_id // empty')

# Se abortado/erro, não verificar
if [ "$status" = "aborted" ] || [ "$status" = "error" ] || [ -z "$generation_id" ] || [ ! -f "$DB_FILE" ]; then
    echo '{}'
    exit 0
fi

# Buscar prompt inicial da conversa
conversation_prompt=""
if [ -n "$conversation_id" ]; then
    conversation_prompt=$(sqlite3 "$DB_FILE" <<EOF
SELECT p.prompt_text
FROM prompts p
JOIN events e ON p.event_id = e.event_id
WHERE e.conversation_id = '$conversation_id' 
  AND e.hook_event_name = 'beforeSubmitPrompt'
ORDER BY e.timestamp ASC
LIMIT 1;
EOF
)
fi

# Usar prompt inicial da conversa ou fallback para generation atual
prompt_text="$conversation_prompt"
if [ -z "$prompt_text" ]; then
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
fi

# Buscar histórico completo de respostas da conversa
agent_response=""
if [ -n "$conversation_id" ]; then
    agent_response=$(sqlite3 "$DB_FILE" <<EOF
SELECT GROUP_CONCAT(ar.text, '\n\n--- RESPOSTA ---\n\n')
FROM agent_responses ar
JOIN events e ON ar.event_id = e.event_id
WHERE e.conversation_id = '$conversation_id' 
  AND e.hook_event_name = 'afterAgentResponse'
ORDER BY e.timestamp ASC;
EOF
)
fi

# Fallback: buscar resposta da generation atual
if [ -z "$agent_response" ] || [ "$agent_response" = "NULL" ]; then
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
fi

# Verificar se tem dados necessários
if [ -z "$prompt_text" ] || [ -z "$agent_response" ]; then
    echo '{}'
    exit 0
fi

# Verificar requisitos
if ! command -v cursor-agent > /dev/null 2>&1; then
    echo '{}'
    exit 0
fi

CURSOR_API_KEY=$(get_cursor_api_key)
if [ -z "$CURSOR_API_KEY" ]; then
    echo '{}'
    exit 0
fi

# Limitar tamanho (8000 caracteres cada)
prompt_text_limited="${prompt_text:0:8000}"
agent_response_limited="${agent_response:0:8000}"

# Determinar path do sprint-artifacts
SPRINT_ARTIFACTS_PATH="${PROJECT_ROOT}/docs/sprint-artifacts"
WORKFLOW_STATUS_FILE="${PROJECT_ROOT}/docs/bmm-workflow-status.yaml"
SPRINT_STATUS_FILE="${SPRINT_ARTIFACTS_PATH}/sprint-status.yaml"

# Criar prompt para o agente avaliar e gerar followup_message
analysis_prompt=$(cat <<EOF
Você é um avaliador de conclusão de tarefas. Analise o contexto abaixo e determine se a tarefa foi concluída ou se precisa continuar.

CONTEXTO:

PROMPT INICIAL DO USUÁRIO (início da conversa):
$prompt_text_limited

HISTÓRICO COMPLETO DE RESPOSTAS DO AGENTE (todas as iterações):
$agent_response_limited

RECURSOS DISPONÍVEIS PARA VERIFICAÇÃO DE STATUS:

1. **Sprint Artifacts Path:** ${SPRINT_ARTIFACTS_PATH}
   - Arquivos de status do sprint e stories estão localizados aqui
   - Verifique arquivos como: sprint-status.yaml, stories/*.md

2. **Workflow Status File:** ${WORKFLOW_STATUS_FILE}
   - Arquivo principal de tracking do workflow BMad Method
   - Contém o estado atual do projeto e próximos passos

3. **Sprint Status File:** ${SPRINT_STATUS_FILE}
   - Status detalhado das stories e épicos em desenvolvimento

4. **Comando do Workflow Status:**
   - Use o comando: /command @bmad/bmm/workflows/workflow-status
   - Este comando lê o arquivo de workflow-status e responde "o que fazer agora?"
   - É o master router e status tracker do BMad Method

INSTRUÇÕES PARA AVALIAÇÃO:

1. **Avalie se a tarefa foi concluída:**
   - Verifique se o prompt inicial foi completamente atendido
   - Considere o progresso acumulado ao longo de todas as iterações
   - Se necessário, use o workflow-status para verificar o estado atual:
     * Execute: /command @bmad/bmm/workflows/workflow-status
     * O workflow-status lerá os arquivos de status e indicará o próximo passo
     * Use essa informação para determinar se a tarefa foi finalizada corretamente

2. **Como verificar conclusão usando workflow-status:**
   
   **Comando:** /command @bmad/bmm/workflows/workflow-status
   
   **Como funciona:**
   - O workflow-status é um "lightweight status checker" que responde "what should I do now?"
   - Ele lê o arquivo bmm-workflow-status.yaml localizado em: ${WORKFLOW_STATUS_FILE}
   - O workflow-status identifica o próximo workflow necessário baseado no estado atual
   - Ele verifica quais workflows estão completos (status = caminho do arquivo criado)
   - Ele identifica workflows pendentes (status = required/optional/recommended/conditional)
   - Ele encontra o primeiro workflow não completado e não pulado como próximo passo
   
   **Como verificar se a tarefa foi concluída:**
   - Execute: /command @bmad/bmm/workflows/workflow-status
   - O workflow-status mostrará o status atual e o próximo workflow a ser executado
   - Se não há próximo workflow ou todos estão completos/pulados, a tarefa pode estar concluída
   - O workflow-status também pode verificar sprint-status.yaml para status de stories/épicos
   - Se o workflow-status indicar que não há próximos passos, a tarefa foi finalizada corretamente
   
   **Instruções detalhadas:**
   - As instruções completas de como usar o workflow-status estão em: {project-root}/.bmad/bmm/workflows/workflow-status/instructions.md
   - Essas instruções explicam como o workflow-status lê e interpreta o arquivo de status
   - Use essas instruções para entender como verificar se um workflow foi concluído corretamente

3. **Se a tarefa FOI concluída completamente:**
   - Retorne JSON com "finish": true
   - Retorne JSON com "followup_message": "" (string vazia)
   - Retorne JSON com "reason": "motivo detalhado da decisão de não continuar"
   - O campo "reason" é obrigatório quando finish=true e será usado apenas para auditoria
   - Isso indica que não há necessidade de continuar
   - Confirme que o workflow-status não indica próximos passos pendentes

4. **Se a tarefa NÃO foi concluída ou precisa continuar:**
   - Retorne JSON com "finish": false
   - Retorne JSON com "followup_message" contendo uma mensagem clara e específica
   - NÃO inclua o campo "reason" (ou use null) quando finish=false
   - A mensagem deve orientar o agente sobre o que fazer a seguir
   - NÃO repita o prompt original
   - Foque no que está faltando ou no próximo passo necessário
   - Seja específico e acionável
   
   **IMPORTANTE: Adapte o followup_message ao tipo de solicitação:**
   
   **A) Se foi solicitado desenvolvimento de uma STORY específica:**
   - Gere mensagem focada na conclusão dessa story específica
   - Verifique o status atual da story em: ${SPRINT_STATUS_FILE}
   - Exemplo de followup_message quando story não está completa:
     "Complete o desenvolvimento da story 1-1. Verifique se todos os requisitos da story foram implementados, testes unitários e de integração estão passando, e a documentação foi atualizada. Quando concluir, execute /command @bmad/bmm/workflows/story-done para marcar como done."
   - Exemplo quando story está quase completa mas falta algo:
     "A story 1-2 está quase completa. Faltam apenas os testes de integração com o serviço de autenticação. Complete os testes e execute /command @bmad/bmm/workflows/story-done."
   - Se a story foi completamente desenvolvida e testada, retorne "finish": true, "followup_message": "", e "reason": "motivo detalhado"
   
   **B) Se foi solicitado conclusão de um ÉPICO inteiro:**
   - Gere mensagem focada na conclusão do épico completo
   - Verifique o status de todas as stories do épico em: ${SPRINT_STATUS_FILE}
   - Exemplo de followup_message quando épico não está completo:
     "Continue o desenvolvimento do épico 1. Verifique o status atual em ${SPRINT_STATUS_FILE}. Complete todas as stories pendentes do épico (atualmente faltam: 1-3, 1-4). Quando todas as stories estiverem done, execute a retrospective do épico."
   - Exemplo quando épico está quase completo:
     "O épico 2 está quase completo. Falta apenas concluir a story 2-5 e executar a retrospective. Complete a story e então execute /command @bmad/bmm/workflows/retrospective para finalizar o épico."
   - Se todas as stories do épico estão done e a retrospective foi concluída, retorne "finish": true, "followup_message": "", e "reason": "motivo detalhado"
   
   **C) Se a tarefa NÃO está documentada no processo BMAD (não é story/épico):**
   - Avalie apenas se a solicitação específica foi atendida completamente
   - Considere aspectos como: implementação completa, testes, documentação, integração, deploy, validação, etc.
   - Exemplo 1 - Criar API no backend (não completa):
     "A API foi criada, mas faltam: testes unitários para todos os endpoints, testes de integração, documentação da API (Swagger/OpenAPI), e validação de entrada de dados. Complete esses itens antes de considerar finalizado."
   - Exemplo 2 - Criar API no backend (quase completa):
     "A API foi criada e testada. Falta apenas gerar a documentação Swagger. Gere a documentação da API e então a tarefa estará completa."
   - Exemplo 3 - Corrigir bug (não completo):
     "O bug foi corrigido, mas não há evidência de testes de regressão. Execute testes para garantir que: (1) o problema original não ocorre mais, (2) não foram introduzidos novos problemas, e (3) casos de borda relacionados foram testados."
   - Exemplo 4 - Implementar feature (não completa):
     "A feature foi implementada parcialmente. Faltam: integração com o sistema de autenticação, tratamento completo de erros, testes end-to-end, e atualização da documentação do sistema."
   - Exemplo 5 - Refatorar código (não completo):
     "O código foi refatorado, mas faltam: testes para garantir que a funcionalidade não foi alterada, atualização da documentação técnica, e validação de performance."
   - Se tudo foi feito corretamente e completamente, retorne "finish": true, "followup_message": "", e "reason": "motivo detalhado"

FORMATO DE RESPOSTA:

Responda APENAS com JSON válido no formato abaixo (sem texto adicional):

{
  "finish": true ou false,
  "followup_message": "sua mensagem aqui (obrigatório se finish=false, vazio se finish=true)",
  "reason": "motivo da decisão de não continuar (obrigatório se finish=true, omitir se finish=false)"
}

IMPORTANTE:
- **finish**: boolean que indica se a tarefa foi concluída completamente
  - true = tarefa concluída, não precisa continuar
  - false = tarefa não concluída, precisa continuar
- **followup_message**: 
  - Se finish=false: mensagem específica e útil orientando o que fazer a seguir
  - Se finish=true: string vazia ""
- **reason**: 
  - Se finish=true: motivo detalhado da decisão de não continuar (para auditoria)
  - Se finish=false: omitir este campo ou usar null
- A mensagem será enviada automaticamente como próxima mensagem do usuário apenas se finish=false
- Quando em dúvida sobre o status, instrua o agente a executar: /command @bmad/bmm/workflows/workflow-status
EOF
)

# Executar cursor-agent
ERROR_TEMP=$(mktemp)
cursor_output=$(timeout "$CURSOR_AGENT_TIMEOUT" cursor-agent -p --output-format json "$analysis_prompt" 2>"$ERROR_TEMP")
cursor_exit_code=$?
cursor_stderr=$(cat "$ERROR_TEMP" 2>/dev/null)
rm -f "$ERROR_TEMP"

# Verificar erros básicos
if [ $cursor_exit_code -eq 124 ] || [ $cursor_exit_code -ne 0 ] || [ -z "$cursor_output" ]; then
    echo '{}'
    exit 0
fi

# Extrair finish, followup_message e reason da resposta do cursor-agent
finish=false
followup_message=""
reason=""
decision_json=""

# Função auxiliar para extrair JSON de markdown code blocks
extract_json_from_markdown() {
    local content="$1"
    if echo "$content" | grep -q '```json'; then
        echo "$content" | sed -n '/```json/,/```/p' | grep -v '```' | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
    elif echo "$content" | grep -q '```'; then
        echo "$content" | sed -n '/```/,/```/p' | grep -v '```' | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
    else
        echo "$content" | grep -oP '\{[\s\S]*?\}' | head -1
    fi
}

# Tentar extrair do campo result
if echo "$cursor_output" | jq -e '.result' > /dev/null 2>&1; then
    result_content=$(echo "$cursor_output" | jq -r '.result // empty')
    json_match=$(extract_json_from_markdown "$result_content")
    
    if [ -n "$json_match" ] && echo "$json_match" | jq . > /dev/null 2>&1; then
        decision_json="$json_match"
    elif echo "$result_content" | jq . > /dev/null 2>&1; then
        decision_json="$result_content"
    fi
fi

# Tentar extrair diretamente da resposta completa
if [ -z "$decision_json" ]; then
    if echo "$cursor_output" | jq -e '.finish' > /dev/null 2>&1; then
        decision_json=$(echo "$cursor_output" | jq -c '{finish: .finish, followup_message: (.followup_message // ""), reason: (.reason // "")}')
    else
        # Tentar extrair JSON do texto completo
        json_match=$(extract_json_from_markdown "$cursor_output")
        if [ -n "$json_match" ] && echo "$json_match" | jq . > /dev/null 2>&1; then
            decision_json="$json_match"
        fi
    fi
fi

# Extrair campos do JSON encontrado
if [ -n "$decision_json" ] && echo "$decision_json" | jq . > /dev/null 2>&1; then
    finish=$(echo "$decision_json" | jq -r '.finish // false' 2>/dev/null)
    followup_message=$(echo "$decision_json" | jq -r '.followup_message // ""' 2>/dev/null)
    reason=$(echo "$decision_json" | jq -r '.reason // ""' 2>/dev/null)
fi

# Normalizar finish (aceitar true/false como string ou boolean)
if [ "$finish" = "true" ] || [ "$finish" = "1" ]; then
    finish=true
else
    finish=false
fi

# Garantir que followup_message e reason são strings (podem ser null)
if [ "$followup_message" = "null" ] || [ -z "$followup_message" ]; then
    followup_message=""
fi
if [ "$reason" = "null" ] || [ -z "$reason" ]; then
    reason=""
fi

# Limitar tamanho (2000 caracteres para followup_message, 5000 para reason)
if [ ${#followup_message} -gt 2000 ]; then
    followup_message="${followup_message:0:2000}"
fi
if [ ${#reason} -gt 5000 ]; then
    reason="${reason:0:5000}"
fi

# Se finish=true, garantir que followup_message está vazio (não deve reacionar o agente)
if [ "$finish" = "true" ]; then
    followup_message=""
fi

# Armazenar decisão no banco de dados quando finish=true (para auditoria)
if [ "$finish" = "true" ] && [ -n "$reason" ] && [ -f "$DB_FILE" ]; then
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Escapar strings para SQL
    conversation_id_escaped=$(echo "$conversation_id" | sed "s/'/''/g")
    generation_id_escaped=$(echo "$generation_id" | sed "s/'/''/g")
    reason_escaped=$(echo "$reason" | sed "s/'/''/g")
    prompt_text_escaped=$(echo "$prompt_text_limited" | sed "s/'/''/g")
    agent_response_summary_escaped=$(echo "${agent_response_limited:0:1000}" | sed "s/'/''/g")
    
    # Criar tabela se não existir (migração automática)
    sqlite3 "$DB_FILE" <<EOF
CREATE TABLE IF NOT EXISTS reexecute_decisions (
    decision_id INTEGER PRIMARY KEY AUTOINCREMENT,
    conversation_id TEXT NOT NULL,
    generation_id TEXT NOT NULL,
    finish BOOLEAN NOT NULL,
    reason TEXT,
    followup_message TEXT,
    prompt_text TEXT,
    agent_response_summary TEXT,
    timestamp TEXT NOT NULL,
    FOREIGN KEY (conversation_id) REFERENCES conversations(conversation_id) ON DELETE CASCADE,
    FOREIGN KEY (generation_id) REFERENCES generations(generation_id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_reexecute_decisions_conversation ON reexecute_decisions(conversation_id);
CREATE INDEX IF NOT EXISTS idx_reexecute_decisions_generation ON reexecute_decisions(generation_id);
CREATE INDEX IF NOT EXISTS idx_reexecute_decisions_finish ON reexecute_decisions(finish);
CREATE INDEX IF NOT EXISTS idx_reexecute_decisions_timestamp ON reexecute_decisions(timestamp);
EOF
    
    # Inserir decisão no banco
    sqlite3 "$DB_FILE" <<EOF
INSERT INTO reexecute_decisions (
    conversation_id,
    generation_id,
    finish,
    reason,
    followup_message,
    prompt_text,
    agent_response_summary,
    timestamp
) VALUES (
    '$conversation_id_escaped',
    '$generation_id_escaped',
    1,
    '$reason_escaped',
    '',
    '$prompt_text_escaped',
    '$agent_response_summary_escaped',
    '$timestamp'
);
EOF
fi

# Criar arquivo temporário para workflow-controller.sh
RESULT_TEMP="${HOME}/.cursor/task-checker-result-${generation_id}.json"
result_json=$(jq -n --arg msg "$followup_message" '{followup_message: $msg}')
echo "$result_json" > "$RESULT_TEMP"

# Retornar resultado
echo "$result_json"
exit 0
