# Hooks

Hooks permitem observar, controlar e estender o loop do agente usando scripts personalizados. Hooks são processos separados que se comunicam via stdio usando JSON em ambas as direções. Eles são executados antes ou depois de estágios definidos do loop do agente e podem observar, bloquear ou modificar o comportamento.

Com hooks, você pode:

- Executar formatadores após edições
- Adicionar analytics de eventos
- Verificar PII (dados pessoais) ou segredos
- Controlar operações arriscadas (por exemplo, escritas em SQL)

## Suporte a Agent e Tab

Hooks funcionam tanto com o **Cursor Agent** (Cmd+K/Agent Chat) quanto com o **Cursor Tab** (compleções em linha), mas eles usam diferentes eventos de hooks:

### Agent (Cmd+K/Agent Chat)

Usa os hooks padrão:

- `beforeShellExecution` / `afterShellExecution` - Controlar comandos de shell
- `beforeMCPExecution` / `afterMCPExecution` - Controlar o uso de ferramentas MCP
- `beforeReadFile` / `afterFileEdit` - Controlar o acesso a arquivos e suas edições
- `beforeSubmitPrompt` - Validar prompts antes do envio
- `stop` - Tratar a finalização do Agent
- `afterAgentResponse` / `afterAgentThought` - Acompanhar respostas do Agent

### Tab (compleções em linha)

Usa hooks especializados:

- `beforeTabFileRead` - Controlar o acesso a arquivos para compleções do Tab
- `afterTabFileEdit` - Pós-processar edições do Tab

Esses hooks separados permitem definir políticas diferentes para operações autônomas do Tab versus operações orientadas pelo usuário no Agent.

## Início Rápido

Crie um arquivo `hooks.json`. Você pode criá-lo no nível do projeto (`<project>/.cursor/hooks.json`) ou no seu diretório pessoal (`~/.cursor/hooks.json`). Hooks no nível do projeto se aplicam apenas a esse projeto específico, enquanto hooks no diretório pessoal se aplicam globalmente.

```json
{
  "version": 1,
  "hooks": {
    "afterFileEdit": [{ "command": "./hooks/format.sh" }]
  }
}
```

Crie seu script de hook em `~/.cursor/hooks/format.sh`:

```bash
#!/bin/bash
# Lê a entrada, faz algo, sai com 0
cat > /dev/null
exit 0
```

Deixe-o executável:

```bash
chmod +x ~/.cursor/hooks/format.sh
```

Reinicie o Cursor. Seu hook agora será executado após cada edição de arquivo.

## Exemplos

### hooks.json

```json
{
  "version": 1,
  "hooks": {
    "beforeShellExecution": [
      {
        "command": "./hooks/audit.sh"
      },
      {
        "command": "./hooks/block-git.sh"
      }
    ],
    "beforeMCPExecution": [
      {
        "command": "./hooks/audit.sh"
      }
    ],
    "afterShellExecution": [
      {
        "command": "./hooks/audit.sh"
      }
    ],
    "afterMCPExecution": [
      {
        "command": "./hooks/audit.sh"
      }
    ],
    "afterFileEdit": [
      {
        "command": "./hooks/audit.sh"
      }
    ],
    "beforeSubmitPrompt": [
      {
        "command": "./hooks/audit.sh"
      }
    ],
    "stop": [
      {
        "command": "./hooks/audit.sh"
      }
    ],
    "beforeTabFileRead": [
      {
        "command": "./hooks/redact-secrets-tab.sh"
      }
    ],
    "afterTabFileEdit": [
      {
        "command": "./hooks/format-tab.sh"
      }
    ]
  }
}
```

### audit.sh

```bash
#!/bin/bash

# audit.sh - Script de hook que grava toda a entrada JSON em /tmp/agent-audit.log
# Este script foi projetado para ser chamado pelo sistema de hooks do Cursor para fins de auditoria

# Ler a entrada JSON da entrada padrão (stdin)
json_input=$(cat)

# Criar carimbo de data/hora para o registro
timestamp=$(date '+%Y-%m-%d %H:%M:%S')

# Criar o diretório de log se ele não existir
mkdir -p "$(dirname /tmp/agent-audit.log)"

# Gravar a entrada JSON com carimbo de data/hora no log de auditoria
echo "[$timestamp] $json_input" >> /tmp/agent-audit.log

# Sair com sucesso
exit 0
```

