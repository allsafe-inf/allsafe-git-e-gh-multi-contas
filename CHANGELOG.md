# 📋 Changelog

## [Não lançado]

## [0.3.0] - 2026-10-09
### Alterado
- O fluxograma de como funciona fica aberto no README, com a sequência escrita logo abaixo.

## [0.2.2] - 2026-10-09
### Corrigido
- O comando de instalação do README traz o endereço do repositório da empresa.

## [0.2.1] - 2026-10-09
### Alterado
- Fotos do terminal refeitas com nomes de conta de exemplo e sem nome de repositório.
- Visualizadores de imagens e de diagramas sem o caminho local de quem os gerou.

## [0.2.0] - 2026-10-09
### Adicionado
- Qualquer número de contas, uma por linha `CONTA_<n>` no `.env`.
- Pasta `.secrets/` para o token de cada conta, guardado cifrado com `systemd-creds` na instalação.
- Auxiliar de credencial do `git` que escolhe a conta pelo dono do endereço do remoto.
- Invólucro do `gh` que escolhe a conta pelo pedido (`GH_CONTA`, `-R`, dono citado, remoto da pasta) e passa o token só ao processo.
- Comando `github-multiconta` com `contas`, `testar` e `esquecer`.
- Funcionamento de dentro do VS Code em Flatpak, pelas mesmas contas do computador.
- Bateria de testes em `testes/testar.sh`.
- Guia dos comandos, com a foto do terminal de cada um, em `doc/aplicacao/`.

### Alterado
- A instalação passa a ser o `instalar.sh`, idempotente e sem perguntas.
- README reescrito, com fluxograma do funcionamento.
- O projeto passa a se chamar `allsafe-git-e-gh-multi-contas`; os comandos continuam `github-multiconta`.

### Removido
- `configurar-git-github-multiconta.sh`, limitado a duas contas e com o token em texto no `~/.git-credentials`.

### Segurança
- Token cifrado em repouso e nunca mostrado em tela, log ou arquivo.
- Nenhum estado global no `gh`: sem `gh auth login` nem `gh auth switch`.

## [0.1.0] - 2026-09-02
### Adicionado
- Primeira versão: script para duas contas (pessoal e empresa) por HTTPS.
