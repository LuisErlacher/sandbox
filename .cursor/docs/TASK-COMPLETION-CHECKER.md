# Task Completion Checker - Verificação Automática de Conclusão de Tasks

## Visão Geral

O `task-completion-checker.sh` é um script que executa automaticamente no hook `stop` do Cursor para verificar se uma task foi concluída comparando o prompt inicial do usuário com a resposta final do agente usando o Cursor CLI headless.

## Funcionamento

### Fluxo de Execução

1. **Hook `stop` é acionado** → recebe JSON com `status`, `loop_count`, `generation_id`
2. **`task-completion-checker.sh` executa**:
   - Extrai `generation_id` do JSON recebido
   - Busca no banco SQLite:
     - Último `beforeSubmitPrompt` da generation (prompt inicial)
     - Último `afterAgentResponse` da generation (resposta final)
   - Cria prompt para análise usando `cursor-agent` CLI
   - Executa `cursor-agent -p --output-format json` com timeout de 60s
   - Processa resposta e extrai JSON com `finish: true|false`
   - Retorna JSON com `followup_message`:
     - Se `finish: true` → `{"followup_message": ""}` (vazio = parar)
     - Se `finish: false` → `{"followup_message": "prompt de continuidade"}`
3. **`workflow-controller.sh` executa**:
   - Lê resultado do `task-completion-checker.sh` de arquivo temporário
   - Valida e retorna `followup_message` para o Cursor
   - Se não houver resultado válido, usa fallback padrão
4. **Cursor processa**:
   - Se `followup_message` vazio → para o loop
   - Se `followup_message` com conteúdo → envia como próxima mensagem

## Arquivos

- **`.cursor/hooks/task-completion-checker.sh`**: Script principal de verificação
- **`.cursor/hooks/workflow-controller.sh`**: Processa resultado e retorna followup_message
- **`.cursor/hooks.json`**: Configuração dos hooks (stop → task-completion-checker → workflow-controller)

## Requisitos

1. **cursor-agent CLI instalado**: `curl https://cursor.com/install -fsS | bash`
2. **CURSOR_API_KEY configurada**: `export CURSOR_API_KEY=your_api_key_here`
3. **Banco SQLite com dados**: O script busca dados do `.cursor/database/cursor_hooks.db`
4. **jq instalado**: Para processamento de JSON

## Tratamento de Erros

O script trata os seguintes casos de erro:

- **Status abortado/erro**: Retorna `{}` sem verificar
- **Sem generation_id**: Retorna `{}` sem verificar
- **cursor-agent não encontrado**: Retorna `{}` sem verificar
- **CURSOR_API_KEY não configurada**: Retorna `{}` sem verificar
- **Banco de dados não encontrado**: Retorna `{}` sem verificar
- **Prompt/resposta não encontrados**: Retorna `{}` sem verificar
- **Timeout do cursor-agent**: Retorna `{}` após 60s
- **Erro de API do cursor-agent**: Retorna `{}` com log de erro
- **JSON inválido retornado**: Usa fallback assumindo `finish: false`

## Logs

Todos os logs são escritos em `~/.cursor/hooks-debug.log` para debug e troubleshooting.

## Limitações

- Prompt e resposta são limitados a 8000 caracteres cada
- Timeout de 60 segundos para execução do cursor-agent
- Máximo de 5 loops automáticos (configurável em `workflow-controller.sh`)

## Exemplo de Uso

O script é executado automaticamente pelo Cursor quando o hook `stop` é acionado. Não é necessário executá-lo manualmente.

Para testar manualmente:

```bash
echo '{"status":"completed","loop_count":0,"generation_id":"<generation_id>"}' | \
  bash .cursor/hooks/task-completion-checker.sh
```

## Configuração

O script está configurado em `.cursor/hooks.json`:

```json
{
  "stop": [
    { "command": "bash .cursor/hooks/session-collector.sh" },
    { "command": "bash .cursor/hooks/task-completion-checker.sh" },
    { "command": "bash .cursor/hooks/workflow-controller.sh" }
  ]
}
```

## Prompt para cursor-agent

O script cria um prompt estruturado pedindo ao cursor-agent para analisar se a resposta completa o prompt inicial:

```
Analise se a resposta do agente abaixo completa satisfatoriamente o prompt do usuário.

PROMPT DO USUÁRIO:
{prompt_text}

RESPOSTA DO AGENTE:
{agent_response}

Analise se a tarefa foi concluída completamente. Considere:
- Se todos os requisitos do prompt foram atendidos
- Se há tarefas pendentes mencionadas na resposta
- Se a resposta indica conclusão ou necessidade de continuidade
- Se há indicações explícitas de que a tarefa foi finalizada

Responda APENAS em JSON válido no formato:
{
  "finish": true ou false,
  "reason": "explicação breve do motivo"
}
```

## Formato de Resposta Esperado

O cursor-agent deve retornar JSON no formato:

```json
{
  "type": "result",
  "result": "{\"finish\": true, \"reason\": \"...\"}"
}
```

O script extrai o JSON do campo `result` e processa o campo `finish` para determinar se deve continuar ou parar.
