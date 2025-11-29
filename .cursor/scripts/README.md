# Sistema de Hooks do Cursor

Sistema completo de hooks para o Cursor que coleta dados de sessão, armazena em banco de dados SQLite e verifica automaticamente a conclusão de tasks usando Cursor CLI headless.

## Estrutura do Projeto

```
sandbox/
├── .cursor/
│   ├── hooks/
│   │   ├── session-collector.sh      # Coleta eventos dos hooks
│   │   ├── db-manager.sh             # Gerencia banco de dados SQLite
│   │   ├── task-completion-checker.sh # Verifica conclusão de tasks
│   │   └── workflow-controller.sh    # Controla workflow do agente
│   ├── scripts/
│   │   ├── query-context.sh          # Consulta contexto de uma generation
│   │   ├── query-conversation-history.sh # Histórico completo de conversa
│   │   ├── query-examples.sh         # Exemplos de consultas SQL
│   │   ├── verify-collection.sh      # Verifica coleta de dados
│   │   └── check-cloud-agents-env.sh  # Verifica configuração de ambiente
│   ├── database/
│   │   ├── cursor_hooks.db           # Banco de dados SQLite
│   │   └── database-schema.sql       # Schema do banco
│   ├── docs/
│   │   ├── DATABASE.md               # Documentação do banco de dados
│   │   ├── TASK-COMPLETION-CHECKER.md # Documentação do checker
│   │   ├── CURSOR-API-KEY-CONFIG.md  # Configuração da API key
│   │   ├── CLOUD-AGENTS-ENV.md       # Configuração de ambiente Cloud Agents
│   │   └── TROUBLESHOOTING.md        # Guia de troubleshooting
│   ├── hooks.json                    # Configuração dos hooks
│   ├── session.json                  # Log linear de eventos
│   └── sessions.json                 # Sessões estruturadas
├── docs/
│   └── cursor-hooks.md               # Documentação dos hooks do Cursor
└── README.md                          # Este arquivo
```

## Componentes Principais

### 1. Session Collector (`session-collector.sh`)

Coleta eventos de todos os hooks do Cursor e armazena em:
- `session.json` - Log linear de todos os eventos
- Banco SQLite - Dados estruturados por conversation e generation

**Hooks suportados:**
- `beforeSubmitPrompt` - Prompt inicial do usuário
- `afterAgentResponse` - Resposta final do agente
- `afterAgentThought` - Pensamentos do agente
- `afterShellExecution` - Comandos executados no terminal
- `afterMCPExecution` - Execuções de ferramentas MCP
- `afterFileEdit` - Edições de arquivos
- `stop` - Finalização do loop do agente

### 2. Database Manager (`db-manager.sh`)

Gerencia o banco de dados SQLite:
- Cria schema automaticamente na primeira execução
- Insere eventos de forma estruturada
- Organiza dados por `conversation_id` e `generation_id`

**Tabelas principais:**
- `conversations` - Conversas do usuário
- `generations` - Gerações (loops) do agente
- `events` - Eventos capturados
- Tabelas específicas por tipo de evento

### 3. Task Completion Checker (`task-completion-checker.sh`)

Verifica automaticamente se uma task foi concluída:
- Compara prompt inicial com resposta final
- Usa Cursor CLI headless para análise
- Retorna `followup_message` para continuar ou parar

**Funcionamento:**
1. Busca prompt inicial (`beforeSubmitPrompt`) no banco
2. Busca resposta final (`afterAgentResponse`) no banco
3. Executa `cursor-agent` para análise
4. Retorna JSON com `followup_message`:
   - `""` (vazio) = task concluída, parar
   - `"mensagem"` = task não concluída, continuar

### 4. Workflow Controller (`workflow-controller.sh`)

Controla o workflow do agente:
- Processa resultado do task-completion-checker
- Gerencia limites de loops
- Retorna `followup_message` para o Cursor

## Configuração

### 1. Instalar Dependências

```bash
# jq para processamento JSON
sudo apt install jq

# cursor-agent CLI (para task-completion-checker)
curl https://cursor.com/install -fsS | bash
```

### 2. Configurar CURSOR_API_KEY

**Para Cloud Agents (Recomendado):**
1. Cursor Settings → Cloud Agents → Secrets
2. Adicione secret com chave `CURSOR_API_KEY`

**Para ambiente local:**
```bash
export CURSOR_API_KEY=sua_api_key_aqui
```

Consulte `.cursor/docs/CURSOR-API-KEY-CONFIG.md` para mais opções.

### 3. Verificar Configuração

Os hooks são configurados em `.cursor/hooks.json`:

```json
{
  "version": 1,
  "hooks": {
    "beforeSubmitPrompt": [
      { "command": "bash .cursor/hooks/session-collector.sh" }
    ],
    "afterAgentResponse": [
      { "command": "bash .cursor/hooks/session-collector.sh" }
    ],
    "stop": [
      { "command": "bash .cursor/hooks/session-collector.sh" },
      { "command": "bash .cursor/hooks/task-completion-checker.sh" },
      { "command": "bash .cursor/hooks/workflow-controller.sh" }
    ]
  }
}
```

## Uso

### Consultar Histórico de Conversa

```bash
# Histórico completo de uma conversa
bash .cursor/scripts/query-conversation-history.sh <conversation_id>

# Contexto de uma generation específica
bash .cursor/scripts/query-context.sh <generation_id>
```

### Verificar Coleta de Dados

```bash
# Verificar se todas as variáveis estão sendo coletadas
bash .cursor/scripts/verify-collection.sh
```

### Verificar Configuração de Ambiente do Cloud Agents

```bash
# Verificar variáveis de ambiente e configuração
bash .cursor/scripts/check-cloud-agents-env.sh
```

### Ver Logs

```bash
# Logs em tempo real
tail -f ~/.cursor/hooks-debug.log

# Últimos erros
tail -50 ~/.cursor/hooks-debug.log | grep ERRO
```

## Documentação

- **`.cursor/docs/DATABASE.md`** - Estrutura do banco de dados e consultas
- **`.cursor/docs/TASK-COMPLETION-CHECKER.md`** - Funcionamento do checker
- **`.cursor/docs/CURSOR-API-KEY-CONFIG.md`** - Configuração da API key
- **`.cursor/docs/CLOUD-AGENTS-ENV.md`** - Configuração de ambiente Cloud Agents
- **`.cursor/docs/TROUBLESHOOTING.md`** - Guia de solução de problemas
- **`docs/cursor-hooks.md`** - Documentação oficial dos hooks do Cursor

## Requisitos

- **jq** - Processamento de JSON
- **sqlite3** - Banco de dados SQLite
- **cursor-agent** - CLI do Cursor (para task-completion-checker)
- **bash** - Shell script

## Troubleshooting

Consulte `.cursor/docs/TROUBLESHOOTING.md` para problemas comuns e soluções.

Principais verificações:
1. Hooks estão executando? → Ver logs em `~/.cursor/hooks-debug.log`
2. Dados estão sendo salvos? → Verificar banco SQLite
3. Task checker retorna vazio? → Verificar CURSOR_API_KEY

## Licença

Este projeto é um sandbox para experimentação e desenvolvimento.
