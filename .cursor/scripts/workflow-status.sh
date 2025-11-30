#!/bin/bash

# Script para executar workflow-status workflow usando cursor-agent CLI
# Uso: ./workflow-status.sh
# Este workflow apenas retorna o status encontrado no diretório

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
WORKFLOW_FILE="${PROJECT_ROOT}/.bmad/bmm/workflows/workflow-status/workflow.yaml"
WORKFLOW_INSTRUCTIONS="${PROJECT_ROOT}/.bmad/bmm/workflows/workflow-status/instructions.md"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Verificando Status do Workflow${NC}"
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

# Verificar se o workflow existe
if [ ! -f "$WORKFLOW_FILE" ]; then
    echo -e "${RED}Erro: Workflow file não encontrado: $WORKFLOW_FILE${NC}"
    exit 1
fi

if [ ! -f "$WORKFLOW_INSTRUCTIONS" ]; then
    echo -e "${YELLOW}⚠️  Workflow instructions não encontrado: $WORKFLOW_INSTRUCTIONS (continuando sem ele)${NC}"
    WORKFLOW_INSTRUCTIONS=""
fi

echo -e "${GREEN}✓ Workflow file encontrado: $WORKFLOW_FILE${NC}"
if [ -n "$WORKFLOW_INSTRUCTIONS" ]; then
    echo -e "${GREEN}✓ Workflow instructions encontrado: $WORKFLOW_INSTRUCTIONS${NC}"
fi

# Preparar prompt para o cursor-agent
PROMPT=$(cat <<EOF
Você é um agente do BMad Method. Siga as instruções de ativação do agente apropriado.

**CONTEXTO DO PROJETO:**
- Projeto: $(basename "$PROJECT_ROOT")
- Usuário: Luis
- Linguagem de comunicação: Português

**INSTRUÇÕES:**

1. Carregue o arquivo de configuração: $BMAD_CONFIG
2. Carregue o workflow YAML: $WORKFLOW_FILE
$(if [ -n "$WORKFLOW_INSTRUCTIONS" ]; then
    echo "3. Carregue as instruções do workflow: $WORKFLOW_INSTRUCTIONS"
    echo "4. Execute o workflow workflow-status seguindo TODAS as instruções do arquivo de instruções"
else
    echo "3. Execute o workflow workflow-status usando o workflow YAML"
fi)
5. Leia o arquivo YAML de status do workflow
6. Responda à pergunta "o que devo fazer agora?" para qualquer agente
7. Retorne o status encontrado no diretório
8. Comunique-se em Português

**WORKFLOW A EXECUTAR:**
$(if [ -n "$WORKFLOW_INSTRUCTIONS" ]; then
    echo "Execute o workflow workflow-status seguindo as instruções em: $WORKFLOW_INSTRUCTIONS"
else
    echo "Execute o workflow workflow-status usando: $WORKFLOW_FILE"
fi)

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