### block-git.sh

```bash
#!/bin/bash

# Hook para bloquear comandos git e redirecionar para o uso da ferramenta gh
# Este hook implementa o hook beforeShellExecution da Cursor Hooks Spec

# Inicializar o log de depuração
echo "Hook execution started" >> /tmp/hooks.log

# Ler a entrada JSON da entrada padrão (stdin)
input=$(cat)
echo "Received input: $input" >> /tmp/hooks.log

# Analisar o comando a partir da entrada JSON
command=$(echo "$input" | jq -r '.command // empty')
echo "Parsed command: '$command'" >> /tmp/hooks.log

# Verificar se o comando contém 'git' ou 'gh'
if [[ "$command" =~ git[[:space:]] ]] || [[ "$command" == "git" ]]; then
    echo "Git command detected - blocking: '$command'" >> /tmp/hooks.log
    # Bloquear o comando git e orientar a usar a ferramenta gh em vez disso
    cat << EOF
{
  "continue": true,
  "permission": "deny",
  "user_message": "Comando Git bloqueado. Use a ferramenta GitHub CLI (gh) em vez disso.",
  "agent_message": "O comando git '$command' foi bloqueado por um hook. Em vez de usar comandos git diretamente, use a ferramenta 'gh', que oferece melhor integração com o GitHub e segue boas práticas. Por exemplo:\n- Em vez de 'git clone', use 'gh repo clone'\n- Em vez de 'git push', use 'gh repo sync' ou o comando gh apropriado\n- Para outras operações git, verifique se existe um comando gh equivalente ou use a interface web do GitHub\n\nIsso ajuda a manter a consistência e aproveitar as ferramentas avançadas do GitHub."
}
EOF
elif [[ "$command" =~ gh[[:space:]] ]] || [[ "$command" == "gh" ]]; then
    echo "GitHub CLI command detected - asking for permission: '$command'" >> /tmp/hooks.log
    # Solicitar permissão para comandos gh
    cat << EOF
{
  "continue": true,
  "permission": "ask",
  "user_message": "Comando do GitHub CLI requer permissão: $command",
  "agent_message": "O comando '$command' usa o GitHub CLI (gh), que pode interagir com seus repositórios e com a sua conta no GitHub. Revise e aprove este comando se você quiser continuar."
}
EOF
else
    echo "Non-git/non-gh command detected - allowing: '$command'" >> /tmp/hooks.log
    # Permitir comandos que não sejam git/gh
    cat << EOF
{
  "continue": true,
  "permission": "allow"
}
EOF
fi
```

## Configuração

Defina hooks em um arquivo `hooks.json`. A configuração pode ser definida em vários níveis; fontes de maior prioridade substituem as de menor prioridade:

```
~/.cursor/
├── hooks.json
└── hooks/
    ├── audit.sh
    └── block-git.sh
```

### Locais de Configuração

- **Global** (gerenciado pela Enterprise):
  - macOS: `/Library/Application Support/Cursor/hooks.json`
  - Linux/WSL: `/etc/cursor/hooks.json`
  - Windows: `C:\ProgramData\Cursor\hooks.json`

- **Diretório do projeto** (específico do projeto):
  - `<project-root>/.cursor/hooks.json`
  - Hooks do projeto são executados em qualquer espaço de trabalho confiável e são versionados junto com o seu projeto

- **Diretório pessoal** (específico do usuário):
  - `~/.cursor/hooks.json`

**Ordem de prioridade** (da mais alta para a mais baixa): Enterprise → Projeto → Usuário

O objeto `hooks` mapeia nomes de hooks para arrays de definições de hooks. Cada definição atualmente aceita uma propriedade `command`.

