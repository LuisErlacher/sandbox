# Configuração da CURSOR_API_KEY para Task Completion Checker

O script `task-completion-checker.sh` busca a `CURSOR_API_KEY` de múltiplas fontes para funcionar tanto localmente quanto em Cloud Agents.

## Fontes de Configuração (em ordem de prioridade)

### 1. Variável de Ambiente (Local)
```bash
export CURSOR_API_KEY=your_api_key_here
```

**Uso:** Ambiente local ou quando você quer sobrescrever outras configurações.

### 2. Secrets do Cloud Agents (Recomendado para Cloud Agents)

Os Cloud Agents do Cursor disponibilizam secrets como variáveis de ambiente automaticamente.

**Como configurar:**
1. No Cursor IDE: Vá até **Cursor Settings** (`Ctrl+,`) → guia **Cloud Agents** → seção **Secrets**
2. Na Web: Acesse **Cursor Dashboard** → **Cloud Agents** → seção **Secrets**
3. Adicione um secret com a chave `CURSOR_API_KEY` e o valor da sua API key

**Vantagens:**
- Criptografado em repouso usando KMS
- Disponível automaticamente como variável de ambiente
- Compartilhado entre todos os cloud agents do workspace/equipe
- Não precisa fazer commit de credenciais no código

### 3. Arquivo de Configuração Local (`.cursor/api-key.txt`)

Crie um arquivo `.cursor/api-key.txt` na raiz do projeto:

```bash
echo "your_api_key_here" > .cursor/api-key.txt
chmod 600 .cursor/api-key.txt
```

**⚠️ IMPORTANTE:** Adicione `.cursor/api-key.txt` ao `.gitignore` para não fazer commit da API key:

```bash
echo ".cursor/api-key.txt" >> .gitignore
```

### 4. Arquivo de Configuração Global (`~/.cursor/api-key`)

Para configuração global do usuário:

```bash
echo "your_api_key_here" > ~/.cursor/api-key
chmod 600 ~/.cursor/api-key
```

**Uso:** Quando você quer usar a mesma API key em todos os projetos.

## Verificação de Configuração

O script verifica as fontes na ordem acima e usa a primeira encontrada. Logs detalhados são escritos em `~/.cursor/hooks-debug.log`:

```bash
tail -f ~/.cursor/hooks-debug.log | grep CURSOR_API_KEY
```

## Exemplo de Logs

### Quando encontrada:
```
[2025-11-29 17:30:00] CURSOR_API_KEY encontrada em variável de ambiente
[2025-11-29 17:30:00] CURSOR_API_KEY encontrada e configurada (32 caracteres)
```

### Quando não encontrada:
```
[2025-11-29 17:30:00] CURSOR_API_KEY não encontrada em nenhuma fonte
[2025-11-29 17:30:00] Fontes verificadas:
[2025-11-29 17:30:00]   1. Variável de ambiente CURSOR_API_KEY
[2025-11-29 17:30:00]   2. Secrets do Cloud Agents (se aplicável)
[2025-11-29 17:30:00]   3. Arquivo .cursor/api-key.txt (local)
[2025-11-29 17:30:00]   4. Arquivo ~/.cursor/api-key (global)
```

## Recomendações

### Para Desenvolvimento Local:
- Use variável de ambiente ou arquivo `~/.cursor/api-key`

### Para Cloud Agents:
- **Use Secrets do Cloud Agents** (método mais seguro e recomendado)
- Configure em Cursor Settings → Cloud Agents → Secrets
- O secret será automaticamente disponibilizado como variável de ambiente

### Para Ambientes CI/CD:
- Use variáveis de ambiente do seu sistema de CI/CD
- Ou configure secrets no seu provedor de CI/CD

## Segurança

- **Nunca** faça commit de arquivos contendo API keys no Git
- Use `.gitignore` para excluir arquivos de configuração locais
- Prefira Secrets do Cloud Agents para ambientes cloud
- Use permissões restritas (600) em arquivos de configuração locais

## Troubleshooting

### O script não encontra a API key mesmo configurada:

1. Verifique os logs:
   ```bash
   tail -50 ~/.cursor/hooks-debug.log | grep CURSOR_API_KEY
   ```

2. Verifique se a variável está disponível:
   ```bash
   echo $CURSOR_API_KEY
   ```

3. Para Cloud Agents, verifique se o secret está configurado:
   - Cursor Settings → Cloud Agents → Secrets
   - Verifique se o nome do secret é exatamente `CURSOR_API_KEY`
   - Reinicie o Cloud Agent após adicionar o secret

4. Teste manualmente:
   ```bash
   export CURSOR_API_KEY=test_key
   echo '{"generation_id":"test"}' | bash .cursor/hooks/task-completion-checker.sh
   ```

## Referências

- [Documentação do Cloud Agents](https://cursor.com/docs/cloud-agents)
- [Gerenciamento de Secrets](https://cursor.com/docs/cloud-agents#variáveis-de-ambiente-e-segredos)

