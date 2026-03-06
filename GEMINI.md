# GEMINI - SmartWrite Installer

## Objetivo
Scripts de automação e instalação para a suíte SmartWrite.

## Regras de Ouro (MANDATÓRIAS)
Este projeto segue rigorosamente o [MASTER_GUIDELINES.md](../../MASTER_GUIDELINES.md) localizado na raiz do workspace.

### 1. Protocolo APAE
Obrigatório para qualquer mudança lógica em scripts:
- **Analyze**: Analisar o impacto do script no sistema.
- **Plan**: Detalhar comandos destrutivos antes de rodar.
- **Authorize**: Pedir "Posso prosseguir?".
- **Execute**: Implementar após autorização.

### 2. Regras de Interrupção
- **STOP / PARE**: Interrompa imediatamente sem questionar.
- **Fail Fast**: Erro 1x -> Pare, analise e aguarde.

### 3. Idiomas
- **Documentação/Chat**: Português (PT-BR).
- **Código/Commits**: Inglês (EN-US).
