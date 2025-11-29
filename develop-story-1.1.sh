#!/bin/bash

# Script para desenvolver a Story 1.1 usando cursor-agent CLI
# Aciona o agente DEV do BMad Method para implementar a landing page

set -e

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Diretórios do projeto
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
STORY_FILE="${PROJECT_ROOT}/docs/sprint-artifacts/1-1-landing-page-petshop.md"
BMAD_CONFIG="${PROJECT_ROOT}/.bmad/bmm/config.yaml"
WORKFLOW_FILE="${PROJECT_ROOT}/.bmad/bmm/workflows/4-implementation/dev-story/workflow.yaml"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Desenvolvendo Story 1.1${NC}"
echo -e "${BLUE}Landing Page - Petshop 'Meu Caozinho Lindo'${NC}"
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

# Verificar se a story existe
if [ ! -f "$STORY_FILE" ]; then
    echo -e "${YELLOW}⚠️  Story file não encontrado: $STORY_FILE${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Story file encontrado: $STORY_FILE${NC}"

# Verificar se o workflow existe
if [ ! -f "$WORKFLOW_FILE" ]; then
    echo -e "${YELLOW}⚠️  Workflow file não encontrado: $WORKFLOW_FILE${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Workflow file encontrado: $WORKFLOW_FILE${NC}"

# Ler a story completa
STORY_CONTENT=$(cat "$STORY_FILE")

# Preparar prompt para o cursor-agent
PROMPT=$(cat <<EOF
Você é o agente DEV (Developer) do BMad Method. Siga as instruções de ativação do agente DEV.

**CONTEXTO DO PROJETO:**
- Projeto: sandbox
- Usuário: Luis
- Linguagem de comunicação: Português
- Story: 1.1 - Landing Page Completa - Petshop "Meu Caozinho Lindo"

**STORY COMPLETA:**

$STORY_CONTENT

**INSTRUÇÕES:**

1. Carregue o arquivo de configuração: $BMAD_CONFIG
2. Leia completamente a story acima
3. Execute o workflow dev-story localizado em: $WORKFLOW_FILE
4. Implemente TODAS as tasks e subtasks da story
5. Siga TODOS os acceptance criteria
6. Crie a landing page completa em HTML5 e CSS3 puro conforme especificado
7. Implemente todas as seções: Header, Hero, Serviços, Sobre, Depoimentos, Contato, Footer
8. Garanta responsividade mobile-first
9. Adicione comentários no código
10. Valide HTML e CSS
11. Atualize o arquivo da story marcando tasks como concluídas

**WORKFLOW A EXECUTAR:**
Execute o workflow dev-story seguindo as instruções em: $WORKFLOW_FILE

**IMPORTANTE:**
- Execute continuamente sem pausar para revisão ou marcos
- Pare apenas quando a story estiver COMPLETA (todos os ACs satisfeitos, todas as tasks marcadas, todos os testes executados e passando 100%)
- Comunique-se em Português
- Siga os padrões de arquitetura e design especificados na story

Comece executando o workflow dev-story agora.
EOF
)

echo ""
echo -e "${BLUE}Acionando agente DEV via cursor-agent CLI...${NC}"
echo ""

# Executar cursor-agent com o prompt
# Usar --output-format json para melhor parsing se necessário
cursor-agent -p "$PROMPT"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Execução concluída${NC}"
echo -e "${GREEN}========================================${NC}"

