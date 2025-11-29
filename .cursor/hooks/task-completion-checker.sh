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

# Verificar fase atual do projeto (planejamento vs implementação)
PHASE_DETECTION=""
IS_PHASE_4=false

# Prioridade 1: Verificar se sprint-status.yaml existe (indica Phase 4 iniciada)
if [ -f "$SPRINT_STATUS_FILE" ]; then
    PHASE_DETECTION="PHASE_4_IMPLEMENTATION"
    IS_PHASE_4=true
# Prioridade 2: Verificar workflow-status.yaml para identificar fase
elif [ -f "$WORKFLOW_STATUS_FILE" ]; then
    # Verificar se sprint-planning está completo ou em progresso
    if grep -qE "sprint-planning:.*docs/sprint|sprint-planning:.*required" "$WORKFLOW_STATUS_FILE"; then
        PHASE_DETECTION="PHASE_4_IMPLEMENTATION"
        IS_PHASE_4=true
    # Verificar se estamos em planejamento/solutioning (Phase 1-3)
    elif grep -qE "prd:|create-architecture:|create-epics-and-stories:|implementation-readiness:" "$WORKFLOW_STATUS_FILE"; then
        # Verificar se implementation-readiness está completo (indica pronto para Phase 4)
        if grep -qE "implementation-readiness:.*\.md" "$WORKFLOW_STATUS_FILE"; then
            PHASE_DETECTION="PHASE_4_READY"
            IS_PHASE_4=true
        else
            PHASE_DETECTION="PHASE_1_3_PLANNING_SOLUTIONING"
            IS_PHASE_4=false
        fi
    else
        PHASE_DETECTION="UNKNOWN"
        IS_PHASE_4=false
    fi
else
    PHASE_DETECTION="NO_STATUS_FILE"
    IS_PHASE_4=false
fi

# Criar prompt para o agente avaliar e gerar followup_message
analysis_prompt=$(cat <<EOF
Você é um avaliador de conclusão de tarefas especializado no BMad Method. Analise o contexto abaixo e determine se a tarefa foi concluída ou se precisa continuar.

**CRÍTICO: DETECÇÃO DE FASE DO PROJETO**

Fase detectada: ${PHASE_DETECTION}
É Phase 4 (Implementação): ${IS_PHASE_4}

**REGRAS DE REACIONAMENTO BASEADAS NA FASE:**

1. **FASE 1-3 (PLANEJAMENTO/SOLUTIONING) - NÃO REACIONAR:**
   - Se estamos em fase de planejamento (PRD, arquitetura, epics) ou solutioning
   - Se o agente está fazendo perguntas e esperando resposta humana (human-in-the-loop)
   - Se o agente está coletando informações para documentação
   - Se o agente está esperando aprovação ou decisão do usuário
   - Se o agente está apresentando opções ou solicitando escolha do usuário
   - Se o agente está criando documentos e aguardando feedback
   - **AÇÃO:** Retorne "finish": true, "followup_message": "", "reason": "Agente está em fase de planejamento/solutioning aguardando input humano. Não deve ser reacionado automaticamente."
   - **EXCEÇÃO:** Apenas reacionar se foi explicitamente solicitado desenvolvimento de código/documentação técnica específica durante planejamento (ex: "crie a API agora", "implemente essa função")

2. **FASE 4 (IMPLEMENTAÇÃO) - REACIONAR APENAS PARA DESENVOLVIMENTO:**
   - Se existe sprint-status.yaml (indica Phase 4 iniciada)
   - Se há stories/epics documentados prontos para desenvolvimento
   - Se foi solicitado desenvolvimento específico de código, correções, debug, features pequenas
   - Se foi solicitado documentação técnica de código existente
   - **AÇÃO:** Avalie se a tarefa de desenvolvimento foi concluída e reacionar se necessário
   - **NÃO reacionar se:** O agente está aguardando input humano mesmo em Phase 4 (ex: perguntando sobre decisões técnicas, aguardando aprovação de mudanças)

3. **TAREFAS ESPECÍFICAS DE DESENVOLVIMENTO (sempre reacionar se não completa):**
   - Desenvolvimento de código (APIs, componentes, features)
   - Correção de bugs
   - Debug de problemas
   - Implementação de features pequenas
   - Documentação técnica de código
   - Testes de código
   - Refatoração

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
   - Indica se estamos em Phase 1-3 (planejamento) ou Phase 4 (implementação)

3. **Sprint Status File:** ${SPRINT_STATUS_FILE}
   - Status detalhado das stories e épicos em desenvolvimento
   - Existe apenas na Phase 4 (implementação)

INSTRUÇÕES PARA AVALIAÇÃO:

**PASSO 1: DETERMINAR TIPO DE TAREFA**

Analise o prompt inicial e identifique:

A) **Tarefa de Planejamento/Solutioning:**
   - Criar PRD, arquitetura, epics, stories
   - Coletar requisitos
   - Fazer perguntas ao usuário
   - Documentar decisões
   - **DECISÃO:** Se o agente está fazendo perguntas ou esperando input humano → finish=true, não reacionar

B) **Tarefa de Desenvolvimento (Phase 4):**
   - Desenvolver story específica
   - Desenvolver épico completo
   - Implementar código
   - Corrigir bugs
   - Debug
   - Features pequenas
   - Documentação técnica de código
   - **DECISÃO:** Avaliar conclusão e reacionar se necessário

