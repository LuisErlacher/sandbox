#!/bin/bash

# Script para executar epic-tech-context workflow usando cursor-agent CLI
# Uso: ./epic-tech-context.sh <epic> [instruções_extras]
# epic pode ser o nome do epic (ex: "epic-1") ou o path completo

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
WORKFLOW_FILE="${PROJECT_ROOT}/.bmad/bmm/workflows/4-implementation/epic-tech-context/workflow.yaml"
WORKFLOW_INSTRUCTIONS="${PROJECT_ROOT}/.bmad/bmm/workflows/4-implementation/epic-tech-context/instructions.md"
OUTPUT_FOLDER="${PROJECT_ROOT}/docs"

# Função para encontrar arquivo de epic
find_epic_file() {
    local epic_input="$1"
    
    # Se já é um path completo e existe, usar diretamente
    if [[ -f "$epic_input" ]]; then
        echo "$epic_input"
        return 0
    fi
    
    # Se é um path relativo, tentar resolver
    if [[ "$epic_input" == *"/"* ]]; then
        local resolved_path="${PROJECT_ROOT}/${epic_input}"
        if [[ -f "$resolved_path" ]]; then
            echo "$resolved_path"
            return 0
        fi
    fi
    
    # Tentar encontrar por nome (com ou sem extensão)
    local epic_name="${epic_input%.md}"
    
    # Tentar encontrar com padrão epic-*.md ou *epic*.md
    local found=$(find "$OUTPUT_FOLDER" -name "*epic*${epic_name}*.md" -type f | head -1)
    if [[ -n "$found" ]]; then
        echo "$found"
        return 0
    fi
    
    # Tentar encontrar epic-{nome}.md
    found=$(find "$OUTPUT_FOLDER" -name "epic-${epic_name}.md" -type f | head -1)
    if [[ -n "$found" ]]; then
        echo "$found"
        return 0
    fi
    
    # Tentar encontrar {nome}-epic.md
    found=$(find "$OUTPUT_FOLDER" -name "${epic_name}-epic.md" -type f | head -1)
    if [[ -n "$found" ]]; then
        echo "$found"
        return 0
    fi
    
    return 1
}

# Verificar argumentos
if [ $# -lt 1 ]; then
    echo -e "${RED}Erro: Epic não especificado${NC}"
    echo "Uso: $0 <epic> [instruções_extras]"
    echo "  epic: nome do epic (ex: 'epic-1' ou '1') ou path completo"
    echo "  instruções_extras: (opcional) instruções adicionais para o agente"
    exit 1
fi

EPIC_INPUT="$1"
EXTRA_INSTRUCTIONS="${2:-}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Gerando Epic Tech Context${NC}"
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

# Tentar encontrar arquivo de epic (pode não existir ainda)
EPIC_FILE=$(find_epic_file "$EPIC_INPUT" 2>/dev/null || echo "")
EPIC_NAME="$EPIC_INPUT"

if [[ -n "$EPIC_FILE" ]] && [[ -f "$EPIC_FILE" ]]; then
    echo -e "${GREEN}✓ Epic encontrado: $EPIC_FILE${NC}"
    EPIC_CONTENT=$(cat "$EPIC_FILE")
else
    echo -e "${YELLOW}⚠️  Epic não encontrado, o agente tentará localizar ou criar${NC}"
    EPIC_CONTENT=""
fi

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

# Preparar prompt para o cursor-agent
PROMPT=$(cat <<EOF
Você é o agente SM (Scrum Master) do BMad Method. Siga as instruções de ativação do agente SM.

**CONTEXTO DO PROJETO:**
- Projeto: $(basename "$PROJECT_ROOT")
- Usuário: Luis
- Linguagem de comunicação: Português
- Epic: $EPIC_NAME

$(if [ -n "$EPIC_CONTENT" ]; then
    echo "**EPIC COMPLETO:**

$EPIC_CONTENT"
fi)

**INSTRUÇÕES:**

1. Carregue o arquivo de configuração: $BMAD_CONFIG
2. Carregue o workflow YAML: $WORKFLOW_FILE
3. Carregue as instruções do workflow: $WORKFLOW_INSTRUCTIONS
4. Execute o workflow epic-tech-context seguindo TODAS as instruções do arquivo de instruções
5. Gere uma especificação técnica abrangente a partir do PRD e Arquitetura
6. Inclua critérios de aceitação e mapeamento de rastreabilidade
7. Use o template do workflow para estruturar a especificação técnica
8. Salve o arquivo em: ${OUTPUT_FOLDER}/tech-spec-epic-{epic_id}.md
9. Comunique-se em Português

$(if [ -n "$EXTRA_INSTRUCTIONS" ]; then
    echo "**INSTRUÇÕES EXTRAS:**
$EXTRA_INSTRUCTIONS"
fi)

**WORKFLOW A EXECUTAR:**
Execute o workflow epic-tech-context seguindo as instruções em: $WORKFLOW_INSTRUCTIONS

**IMPORTANTE:**
- Execute continuamente sem pausar para revisão ou marcos
- Pare apenas quando a especificação técnica estiver COMPLETA e validada
- Comunique-se em Português
- Siga os padrões de documentação técnica do BMad Method

Comece executando o workflow epic-tech-context agora.
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

