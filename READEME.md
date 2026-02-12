Windows Update & Maintenance Everything Silent (v4.4)

Script robusto para manutenção profunda, limpeza de disco e atualização de softwares no Windows 10 e 11. Projetado para rodar de forma automática, movendo todas as interações para o final.

🚀 Como Executar (PowerShell Admin)

Para rodar o script diretamente da nuvem sem baixar arquivos manualmente, copie e cole o comando abaixo no seu PowerShell como Administrador:

Set-ExecutionPolicy Bypass -Scope Process -Force; iwr -useb https://raw.githubusercontent.com/murilogiatti/WindowsUpdateEverythingSilent/main/Update.ps1 | iex

🤖 Modo 100% Automático

Para rodar em servidores ou via agendador de tarefas (sem nenhuma pergunta ao final):

Set-ExecutionPolicy Bypass -Scope Process -Force; $script = iwr -useb https://raw.githubusercontent.com/murilogiatti/WindowsUpdateEverythingSilent/main/Update.ps1; Invoke-Expression "$script -SilentMode"

🛠️ O que o script realiza

Limpeza de Disco: Deleta arquivos temporários, Prefetch, cache de miniaturas e esvazia a lixeira.

Reparo de Sistema: Executa DISM (com /ResetBase para liberar espaço real em disco) e SFC Scannow.

Rede: Flush de DNS e reset total das pilhas TCP/IP e Winsock.

Software: Atualiza todos os apps via Winget silenciosamente e instala patches do Windows Update.

Otimização: Executa TRIM em SSDs e Defrag em HDDs.

🔄 Interações ao Final

O script executará todo o trabalho pesado primeiro. Apenas ao concluir (caso não use o -SilentMode), ele solicitará:

Agendamento de CHKDSK (Sim/Não).

Abertura da Microsoft Store para updates manuais (Sim/Não).

Reinicialização do sistema se houver updates pendentes (Sim/Não).

⚠️ Requisitos

Windows 10 ou 11.

Execução como Administrador.

Conexão com a internet.