## Referência de Hooks

### beforeReadFile

Chamado antes de o Agent tentar ler um arquivo. Pode editar o conteúdo do arquivo ou negar acesso.

```json
// Entrada
{
  "file_path": "<caminho absoluto>",
  "content": "<conteúdo do arquivo>",
  "attachments": [
    {
      "type": "file" | "rule",
      "filePath": "<caminho absoluto>"
    }
  ]
}

// Saída
{
  "permission": "allow" | "deny",
  "new_content": "<conteúdo modificado do arquivo>"
}
```

| Campo de saída | Tipo   | Descrição                                    |
| -------------- | ------ | -------------------------------------------- |
| `permission`   | string | Se a leitura do arquivo deve ser permitida   |
| `new_content`  | string | Conteúdo modificado do arquivo (se editado)  |

### beforeShellExecution / beforeMCPExecution

Chamado antes de executar comandos de shell ou ferramentas MCP. Pode permitir, negar ou solicitar permissão.

```json
// beforeShellExecution input
{
  "command": "<comando completo do terminal>",
  "cwd": "<diretório de trabalho atual>"
}

// beforeMCPExecution input
{
  "tool_name": "<nome da ferramenta>",
  "tool_input": "<parâmetros json>"
}
// Mais um dos seguintes:
{ "url": "<url do servidor>" }
// Ou:
{ "command": "<string de comando>" }

// Output
{
  "permission": "allow" | "deny" | "ask",
  "user_message": "<mensagem exibida no cliente>",
  "agent_message": "<mensagem enviada ao agente>"
}
```

### afterShellExecution

É acionado depois que um comando de shell é executado; útil para auditoria ou para coletar métricas a partir da saída do comando.

```json
// Entrada
{
  "command": "<comando completo do terminal>",
  "output": "<saída completa do terminal>",
  "duration": 1234
}
```

| Campo      | Tipo   | Descrição                                                                                               |
| ---------- | ------ | ------------------------------------------------------------------------------------------------------- |
| `command`  | string | O comando completo de terminal que foi executado                                                        |
| `output`   | string | Saída completa capturada no terminal                                                                    |
| `duration` | number | Tempo em milissegundos gasto na execução do comando de shell (não inclui o tempo de espera por aprovação) |

### afterMCPExecution

É disparado após a execução de uma ferramenta MCP; inclui os parâmetros de entrada da ferramenta e o resultado JSON completo.

```json
// Entrada
{
  "tool_name": "<nome da ferramenta>",
  "tool_input": "<parâmetros json>",
  "result_json": "<json de resultado da ferramenta>",
  "duration": 1234
}
```

| Campo         | Tipo   | Descrição                                                                                                 |
| ------------- | ------ | --------------------------------------------------------------------------------------------------------- |
| `tool_name`   | string | Nome da ferramenta MCP que foi executada                                                                  |
| `tool_input`  | string | String JSON de parâmetros enviada para a ferramenta                                                       |
| `result_json` | string | String JSON com a resposta da ferramenta                                                                  |
| `duration`    | number | Tempo, em milissegundos, gasto na execução da ferramenta MCP (não inclui o tempo de espera por aprovação) |

### afterFileEdit

É acionado depois que o Agent edita um arquivo; útil para formatadores ou para contabilizar o código escrito pelo Agent.

```json
// Entrada
{
  "file_path": "<caminho absoluto>",
  "edits": [{ "old_string": "<busca>", "new_string": "<substitui>" }]
}
```

### beforeTabFileRead

Chamado antes de o Tab (compleções inline) ler um arquivo. Habilite redação ou controle de acesso antes de o Tab acessar o conteúdo do arquivo.

**Principais diferenças em relação a `beforeReadFile`:**

- Acionado apenas pelo Tab, não pelo Agent
- Não inclui o campo `attachments` (o Tab não usa anexos de prompt)
- Útil para aplicar políticas diferentes a operações autônomas do Tab

