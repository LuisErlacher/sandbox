#!/bin/bash

# Script para executar story-ready workflow usando cursor-agent CLI
# Uso: ./story-ready.sh <story> [instruções_extras]
# story pode ser o nome da story (ex: "1-1-landing-page-petshop") ou o path completo

set -e

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Diretórios do projeto
# Calcular PROJECT_ROOT: subir de .cursor/scripts/ para a raiz do projeto
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BMAD_CONFIG="${PROJECT_ROOT}/.bmad/bmm/config.yaml"
WORKFLOW_FILE="${PROJECT_ROOT}/.bmad/bmm/workflows/4-implementation/story-ready/workflow.yaml"
WORKFLOW_INSTRUCTIONS="${PROJECT_ROOT}/.bmad/bmm/workflows/4-implementation/story-ready/instructions.md"
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
echo -e "${BLUE}Marcando Story como Ready${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Função para verificar e instalar cursor-agent
check_and_install_cursor_agent() {
    if command -v cursor-agent &> /dev/null; then
        echo -e "${GREEN}✓ cursor-agent encontrado${NC}"
        cursor-agent --version 2>&1 | head -1
        return 0
    fi
    
    echo -e "${YELLOW}⚠️  cursor-agent não encontrado no PATH${NC}"
    echo "Instalando cursor-agent..."
    
    # Instalar cursor-agent
    if ! curl https://cursor.com/install -fsS | bash; then
        echo -e "${RED}Erro ao instalar cursor-agent. Verifique sua conexão com a internet.${NC}"
        exit 1
    fi
    
    # Recarregar PATH para incluir novos binários
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    
    # Verificar novamente após instalação
    if command -v cursor-agent &> /dev/null; then
        echo -e "${GREEN}✓ cursor-agent instalado e encontrado${NC}"
        cursor-agent --version 2>&1 | head -1
        return 0
    fi
    
    # Tentar encontrar em locais comuns
    local possible_paths=(
        "$HOME/.local/bin/cursor-agent"
        "$HOME/.cargo/bin/cursor-agent"
        "/usr/local/bin/cursor-agent"
        "/usr/bin/cursor-agent"
    )
    
    for path in "${possible_paths[@]}"; do
        if [ -f "$path" ] && [ -x "$path" ]; then
            echo -e "${GREEN}✓ cursor-agent encontrado em: $path${NC}"
            "$path" --version 2>&1 | head -1
            export PATH="$(dirname "$path"):$PATH"
            return 0
        fi
    done
    
    echo -e "${RED}Erro: cursor-agent não pôde ser encontrado após instalação${NC}"
    echo "Por favor, execute manualmente: curl https://cursor.com/install -fsS | bash"
    echo "E adicione o diretório de instalação ao seu PATH"
    exit 1
}

# Verificar e instalar cursor-agent se necessário
check_and_install_cursor_agent

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
    echo -e "${RED}Erro: Workflow file não encontrado: $WORKFLOW_FILE${NC}"
    exit 1
fi

if [ ! -f "$WORKFLOW_INSTRUCTIONS" ]; then
    echo -e "${RED}Erro: Workflow instructions não encontrado: $WORKFLOW_INSTRUCTIONS${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Workflow file encontrado: $WORKFLOW_FILE${NC}"
echo -e "${GREEN}✓ Workflow instructions encontrado: $WORKFLOW_INSTRUCTIONS${NC}"

# Ler a story completa
STORY_CONTENT=$(cat "$STORY_FILE")
STORY_NAME=$(basename "$STORY_FILE" .md)

# Preparar prompt para o cursor-agent
PROMPT=$(cat <<EOF
Você é o agente SM (Scrum Master) do BMad Method. Siga as instruções de ativação do agente SM.

**CONTEXTO DO PROJETO:**
- Projeto: $(basename "$PROJECT_ROOT")
- Usuário: Luis
- Linguagem de comunicação: Português
- Story: $STORY_NAME

**STORY COMPLETA:**

$STORY_CONTENT

**INSTRUÇÕES:**

1. Carregue o arquivo de configuração: $BMAD_CONFIG
2. Carregue o workflow YAML: $WORKFLOW_FILE
3. Carregue as instruções do workflow: $WORKFLOW_INSTRUCTIONS
4. Leia completamente a story acima
5. Execute o workflow story-ready seguindo TODAS as instruções do arquivo de instruções
6. Verifique se a story está completa e pronta para desenvolvimento
7. Marque a story como ready-for-dev no arquivo de status
8. Atualize o sprint-status.yaml movendo de drafted → ready-for-dev
9. Comunique-se em Português

$(if [ -n "$EXTRA_INSTRUCTIONS" ]; then
    echo "**INSTRUÇÕES EXTRAS:**
$EXTRA_INSTRUCTIONS"
fi)

**WORKFLOW A EXECUTAR:**
Execute o workflow story-ready seguindo as instruções em: $WORKFLOW_INSTRUCTIONS

**IMPORTANTE:**
- Execute continuamente sem pausar para revisão ou marcos
- Pare apenas quando a story estiver marcada como IN PROGRESS e o status atualizado
- Comunique-se em Português
- Siga os padrões do BMad Method

Comece executando o workflow story-ready agora.
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

