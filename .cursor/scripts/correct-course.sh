#!/bin/bash

# Script para executar correct-course workflow usando cursor-agent CLI
# Uso: ./correct-course.sh [instruções_extras]
# Este workflow gerencia mudanças significativas durante a execução do sprint

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
WORKFLOW_FILE="${PROJECT_ROOT}/.bmad/bmm/workflows/4-implementation/correct-course/workflow.yaml"
WORKFLOW_INSTRUCTIONS="${PROJECT_ROOT}/.bmad/bmm/workflows/4-implementation/correct-course/instructions.md"
OUTPUT_FOLDER="${PROJECT_ROOT}/docs"
SPRINT_ARTIFACTS="${PROJECT_ROOT}/docs/sprint-artifacts"

# Verificar argumentos
EXTRA_INSTRUCTIONS="${1:-}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Gerenciando Mudanças no Sprint${NC}"
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
Você é o agente SM (Scrum Master) ou PM (Product Manager) do BMad Method. Siga as instruções de ativação do agente apropriado.

**CONTEXTO DO PROJETO:**
- Projeto: $(basename "$PROJECT_ROOT")
- Usuário: Luis
- Linguagem de comunicação: Português

**INSTRUÇÕES:**

1. Carregue o arquivo de configuração: $BMAD_CONFIG
2. Carregue o workflow YAML: $WORKFLOW_FILE
3. Carregue as instruções do workflow: $WORKFLOW_INSTRUCTIONS
4. Execute o workflow correct-course seguindo TODAS as instruções do arquivo de instruções
5. Analise o impacto das mudanças propostas
6. Crie propostas de mudança específicas para stories, PRD, arquitetura ou UX
7. Gere um documento Sprint Change Proposal completo
8. Roteie para implementação baseado no escopo da mudança
9. Comunique-se em Português

$(if [ -n "$EXTRA_INSTRUCTIONS" ]; then
    echo "**INSTRUÇÕES EXTRAS:**
$EXTRA_INSTRUCTIONS"
fi)

**WORKFLOW A EXECUTAR:**
Execute o workflow correct-course seguindo as instruções em: $WORKFLOW_INSTRUCTIONS

**IMPORTANTE:**
- Execute continuamente sem pausar para revisão ou marcos
- Pare apenas quando o Sprint Change Proposal estiver COMPLETO e aprovado
- Comunique-se em Português
- Siga os padrões de documentação do BMad Method
- O workflow deve carregar PRD, Epics, Arquitetura e UX para análise de impacto

Comece executando o workflow correct-course agora.
EOF
)

echo ""
echo -e "${BLUE}Acionando agente SM/PM via cursor-agent CLI...${NC}"
echo ""

# Executar cursor-agent com o prompt
cursor-agent -p "$PROMPT"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Execução concluída${NC}"
echo -e "${GREEN}========================================${NC}"

