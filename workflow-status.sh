#!/bin/bash

# Script para executar workflow-status workflow usando cursor-agent CLI
# Uso: ./workflow-status.sh
# Este workflow apenas retorna o status encontrado no diretório

set -e

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Diretórios do projeto
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
BMAD_CONFIG="${PROJECT_ROOT}/.bmad/bmm/config.yaml"
WORKFLOW_FILE="${PROJECT_ROOT}/.cursor/rules/bmad/bmm/workflows/workflow-status.mdc"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Verificando Status do Workflow${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Verificar se cursor-agent está instalado
if ! command -v cursor-agent &> /dev/null; then
    echo -e "${YELLOW}⚠️  cursor-agent não encontrado no PATH${NC}"
    echo "Instalando cursor-agent..."
    curl https://cursor.com/install -fsS | bash
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}Erro ao instalar cursor-agent. Verifique sua conexão com a internet.${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✓ cursor-agent encontrado${NC}"
cursor-agent --version 2>&1 | head -1

# Verificar se o workflow existe
if [ ! -f "$WORKFLOW_FILE" ]; then
    echo -e "${YELLOW}⚠️  Workflow file não encontrado: $WORKFLOW_FILE${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Workflow file encontrado: $WORKFLOW_FILE${NC}"

# Preparar prompt para o cursor-agent
PROMPT=$(cat <<EOF
Você é um agente do BMad Method. Siga as instruções de ativação do agente apropriado.

**CONTEXTO DO PROJETO:**
- Projeto: $(basename "$PROJECT_ROOT")
- Usuário: Luis
- Linguagem de comunicação: Português

**INSTRUÇÕES:**

1. Carregue o arquivo de configuração: $BMAD_CONFIG
2. Execute o workflow workflow-status localizado em: $WORKFLOW_FILE
3. Leia o arquivo YAML de status do workflow
4. Responda à pergunta "o que devo fazer agora?" para qualquer agente
5. Retorne o status encontrado no diretório
6. Comunique-se em Português

**WORKFLOW A EXECUTAR:**
Execute o workflow workflow-status seguindo as instruções em: $WORKFLOW_FILE

**IMPORTANTE:**
- Este workflow é um verificador de status leve
- Retorne apenas o status encontrado
- Comunique-se em Português
- Use workflow-init para novos projetos se necessário

Comece executando o workflow workflow-status agora.
EOF
)

echo ""
echo -e "${BLUE}Acionando agente via cursor-agent CLI...${NC}"
echo ""

# Executar cursor-agent com o prompt
cursor-agent -p "$PROMPT"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Execução concluída${NC}"
echo -e "${GREEN}========================================${NC}"

