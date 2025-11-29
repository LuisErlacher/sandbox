# Troubleshooting - Sistema de Hooks do Cursor

Este guia cobre problemas comuns e soluções para o sistema de hooks do Cursor, incluindo coleta de sessões, banco de dados e verificação de conclusão de tasks.

## Índice

1. [Hooks não estão salvando dados](#hooks-não-estão-salvando-dados)
2. [Task Completion Checker retorna vazio](#task-completion-checker-retorna-vazio)
3. [Problemas com banco de dados](#problemas-com-banco-de-dados)
4. [Problemas com CURSOR_API_KEY](#problemas-com-cursor_api_key)

---

## Hooks não estão salvando dados

### Verificação 1: Os hooks estão sendo executados?

1. **Monitore os logs em tempo real:**
   ```bash
   tail -f ~/.cursor/hooks-debug.log
   ```

2. **Use o Cursor Agent normalmente** (envie uma mensagem no Agent Chat)

3. **Observe o terminal** - você deve ver logs como:
   ```
   [2025-11-29 XX:XX:XX] === Hook executado ===
   [2025-11-29 XX:XX:XX] Hook: beforeSubmitPrompt - Evento registrado
   ```

**Se NÃO aparecer nenhum log:**
- Os hooks não estão sendo executados pelo Cursor
- Verifique a configuração do Cursor

**Se aparecerem logs:**
- Os hooks estão sendo executados
- Verifique se os dados estão sendo salvos corretamente

### Verificação 2: Configuração do Cursor

1. **Abra o Cursor**
2. **Vá em Configurações** (Ctrl+, ou Cmd+,)
3. **Procure por "Hooks"** na barra de busca
4. **Verifique se os hooks aparecem listados**

Se não aparecerem:
- O Cursor pode não ter carregado o `hooks.json`
- Reinicie o Cursor completamente

### Verificação 3: Verificar erros no Cursor

1. **No Cursor, vá em:**
   - View → Output (ou Ctrl+Shift+U)
2. **Selecione "Hooks" no dropdown**
3. **Verifique se há erros listados**

### Verificação 4: Permissões e caminhos

```bash
# Verificar permissões
ls -la .cursor/hooks/session-collector.sh

# Deve mostrar: -rwxrwxr-x (executável)

# Verificar se o arquivo existe
test -f .cursor/hooks.json && echo "✓ hooks.json existe" || echo "✗ hooks.json NÃO existe"

# Verificar se jq está instalado
which jq || echo "✗ jq NÃO está instalado"
```

### Soluções Comuns

#### Solução 1: Reiniciar o Cursor
1. Feche TODAS as janelas do Cursor
2. Aguarde alguns segundos
3. Abra o Cursor novamente
4. Teste novamente

#### Solução 2: Verificar se está usando o Agent correto
- Os hooks funcionam com **Cursor Agent** (Cmd+K ou Agent Chat)
- NÃO funcionam com Tab (compleções inline) - esses usam hooks diferentes

#### Solução 3: Verificar caminho do hooks.json
O arquivo deve estar em:
- `.cursor/hooks.json` (projeto)
- OU `~/.cursor/hooks.json` (global)

---

## Task Completion Checker retorna vazio

### Diagnóstico

O script pode retornar `{}` vazio por vários motivos. Verifique os logs:

```bash
tail -50 ~/.cursor/hooks-debug.log | grep -E "(task-completion|ERRO|CRÍTICO|CURSOR_API_KEY)"
```

### Causas Comuns

#### 1. CURSOR_API_KEY não configurada ou inválida

**Sintomas:**
```
[timestamp] ERRO: cursor-agent falhou (código: 1)
[timestamp] ERRO: Erro de API/autenticação do cursor-agent
[timestamp] Resumo do erro: ⚠ Warning: The provided API key is invalid.
[timestamp] ERRO CRÍTICO: API key inválida. Não é possível continuar.
```

**Solução:**
1. Verifique se a API key está configurada:
   ```bash
   echo $CURSOR_API_KEY
   ```

2. Para Cloud Agents, configure o secret em:
   - Cursor Settings → Cloud Agents → Secrets
   - Adicione secret com chave `CURSOR_API_KEY`

3. Para ambiente local, configure:
   ```bash
   export CURSOR_API_KEY=sua_api_key_aqui
   ```

4. Verifique se a API key é válida testando manualmente:
   ```bash
   export CURSOR_API_KEY=sua_api_key
   cursor-agent -p "teste"
   ```

#### 2. Prompt ou resposta não encontrados no banco

**Sintomas:**
```
[timestamp] ✗ Prompt inicial NÃO encontrado
[timestamp] ✗ Resposta do agente NÃO encontrada
```

**Solução:**
- Verifique se o `generation_id` existe no banco:
  ```bash
  sqlite3 .cursor/database/cursor_hooks.db \
    "SELECT hook_event_name FROM events WHERE generation_id = 'SEU_GENERATION_ID';"
  ```
- Certifique-se de que `beforeSubmitPrompt` e `afterAgentResponse` foram capturados

#### 3. cursor-agent não encontrado

**Sintomas:**
```
[timestamp] ERRO: cursor-agent não encontrado no PATH
```

**Solução:**
```bash
# Instalar cursor-agent
curl https://cursor.com/install -fsS | bash

# Verificar instalação
which cursor-agent
cursor-agent --version
```

#### 4. Timeout do cursor-agent

**Sintomas:**
```
[timestamp] ERRO: cursor-agent timeout após 60s
```

**Solução:**
- O timeout padrão é 60 segundos
- Se necessário, ajuste `CURSOR_AGENT_TIMEOUT` no script
- Verifique conectividade de rede

---

## Problemas com banco de dados

### Banco de dados não encontrado

**Sintomas:**
```
[timestamp] ERRO: Banco de dados não encontrado em /path/to/db
```

**Solução:**
- Verifique se o banco existe: `ls -la .cursor/database/cursor_hooks.db`
- Certifique-se de que o `session-collector.sh` está executando e salvando dados
- O banco é criado automaticamente na primeira execução

### Verificar dados no banco

```bash
# Contar eventos
sqlite3 .cursor/database/cursor_hooks.db "SELECT COUNT(*) FROM events;"

# Ver últimas conversas
sqlite3 .cursor/database/cursor_hooks.db \
  "SELECT conversation_id, COUNT(*) as eventos FROM events GROUP BY conversation_id ORDER BY eventos DESC LIMIT 5;"

# Verificar uma generation específica
sqlite3 .cursor/database/cursor_hooks.db \
  "SELECT hook_event_name, COUNT(*) FROM events WHERE generation_id = 'SEU_GENERATION_ID' GROUP BY hook_event_name;"
```

---

## Problemas com CURSOR_API_KEY

### Configuração da API Key

O sistema busca a `CURSOR_API_KEY` na seguinte ordem:

1. **Variável de ambiente** `CURSOR_API_KEY`
2. **Secrets do Cloud Agents** (disponíveis como variáveis de ambiente)
3. **Arquivo `.cursor/api-key.txt`** (local do projeto)
4. **Arquivo `~/.cursor/api-key`** (global do usuário)

### Verificar configuração

```bash
# Verificar se está configurada
echo $CURSOR_API_KEY

# Verificar logs para ver de onde foi carregada
tail -20 ~/.cursor/hooks-debug.log | grep CURSOR_API_KEY
```

### Configurar para Cloud Agents

1. No Cursor IDE: **Cursor Settings** (`Ctrl+,`) → guia **Cloud Agents** → seção **Secrets**
2. Na Web: **Cursor Dashboard** → **Cloud Agents** → seção **Secrets**
3. Adicione um secret com a chave `CURSOR_API_KEY` e o valor da sua API key

**Vantagens:**
- Criptografado em repouso usando KMS
- Disponível automaticamente como variável de ambiente
- Compartilhado entre todos os cloud agents do workspace/equipe

### Configurar para ambiente local

```bash
# Opção 1: Variável de ambiente (temporária)
export CURSOR_API_KEY=sua_api_key_aqui

# Opção 2: Arquivo global (persistente)
echo "sua_api_key_aqui" > ~/.cursor/api-key
chmod 600 ~/.cursor/api-key

# Opção 3: Arquivo do projeto (não fazer commit!)
echo "sua_api_key_aqui" > .cursor/api-key.txt
chmod 600 .cursor/api-key.txt
echo ".cursor/api-key.txt" >> .gitignore
```

---

## Teste Manual Completo

### Testar Task Completion Checker

```bash
# 1. Configure a API key
export CURSOR_API_KEY=sua_api_key_valida

# 2. Execute o script com um generation_id válido
echo '{
  "conversation_id": "test-conv",
  "generation_id": "SEU_GENERATION_ID_AQUI",
  "status": "completed",
  "loop_count": 0
}' | bash .cursor/hooks/task-completion-checker.sh

# 3. Verifique os logs
tail -50 ~/.cursor/hooks-debug.log | grep -A 5 "task-completion"
```

### Verificar Status Completo

```bash
#!/bin/bash
echo "=== Verificação do Sistema de Hooks ==="
echo ""
echo "1. CURSOR_API_KEY:"
if [ -n "$CURSOR_API_KEY" ]; then
    echo "   ✅ Configurada (${#CURSOR_API_KEY} caracteres)"
else
    echo "   ❌ Não configurada"
fi
echo ""
echo "2. cursor-agent:"
if command -v cursor-agent > /dev/null 2>&1; then
    echo "   ✅ Instalado: $(cursor-agent --version 2>&1 | head -1)"
else
    echo "   ❌ Não encontrado"
fi
echo ""
echo "3. Banco de dados:"
DB_FILE=".cursor/database/cursor_hooks.db"
if [ -f "$DB_FILE" ]; then
    echo "   ✅ Existe: $DB_FILE"
    COUNT=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM events;" 2>/dev/null)
    echo "   ✅ Eventos no banco: $COUNT"
else
    echo "   ❌ Não encontrado: $DB_FILE"
fi
echo ""
echo "4. Scripts de hooks:"
for script in session-collector.sh task-completion-checker.sh workflow-controller.sh; do
    if [ -f ".cursor/hooks/$script" ]; then
        echo "   ✅ $script"
    else
        echo "   ❌ $script não encontrado"
    fi
done
echo ""
echo "5. Logs recentes:"
tail -10 ~/.cursor/hooks-debug.log 2>/dev/null | grep -E "(ERRO|AVISO)" | tail -5
```

---

## Próximos Passos

1. **Se os hooks não estão executando:**
   - Reinicie o Cursor
   - Verifique `.cursor/hooks.json`
   - Consulte logs em `~/.cursor/hooks-debug.log`

2. **Se a API key está inválida:**
   - Obtenha uma API key válida do Cursor
   - Configure como secret no Cloud Agents ou variável de ambiente
   - Consulte `.cursor/docs/CURSOR-API-KEY-CONFIG.md` para detalhes

3. **Se os dados não estão no banco:**
   - Verifique se `session-collector.sh` está executando
   - Verifique se os hooks estão configurados em `.cursor/hooks.json`
   - Consulte `.cursor/docs/DATABASE.md` para estrutura do banco

4. **Para mais informações:**
   - Consulte `~/.cursor/hooks-debug.log` para logs detalhados
   - Consulte `.cursor/docs/` para documentação completa

