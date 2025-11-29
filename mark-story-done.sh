#!/bin/bash

# Script para marcar a Story 1.1 como concluída usando cursor-agent CLI
# Executa o workflow story-done do BMad Method

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
WORKFLOW_FILE="${PROJECT_ROOT}/.bmad/bmm/workflows/4-implementation/story-done/workflow.yaml"
SPRINT_STATUS="${PROJECT_ROOT}/docs/sprint-status.yaml"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Marcando Story 1.1 como Concluída${NC}"
echo -e "${BLUE}Workflow: story-done${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Verificar se cursor-agent está instalado
if ! command -v cursor-agent &> /dev/null; then
    echo -e "${YELLOW}⚠️  cursor-agent não encontrado no PATH${NC}"
    exit 1
fi

echo -e "${GREEN}✓ cursor-agent encontrado${NC}"

# Verificar se a story existe
if [ ! -f "$STORY_FILE" ]; then
    echo -e "${YELLOW}⚠️  Story file não encontrado: $STORY_FILE${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Story file encontrado: $STORY_FILE${NC}"

# Verificar status atual da story
CURRENT_STATUS=$(grep "^Status:" "$STORY_FILE" | sed 's/Status: //' | tr -d ' ')
if [ "$CURRENT_STATUS" != "review" ]; then
    echo -e "${YELLOW}⚠️  Status atual da story: $CURRENT_STATUS${NC}"
    echo -e "${YELLOW}   Esperado: review${NC}"
    if [ "$CURRENT_STATUS" == "done" ]; then
        echo -e "${GREEN}   Story já está marcada como concluída!${NC}"
        exit 0
    else
        echo -e "${YELLOW}   A story precisa estar em 'review' para ser marcada como 'done'${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✓ Status atual: review${NC}"

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
3. Execute o workflow story-done localizado em: $WORKFLOW_FILE
4. A story está atualmente com status "review" e precisa ser marcada como "done"
5. Atualize o arquivo da story mudando o status para "done"
6. Adicione notas de conclusão na seção Dev Agent Record
7. Atualize o sprint-status.yaml se existir (caminho: $SPRINT_STATUS)
8. Confirme a conclusão ao usuário

**WORKFLOW A EXECUTAR:**
Execute o workflow story-done seguindo as instruções em: $WORKFLOW_FILE

**IMPORTANTE:**
- A story foi completamente desenvolvida com todos os arquivos criados
- Todas as tasks e subtasks foram concluídas
- Todos os acceptance criteria foram atendidos
- A story está pronta para ser marcada como "done"
- Comunique-se em Português

Execute o workflow story-done agora para marcar a story como concluída.
EOF
)

echo ""
echo -e "${BLUE}Executando workflow story-done via cursor-agent CLI...${NC}"
echo ""

# Executar cursor-agent com o prompt
cursor-agent -p "$PROMPT"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Execução concluída${NC}"
echo -e "${GREEN}========================================${NC}"

# Verificar se o status foi atualizado
NEW_STATUS=$(grep "^Status:" "$STORY_FILE" | sed 's/Status: //' | tr -d ' ')
if [ "$NEW_STATUS" == "done" ]; then
    echo -e "${GREEN}✓ Story marcada como concluída com sucesso!${NC}"
else
    echo -e "${YELLOW}⚠️  Status atual: $NEW_STATUS${NC}"
fi

