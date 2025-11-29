#!/bin/bash

# Script para verificar configuração de ambiente do Cloud Agents
# Uso: bash .cursor/scripts/check-cloud-agents-env.sh

echo "=========================================="
echo "Verificação de Ambiente - Cloud Agents"
echo "=========================================="
echo ""

# Cores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função para verificar variável
check_var() {
    local var_name=$1
    local var_value="${!var_name}"
    
    if [ -n "$var_value" ]; then
        local length=${#var_value}
        echo -e "${GREEN}✅${NC} $var_name: Configurada (${length} caracteres)"
        return 0
    else
        echo -e "${RED}❌${NC} $var_name: Não configurada"
        return 1
    fi
}

# Verificar variáveis principais
echo "1. Variáveis de Ambiente:"
echo "-------------------------"
check_var "CURSOR_API_KEY"
echo ""

# Verificar se está rodando em Cloud Agent
echo "2. Ambiente:"
echo "------------"
if [ -n "$CLOUD_AGENT" ] || [ -n "$CURSOR_CLOUD_AGENT" ]; then
    echo -e "${GREEN}✅${NC} Rodando em Cloud Agent"
else
    echo -e "${YELLOW}⚠️${NC} Ambiente local (Cloud Agents secrets não disponíveis)"
fi
echo ""

# Verificar arquivos de configuração locais
echo "3. Arquivos de Configuração Local:"
echo "------------------------------------"
if [ -f ".cursor/api-key.txt" ]; then
    echo -e "${GREEN}✅${NC} .cursor/api-key.txt existe"
else
    echo -e "${YELLOW}⚠️${NC} .cursor/api-key.txt não encontrado"
fi

if [ -f "$HOME/.cursor/api-key" ]; then
    echo -e "${GREEN}✅${NC} ~/.cursor/api-key existe"
else
    echo -e "${YELLOW}⚠️${NC} ~/.cursor/api-key não encontrado"
fi
echo ""

# Verificar logs
echo "4. Logs de Debug:"
echo "------------------"
if [ -f "$HOME/.cursor/hooks-debug.log" ]; then
    echo -e "${GREEN}✅${NC} Logs disponíveis em ~/.cursor/hooks-debug.log"
    echo ""
    echo "Últimas entradas relacionadas a CURSOR_API_KEY:"
    tail -20 "$HOME/.cursor/hooks-debug.log" | grep -i "CURSOR_API_KEY" | tail -5 || echo "Nenhuma entrada encontrada"
else
    echo -e "${YELLOW}⚠️${NC} Arquivo de log não encontrado"
fi
echo ""

# Resumo e recomendações
echo "=========================================="
echo "Resumo e Recomendações:"
echo "=========================================="
echo ""

if [ -z "$CURSOR_API_KEY" ]; then
    echo -e "${RED}❌ CURSOR_API_KEY não está configurada${NC}"
    echo ""
    echo "Para configurar no Cloud Agents:"
    echo "1. Cursor Settings (Ctrl+,) → Cloud Agents → Secrets"
    echo "2. Adicione secret: CURSOR_API_KEY = sua_api_key"
    echo "3. Reinicie o Cloud Agent"
    echo ""
    echo "Para ambiente local:"
    echo "1. export CURSOR_API_KEY=sua_api_key"
    echo "2. Ou crie ~/.cursor/api-key"
else
    echo -e "${GREEN}✅ CURSOR_API_KEY está configurada${NC}"
    echo ""
    echo "Para verificar de onde foi carregada:"
    echo "tail -50 ~/.cursor/hooks-debug.log | grep CURSOR_API_KEY"
fi

echo ""
echo "Documentação completa: .cursor/docs/CLOUD-AGENTS-ENV.md"

