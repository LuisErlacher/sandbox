# Correções no Hook de Stop - task-completion-checker.sh

## Problemas Identificados

1. **Hook estava usando prompt da generation atual em vez do prompt inicial da conversa**
   - O hook comparava o prompt da generation atual (que pode ser um followup_message anterior) com a resposta do agente
   - Isso causava análise incorreta, pois o prompt original da tarefa era ignorado

2. **Hook não considerava o histórico completo de respostas**
   - Apenas a última resposta da generation atual era analisada
   - Não havia visão do progresso acumulado ao longo de múltiplas iterações

3. **Logs insuficientes para debug**
   - Difícil identificar qual prompt estava sendo usado
   - Não havia indicação clara se estava usando prompt da conversa ou da generation

## Correções Implementadas

### 1. Uso do Prompt Inicial da Conversa

**Antes:**
```bash
# Buscava prompt da generation atual
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
```

**Depois:**
```bash
# Usa o prompt inicial da conversa que já foi buscado anteriormente
if [ -n "$conversation_prompt_text" ]; then
    prompt_text="$conversation_prompt_text"
    echo "✓ Usando prompt inicial da conversa para análise"
else
    # Fallback apenas se não houver prompt da conversa
    prompt_text=$(sqlite3 ...)
fi
```

### 2. Histórico Completo de Respostas

**Antes:**
```bash
# Buscava apenas resposta da generation atual
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
```

**Depois:**
```bash
# Busca TODAS as respostas da conversa
agent_responses_all=$(sqlite3 "$DB_FILE" <<EOF
SELECT GROUP_CONCAT(ar.text, '\n\n--- RESPOSTA ---\n\n')
FROM agent_responses ar
JOIN events e ON ar.event_id = e.event_id
WHERE e.conversation_id = '$conversation_id' 
  AND e.hook_event_name = 'afterAgentResponse'
ORDER BY e.timestamp ASC;
EOF
)
```

### 3. Logs Detalhados

Adicionados logs que mostram:
- Qual prompt está sendo usado (conversa ou generation)
- Quantas respostas foram encontradas
- Se está usando histórico completo ou apenas da generation atual
- Resumo completo dos dados coletados antes da análise

### 4. Prompt de Análise Melhorado

O prompt enviado ao cursor-agent agora:
- Especifica claramente que é o "PROMPT ORIGINAL DO USUÁRIO"
- Indica que está analisando o "HISTÓRICO COMPLETO DE RESPOSTAS"
- Enfatiza análise do progresso TOTAL da conversa

## Como Testar

1. Execute o script de teste:
```bash
bash .cursor/hooks/test-task-checker.sh
```

2. Verifique os logs:
```bash
tail -f ~/.cursor/hooks-debug.log | grep "task-completion-checker"
```

3. Procure por estas mensagens nos logs:
- `✓ Usando prompt inicial da conversa (correto)`
- `✓ Histórico completo de respostas encontrado`
- `Total de respostas na conversa: X`

## Resultado Esperado

Agora o hook deve:
1. ✅ Sempre usar o prompt inicial da conversa para análise
2. ✅ Considerar todas as respostas acumuladas da conversa
3. ✅ Gerar followup_messages mais precisos baseados no progresso real
4. ✅ Evitar loops infinitos com a mesma mensagem genérica

## Próximos Passos

1. Testar com uma conversa real que tenha múltiplas iterações
2. Verificar se o followup_message está sendo gerado corretamente
3. Confirmar que o workflow-controller.sh está lendo o resultado corretamente