C) **Tarefa Específica de Código (qualquer fase):**
   - Criar API, componente, função específica
   - Corrigir bug específico
   - Implementar feature específica
   - Refatorar código específico
   - **DECISÃO:** Avaliar conclusão e reacionar se necessário

**PASSO 2: VERIFICAR ESTADO DO SISTEMA**

1. **Se existe sprint-status.yaml:**
   - Estamos em Phase 4 (implementação)
   - Verifique status das stories/epics solicitados
   - Reacionar apenas se desenvolvimento não está completo

2. **Se NÃO existe sprint-status.yaml mas existe workflow-status:**
   - Verifique qual é o próximo workflow
   - Se é workflow de planejamento (prd, architecture, epics) → NÃO reacionar se agente está aguardando input
   - Se é workflow de implementação → avaliar conclusão

3. **Se não há arquivos de status:**
   - Avaliar apenas se a tarefa específica foi concluída
   - Reacionar apenas para tarefas de desenvolvimento/código

**PASSO 3: DETECTAR SE AGENTE ESTÁ AGUARDANDO INPUT HUMANO**

Sinais de que o agente está aguardando input humano (NÃO reacionar):
- Fazendo perguntas ao usuário (ex: "Qual tecnologia você prefere?", "Qual é o objetivo principal?")
- Solicitando aprovação ou decisão (ex: "Você aprova esta abordagem?", "Qual opção você prefere?")
- Esperando informações adicionais (ex: "Preciso saber mais sobre...", "Você pode me fornecer...")
- Coletando requisitos (ex: "Quais são os requisitos?", "Descreva o comportamento esperado")
- Apresentando opções para escolha (ex: "Opção 1... Opção 2... Qual você prefere?")
- Solicitando feedback sobre documentos criados (ex: "Revise o PRD e me diga se está correto")
- Apresentando análise e aguardando decisão (ex: "Analisei e encontrei... O que você prefere fazer?")
- Criando documentos e aguardando revisão/aprovação

**REGRAS DE REACIONAMENTO:**
- **Se detectar esses sinais durante Phase 1-3 → finish=true, não reacionar (SEM EXCEÇÕES)**
- **Se detectar esses sinais durante Phase 4 → finish=true, não reacionar (aguardar resposta humana)**
- **Apenas reacionar se:** Não há sinais de espera por input humano E há trabalho de desenvolvimento pendente

**PASSO 4: AVALIAR CONCLUSÃO DA TAREFA**

**Para tarefas de DESENVOLVIMENTO (Phase 4 ou código específico):**

A) **Desenvolvimento de STORY específica:**
   - Verifique se todos os acceptance criteria foram implementados
   - Verifique se testes foram escritos e estão passando
   - Verifique se código foi revisado (se aplicável)
   - Verifique status em sprint-status.yaml
   - Se story está "done" → finish=true
   - Se story está "in-progress" ou "review" → finish=false, continue desenvolvimento

B) **Desenvolvimento de ÉPICO completo:**
   - Verifique status de todas as stories do épico
   - Se todas as stories estão "done" e retrospective foi feita → finish=true
   - Se há stories pendentes → finish=false, continue desenvolvimento

C) **Tarefas específicas de código:**
   - Verifique se código foi implementado completamente
   - Verifique se testes foram escritos
   - Verifique se documentação foi atualizada (se necessário)
   - Verifique se integração foi testada
   - Se tudo completo → finish=true
   - Se falta algo → finish=false, continue

**PASSO 5: GERAR FOLLOWUP_MESSAGE (apenas se finish=false)**

A mensagem deve ser:
- Específica sobre o que falta fazer
- Acionável (o que fazer agora)
- Não repetir o prompt original
- Focar no próximo passo concreto

Exemplos bons:
- "Complete os testes de integração da story 1-2. Execute os testes e verifique se todos passam antes de marcar como done."
- "A API foi criada mas faltam testes unitários. Escreva testes para todos os endpoints e valide entrada de dados."
- "O épico 1 está quase completo. Falta apenas concluir a story 1-5. Complete a story e execute a retrospective."

Exemplos ruins:
- "Continue o desenvolvimento" (muito genérico)
- "Desenvolva o épico 1" (repetindo prompt original)
- "Faça o que foi pedido" (não acionável)

FORMATO DE RESPOSTA:

Responda APENAS com JSON válido no formato abaixo (sem texto adicional):

{
  "finish": true ou false,
  "followup_message": "sua mensagem aqui (obrigatório se finish=false, vazio se finish=true)",
  "reason": "motivo da decisão de não continuar (obrigatório se finish=true, omitir se finish=false)"
}

IMPORTANTE:
- **finish**: boolean que indica se a tarefa foi concluída completamente
  - true = tarefa concluída OU agente aguardando input humano em planejamento
  - false = tarefa não concluída e precisa continuar desenvolvimento
- **followup_message**: 
  - Se finish=false: mensagem específica e útil orientando o que fazer a seguir
  - Se finish=true: string vazia ""
- **reason**: 
  - Se finish=true: motivo detalhado da decisão (obrigatório)
  - Se finish=false: omitir este campo ou usar null
- **NÃO reacionar durante Phase 1-3 quando agente está aguardando input humano**
- **Reacionar apenas para desenvolvimento de código, correções, features, documentação técnica**
- A mensagem será enviada automaticamente como próxima mensagem do usuário apenas se finish=false
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
