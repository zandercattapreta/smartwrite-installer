# SmartWrite Installer

O **SmartWrite Installer** é um utilitário CLI interativo projetado para descobrir automaticamente cofres (vaults) do Obsidian e instalar de forma centralizada os plugins do ecossistema SmartWrite desenvolvidos pela Z•Edições.

> Parte do projeto "Programando sem saber código (uma aventura antigravitacional)" e do ecossistema SADE.

## 🚀 Funcionalidades Principais

- **Auto-Discovery:** Escaneia automaticamente as configurações locais do Obsidian (`obsidian.json`) e localiza todos os cofres do usuário no macOS.
- **Catálogo em Tempo Real:** Faz o fetch da lista atualizada de plugins disponíveis diretamente do repositório no GitHub (ou usa um catálogo local como fallback).
- **Instalação e Atualização Interativas:** Interface colorida no terminal que permite selecionar quais plugins instalar/atualizar via `git clone` e `git pull`.

## 📦 Lista de Plugins Suportados

1. **SmartWrite Companion:** Assistente de escrita local inteligente, com estatísticas e personas.
2. **SmartWriter Analyzer:** Analisador de qualidade de manuscritos (Ritmo, Legibilidade, Coerência).
3. **SmartWrite Publisher:** Utilitário para automação de publicações no Substack em lote.

## 💻 Como Usar

Certifique-se de que você possui `git`, `curl` e `jq` instalados em sua máquina.

```bash
# 1. Clone o instalador
git clone https://github.com/zandercpzed/smartwrite-installer.git
cd smartwrite-installer

# 2. Dê permissão de execução
chmod +x install.sh

# 3. Execute o assistente
./install.sh
```

## 📚 Documentação
Consulte a [Documentação Técnica e Funcional](DOCUMENTATION.md) para detalhes da arquitetura.

## 📄 Licença
Licenciado sob a [MIT License](LICENSE.md).
