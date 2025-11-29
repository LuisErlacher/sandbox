#!/bin/bash

# Script para executar create-story workflow usando cursor-agent CLI
# Uso: ./create-story.sh <story> [instruções_extras]
# story pode ser o nome da story (ex: "1-2-authentication") ou o path completo
# Nota: Para criar uma nova story, pode passar o nome desejado ou deixar o agente determinar

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
WORKFLOW_FILE="${PROJECT_ROOT}/.cursor/rules/bmad/bmm/workflows/create-story.mdc"
SPRINT_ARTIFACTS="${PROJECT_ROOT}/docs/sprint-artifacts"

# Função para encontrar arquivo de story (pode não existir ainda se for criação)
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
    
    # Se não encontrou, pode ser uma nova story - retornar o nome sugerido
    echo "${SPRINT_ARTIFACTS}/${story_name}.md"
    return 1
}

# Verificar argumentos
if [ $# -lt 1 ]; then
    echo -e "${RED}Erro: Story não especificada${NC}"
    echo "Uso: $0 <story> [instruções_extras]"
    echo "  story: nome da story (ex: '1-2-authentication') ou path completo"
    echo "  instruções_extras: (opcional) instruções adicionais para o agente"
    exit 1
fi

STORY_INPUT="$1"
EXTRA_INSTRUCTIONS="${2:-}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Criando Story${NC}"
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

# Tentar encontrar arquivo de story (pode não existir se for criação)
STORY_FILE=$(find_story_file "$STORY_INPUT" 2>/dev/null || echo "")
STORY_NAME=$(basename "${STORY_INPUT%.md}")

# Verificar se o workflow existe
if [ ! -f "$WORKFLOW_FILE" ]; then
    echo -e "${YELLOW}⚠️  Workflow file não encontrado: $WORKFLOW_FILE${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Workflow file encontrado: $WORKFLOW_FILE${NC}"

# Preparar prompt para o cursor-agent
PROMPT=$(cat <<EOF
Você é o agente SM (Scrum Master) do BMad Method. Siga as instruções de ativação do agente SM.

**CONTEXTO DO PROJETO:**
- Projeto: $(basename "$PROJECT_ROOT")
- Usuário: Luis
- Linguagem de comunicação: Português
- Story: $STORY_NAME

$(if [ -n "$STORY_FILE" ] && [ -f "$STORY_FILE" ]; then
    echo "**STORY EXISTENTE (se aplicável):**
$(cat "$STORY_FILE")"
fi)

**INSTRUÇÕES:**

1. Carregue o arquivo de configuração: $BMAD_CONFIG
2. Execute o workflow create-story localizado em: $WORKFLOW_FILE
3. Crie a story seguindo o template padrão do BMad Method
4. Use os epics, PRD e arquitetura disponíveis como referência
5. Salve a story em: ${SPRINT_ARTIFACTS}/${STORY_NAME}.md
6. Siga todos os critérios de validação do workflow
7. Comunique-se em Português

$(if [ -n "$EXTRA_INSTRUCTIONS" ]; then
    echo "**INSTRUÇÕES EXTRAS:**
$EXTRA_INSTRUCTIONS"
fi)

**WORKFLOW A EXECUTAR:**
Execute o workflow create-story seguindo as instruções em: $WORKFLOW_FILE

**IMPORTANTE:**
- Execute continuamente sem pausar para revisão ou marcos
- Pare apenas quando a story estiver COMPLETA e validada
- Comunique-se em Português
- Siga os padrões de documentação do BMad Method

Comece executando o workflow create-story agora.
EOF
)

echo ""
echo -e "${BLUE}Acionando agente SM via cursor-agent CLI...${NC}"
echo ""

# Executar cursor-agent com o prompt
cursor-agent -p "$PROMPT"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Execução concluída${NC}"
echo -e "${GREEN}========================================${NC}"

