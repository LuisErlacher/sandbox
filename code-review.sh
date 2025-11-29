#!/bin/bash

# Script para executar code-review workflow usando cursor-agent CLI
# Uso: ./code-review.sh <story> [instruções_extras]
# story pode ser o nome da story (ex: "1-1-landing-page-petshop") ou o path completo

set -e

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Diretórios do projeto
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
BMAD_CONFIG="${PROJECT_ROOT}/.bmad/bmm/config.yaml"
WORKFLOW_FILE="${PROJECT_ROOT}/.cursor/rules/bmad/bmm/workflows/code-review.mdc"
SPRINT_ARTIFACTS="${PROJECT_ROOT}/docs/sprint-artifacts"

# Função para encontrar arquivo de story
find_story_file() {
    local story_input="$1"
    
    # Se já é um path completo e existe, usar diretamente
    if [[ -f "$story_input" ]]; then
        echo "$story_input"
        return 0
    fi
    
    # Se é um path relativo, tentar resolver
    if [[ "$story_input" == *"/"* ]]; then
        local resolved_path="${PROJECT_ROOT}/${story_input}"
        if [[ -f "$resolved_path" ]]; then
            echo "$resolved_path"
            return 0
        fi
    fi
    
    # Tentar encontrar por nome (com ou sem extensão)
    local story_name="${story_input%.md}"
    local story_file="${SPRINT_ARTIFACTS}/${story_name}.md"
    
    if [[ -f "$story_file" ]]; then
        echo "$story_file"
        return 0
    fi
    
    # Tentar encontrar com padrão
    local found=$(find "$SPRINT_ARTIFACTS" -name "*${story_name}*.md" -type f | head -1)
    if [[ -n "$found" ]]; then
        echo "$found"
        return 0
    fi
    
    return 1
}

# Verificar argumentos
if [ $# -lt 1 ]; then
    echo -e "${RED}Erro: Story não especificada${NC}"
    echo "Uso: $0 <story> [instruções_extras]"
    echo "  story: nome da story (ex: '1-1-landing-page-petshop') ou path completo"
    echo "  instruções_extras: (opcional) instruções adicionais para o agente"
    exit 1
fi

STORY_INPUT="$1"
EXTRA_INSTRUCTIONS="${2:-}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Executando Code Review${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Verificar se cursor-agent está instalado
if ! command -v cursor-agent &> /dev/null; then
    echo -e "${YELLOW}⚠️  cursor-agent não encontrado no PATH${NC}"
    echo "Instalando cursor-agent..."
    curl https://cursor.com/install -fsS | bash
    if [ $? -ne 0 ]; then
        echo -e "${RED}Erro ao instalar cursor-agent. Verifique sua conexão com a internet.${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✓ cursor-agent encontrado${NC}"
cursor-agent --version 2>&1 | head -1

# Encontrar arquivo de story
STORY_FILE=$(find_story_file "$STORY_INPUT")
if [ $? -ne 0 ] || [ -z "$STORY_FILE" ]; then
    echo -e "${RED}Erro: Story não encontrada: $STORY_INPUT${NC}"
    echo "Procurando em: $SPRINT_ARTIFACTS"
    exit 1
fi

echo -e "${GREEN}✓ Story encontrada: $STORY_FILE${NC}"

# Verificar se o workflow existe
if [ ! -f "$WORKFLOW_FILE" ]; then
    echo -e "${YELLOW}⚠️  Workflow file não encontrado: $WORKFLOW_FILE${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Workflow file encontrado: $WORKFLOW_FILE${NC}"

# Ler a story completa
STORY_CONTENT=$(cat "$STORY_FILE")
STORY_NAME=$(basename "$STORY_FILE" .md)

# Preparar prompt para o cursor-agent
PROMPT=$(cat <<EOF
Você é o agente DEV (Developer) do BMad Method. Siga as instruções de ativação do agente DEV.

**CONTEXTO DO PROJETO:**
- Projeto: $(basename "$PROJECT_ROOT")
- Usuário: Luis
- Linguagem de comunicação: Português
- Story: $STORY_NAME

**STORY COMPLETA:**

$STORY_CONTENT

**INSTRUÇÕES:**

1. Carregue o arquivo de configuração: $BMAD_CONFIG
2. Leia completamente a story acima
3. Execute o workflow code-review localizado em: $WORKFLOW_FILE
4. Realize uma revisão completa de código seguindo os padrões do BMad Method
5. Aplique todos os critérios de validação do workflow
6. Adicione notas estruturadas de revisão à story
7. Comunique-se em Português

$(if [ -n "$EXTRA_INSTRUCTIONS" ]; then
    echo "**INSTRUÇÕES EXTRAS:**
$EXTRA_INSTRUCTIONS"
fi)

**WORKFLOW A EXECUTAR:**
Execute o workflow code-review seguindo as instruções em: $WORKFLOW_FILE

**IMPORTANTE:**
- Execute continuamente sem pausar para revisão ou marcos
- Pare apenas quando a revisão estiver COMPLETA
- Comunique-se em Português
- Siga os padrões de arquitetura e design especificados

Comece executando o workflow code-review agora.
EOF
)

echo ""
echo -e "${BLUE}Acionando agente DEV via cursor-agent CLI...${NC}"
echo ""

# Executar cursor-agent com o prompt
cursor-agent -p "$PROMPT"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Execução concluída${NC}"
echo -e "${GREEN}========================================${NC}"