```json
// Entrada
{
  "file_path": "<caminho absoluto>",
  "content": "<conteúdo do arquivo>"
}

// Saída
{
  "permission": "allow" | "deny"
}
```

### afterTabFileEdit

Chamado depois que o Tab (completações inline) edita um arquivo. Útil para formatadores ou para auditoria de código escrito pelo Tab.

**Principais diferenças em relação a `afterFileEdit`:**

- Acionado apenas pelo Tab, não pelo Agent
- Inclui informações detalhadas da edição: `range`, `old_line` e `new_line` para rastreamento preciso da edição
- Útil para formatação ou análise detalhada das edições do Tab

```json
// Entrada
{
  "file_path": "<caminho absoluto>",
  "edits": [
    {
      "old_string": "<pesquisar>",
      "new_string": "<substituir>",
      "range": {
        "start_line_number": 10,
        "start_column": 5,
        "end_line_number": 10,
        "end_column": 20
      },
      "old_line": "<linha antes da edição>",
      "new_line": "<linha depois da edição>"
    }
  ]
}

// Saída
{
  // Nenhum campo de saída disponível no momento
}
```

### beforeSubmitPrompt

Chamado logo depois que o usuário clica em Enviar, mas antes da requisição ao backend. Pode impedir o envio.

```json
// Entrada
{
  "prompt": "<texto do prompt do usuário>",
  "attachments": [
    {
      "type": "file" | "rule",
      "filePath": "<caminho absoluto>"
    }
  ]
}

// Saída
{
  "continue": true | false,
  "user_message": "<mensagem exibida para o usuário quando bloqueado>"
}
```

| Campo de saída | Tipo              | Descrição                                               |
| -------------- | ----------------- | ------------------------------------------------------- |
| `continue`     | boolean           | Se o envio do prompt pode prosseguir                    |
| `user_message` | string (opcional) | Mensagem exibida ao usuário quando o prompt é bloqueado |

### afterAgentResponse

Chamado após o agente concluir uma mensagem do assistente.

```json
// Entrada
{
  "text": "<texto final do assistente>"
}
```

### afterAgentThought

Chamado após o agente concluir um bloco de raciocínio. Útil para observar o processo de raciocínio do agente.

```json
// Entrada
{
  "text": "<texto de raciocínio totalmente agregado>",
  "duration_ms": 5000
}

// Saída
{
  // Nenhum campo de saída disponível no momento
}
```

| Campo         | Tipo              | Descrição                                                |
| ------------- | ----------------- | -------------------------------------------------------- |
| `text`        | string            | Texto de raciocínio totalmente agregado do bloco concluído |
| `duration_ms` | number (opcional) | Duração, em milissegundos, do bloco de raciocínio        |

### stop

Chamado quando o loop do agente termina. Opcionalmente, pode enviar automaticamente uma mensagem de acompanhamento do usuário para continuar iterando.

```json
// Entrada
{
  "status": "completed" | "aborted" | "error",
  "loop_count": 0
}

// Saída
{
  "followup_message": "<texto da mensagem>"
}
```

- O `followup_message` opcional é uma string. Quando definido e não vazio, o Cursor o enviará automaticamente como a próxima mensagem do usuário. Isso permite fluxos em loop (por exemplo, iterar até que uma meta seja atingida).
- O campo `loop_count` indica quantas vezes o stop hook já acionou um follow-up automático para esta conversa (inicia em 0). Para evitar loops infinitos, é aplicado um máximo de 5 follow-ups automáticos.

## Solução de Problemas

### Como confirmar que os hooks estão ativos

Há uma guia Hooks nas Configurações do Cursor para depurar hooks configurados e executados, além de um canal de saída de Hooks para ver erros.

### Se os hooks não estiverem funcionando

- Reinicie o Cursor para garantir que o serviço de hooks esteja em execução.
- Certifique-se de que os caminhos dos scripts de hook sejam relativos a `hooks.json` ao usar caminhos relativos.

---

**Fonte:** [https://cursor.com/pt-BR/docs/agent/hooks](https://cursor.com/pt-BR/docs/agent/hooks)




