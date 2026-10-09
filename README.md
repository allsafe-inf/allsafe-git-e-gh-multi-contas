<div align="center">

# 🔐 allsafe-git-e-gh-multi-contas

**Várias contas do GitHub no mesmo computador, para `git` e `gh`: a conta certa é escolhida pelo dono do remoto, sem autenticação em nenhuma pasta.**

![Versão](https://img.shields.io/badge/versão-0.3.1-blue)
![Bash](https://img.shields.io/badge/Bash-5.2-4EAA25?logo=gnubash&logoColor=white)
![Git](https://img.shields.io/badge/Git-2.47-F05032?logo=git&logoColor=white)
![GitHub CLI](https://img.shields.io/badge/GitHub%20CLI-2.46-181717?logo=github&logoColor=white)
![systemd](https://img.shields.io/badge/systemd-257-30D475)
![Status](https://img.shields.io/badge/status-em%20uso-brightgreen)

<!-- diagrama: doc/diagramas/visao-geral-diagrama.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    usuario@{ shape: person, label: "Usuário" }
    instalar@{ shape: console, label: "instalar.sh<br>lê o .env e o .secrets" }
    multiconta@{ shape: rect, label: "github-multiconta<br>contas e tokens cifrados" }
    comandos@{ shape: console, label: "git e gh<br>em qualquer pasta" }
    github@{ shape: cloud, label: "GitHub<br>a conta do dono do remoto" }

    usuario --> instalar --> multiconta --> comandos --> github
```

<sub>Nível 1 · Diagrama · [fonte](doc/diagramas/)</sub>

</div>

**Sequência:** Usuário ➜ instalar.sh ➜ github-multiconta ➜ git e gh ➜ GitHub

<details>
<summary>Sumário — clique para expandir</summary>

[O que é](#o-que-e) · [Imagens](#imagens) · [Destaques](#destaques) · [Instalação rápida](#instalacao) · [Como funciona](#como-funciona) · [Tecnologias](#tecnologias) · [Configuração](#configuracao) · [Segurança](#seguranca) · [Testes](#testes) · [Solução de problemas](#problemas) · [Estrutura de arquivos](#arquivos) · [Plano](#plano) · [Versão](#versao)

</details>

---

<a name="o-que-e"></a>

## 💡 O que é

Quem tem mais de uma conta no GitHub (pessoal, empresa, cliente) precisa que cada repositório use a conta dona dele. Este kit resolve isso uma vez por computador: as contas ficam em um arquivo, o token de cada uma fica guardado cifrado, e daí em diante basta adicionar o remoto na pasta do projeto.

Vale para o `git` e para o `gh`, no terminal, no VS Code e nos agentes de IA (Claude Code e Codex, nativos e do VS Code em Flatpak).

| | |
|---|---|
| **Para quê** | Usar quantas contas do GitHub forem precisas, sem trocar de login e sem configurar cada pasta |
| **Tecnologias** | Bash · Git · GitHub CLI · systemd-creds |
| **Acesso** | Comandos `git`, `gh` e `github-multiconta`, em qualquer pasta |
| **Requisitos** | Linux com Bash 5 e Git 2.40 ou mais novo · `gh` para os comandos do GitHub · systemd 256 ou mais novo para guardar o token cifrado |

<a name="imagens"></a>

## 📸 Imagens

<a href="doc/imagens/terminal-principal.png"><img src="doc/imagens/terminal-principal.png" alt="Terminal com as contas instaladas e o teste de git e gh em ok nas duas contas" width="100%"></a>

<sub><b>v0.2.1</b> · contas instaladas e teste · captura de 2026-10-09</sub>

Nas fotos, os nomes das contas são de exemplo.

Cada comando, com a foto e a explicação: [comandos, um por um](doc/aplicacao/README.md).

<a name="destaques"></a>

## ✨ Destaques

| Destaque | Na prática |
|---|---|
| Quantas contas quiser | Cada conta é uma linha `CONTA_<n>` no `.env` e um arquivo de token em `.secrets/` |
| Nada de autenticação na pasta | Na pasta do projeto vai só `git remote add`; o dono do endereço escolhe a conta |
| `git` e `gh` com a mesma regra | O `gh` usa a conta do remoto da pasta, ou a que for dita em `GH_CONTA` ou `-R` |
| Token cifrado | Guardado com `systemd-creds`; o arquivo em texto é apagado na instalação |
| Rápido | O token é decifrado uma vez por sessão; depois, cada chamada custa cerca de 2 ms |
| Sem estado global | Nenhum `gh auth login` nem `gh auth switch`: dois agentes usam contas diferentes ao mesmo tempo |
| Funciona no Flatpak | Dentro do VS Code em Flatpak, os comandos rodam no computador e usam as mesmas contas |

<a name="instalacao"></a>

## 🚀 Instalação rápida

```bash
git clone https://github.com/allsafe-inf/allsafe-git-e-gh-multi-contas.git
cd allsafe-git-e-gh-multi-contas
cp .env.example .env    # ajuste as linhas CONTA_<n>
./instalar.sh
```

Antes de instalar, grave o token de cada conta em `.secrets/<login>.token`: um arquivo por conta, só o token. O `<login>` é o **nome de usuário da conta no GitHub**, o mesmo que está no campo do meio da linha `CONTA_<n>` do `.env`. Não é `conta1`, nem o nome do remoto (`origin`, `empresa`), nem o e-mail.

| Linha no `.env` | Arquivo do token |
|---|---|
| `CONTA_1=origin:maria-dev:maria-dev` | `.secrets/maria-dev.token` |
| `CONTA_2=empresa:maria-acme:acme-ltda` | `.secrets/maria-acme.token` |

O instalador confere o `.env`, guarda cada token cifrado, apaga o arquivo em texto, instala os comandos em `~/.local/bin` e liga o `git` ao auxiliar de credencial do GitHub. Pode ser rodado de novo quantas vezes for preciso.

| Quero | Comando |
|---|---|
| Instalar ou atualizar | `./instalar.sh` |
| Aproveitar os tokens que o Git já guarda neste computador | `./instalar.sh --importar-do-git` |
| Ver as contas e onde está cada token | `github-multiconta contas` |
| Conferir `git` e `gh` em cada conta | `github-multiconta testar` |
| Apagar a cópia dos tokens em memória | `github-multiconta esquecer` |
| Usar o `gh` com uma conta específica | `GH_CONTA=empresa gh repo list` |

<details>
<summary>Acrescentar uma conta, trocar um token e levar para outro computador — clique para expandir</summary>

Acrescentar uma conta:

```bash
echo 'CONTA_3=cliente:login-do-cliente:organizacao-do-cliente' >> .env
printf '%s' '<REDACTED>' > .secrets/login-do-cliente.token   # o token da conta
./instalar.sh
```

Trocar o token de uma conta: grave o token novo em `.secrets/<login>.token` e rode `./instalar.sh`.

Outro computador: copie esta pasta (sem o `.env` e sem tokens), crie o `.env` a partir do `.env.example`, grave os tokens em `.secrets/` e rode `./instalar.sh`. O token cifrado de um computador não abre em outro.

Ligar um projeto às contas, sem autenticação na pasta:

```bash
git remote add origin  https://github.com/<conta-pessoal>/<projeto>.git
git remote add empresa https://github.com/<organizacao>/<projeto>.git
git push origin main
git push empresa main
```

</details>

<a name="como-funciona"></a>

## 🔄 Como funciona

O `git` pergunta ao auxiliar qual é a credencial do endereço; o `gh` passa por um invólucro. Os dois descobrem o dono do repositório, acham a conta dele na lista e usam o token dessa conta só naquele comando.

<!-- diagrama: doc/diagramas/funcionamento-fluxograma.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart TD
    quem@{ shape: person, label: "Usuário ou IA" }
    git@{ shape: console, label: "git<br>push, pull, fetch, clone" }
    auxiliar@{ shape: console, label: "git-credential-github-multiconta<br>auxiliar de credencial" }
    gh@{ shape: console, label: "gh do github-multiconta<br>invólucro em ~/.local/bin" }
    lib@{ shape: rect, label: "lib.sh<br>escolhe a conta e lê o token" }
    tem@{ shape: diam, label: "a conta<br>tem token?" }
    github@{ shape: cloud, label: "GitHub" }
    aviso@{ shape: stadium, label: "para com aviso<br>conta sem token" }
    contas@{ shape: doc, label: "contas.conf<br>remoto, login e donos" }
    tokens@{ shape: docs, label: "tokens cifrados<br>um arquivo por conta" }
    sessao@{ shape: lin-cyl, label: "cópia da sessão<br>em memória, só do usuário" }

    quem -- "1a · roda um comando do git" --> git
    quem -- "1b · roda um comando do gh" --> gh
    git -- "2a · pede a credencial do endereço" --> auxiliar
    auxiliar -- "3a · informa o dono do endereço" --> lib
    gh -- "2b · informa o pedido e a pasta" --> lib
    lib -- "4 · conta escolhida" --> tem
    tem -- "5a · sim: segue com a conta certa, HTTPS 443" --> github
    tem -- "5b · não" --> aviso
    lib -. "lê" .-> contas
    lib -. "decifra uma vez por sessão" .-> tokens
    lib -. "lê e grava" .-> sessao
```

<sub>Nível 2 · Fluxograma · [fonte](doc/diagramas/)</sub>

| Nº | De ➜ Para | O que acontece |
|---|---|---|
| 1a | Usuário ou IA ➜ git | Alguém roda um comando do `git` que fala com o GitHub |
| 1b | Usuário ou IA ➜ gh do github-multiconta | Alguém roda um comando do `gh` |
| 2a | git ➜ git-credential-github-multiconta | O `git` pede a credencial do endereço do remoto |
| 3a | git-credential-github-multiconta ➜ lib.sh | O auxiliar informa o dono que aparece no endereço |
| 2b | gh do github-multiconta ➜ lib.sh | O invólucro informa o pedido e a pasta em que foi feito |
| 4 | lib.sh ➜ a conta tem token? | A conta do dono é escolhida e o token dela é procurado |
| 5a | a conta tem token? ➜ GitHub | Tem: o comando segue com a conta certa |
| 5b | a conta tem token? ➜ para com aviso | Não tem: o comando para e diz qual conta está sem token |

**Apoio**

| Quem | Usa | Como |
|---|---|---|
| lib.sh | contas.conf | lê a lista de contas |
| lib.sh | tokens cifrados | decifra uma vez por sessão |
| lib.sh | cópia da sessão | lê e grava a cópia em memória |


<details>
<summary>Como a conta é escolhida — clique para expandir</summary>

No `git`, nesta ordem:

1. o dono no endereço do remoto (`https://github.com/<dono>/<repo>.git`);
2. o login escrito no endereço (`https://<login>@github.com/...`);
3. a conta padrão, que é a de menor número no `.env`.

No `gh`, nesta ordem:

1. `GH_CONTA=<dono, login ou nome do remoto>`;
2. `-R <dono>/<repo>` ou `--repo`;
3. a variável `GH_REPO`;
4. o dono citado no comando (`gh repo view <dono>/<repo>`, `gh repo list <dono>`, `gh api repos/<dono>/...`, `orgs/<dono>`, `users/<dono>`);
5. o remoto `origin` da pasta atual;
6. a conta padrão.

Com `GH_TOKEN` ou `GITHUB_TOKEN` já definido, ou em `gh auth`, o invólucro não escolhe nada e repassa o comando como veio.

</details>

<a name="tecnologias"></a>

## 🛠️ Tecnologias

Tudo em Bash, sem serviço em execução e sem dependência a instalar além do que o sistema já traz.

<details>
<summary>Tecnologias, com nome e versão — clique para expandir</summary>

| Tecnologia | Versão | Papel no projeto |
|---|---|---|
| Bash | 5.2.37 | Linguagem dos comandos e do instalador |
| Git | 2.47.3 | Chama o auxiliar de credencial a cada acesso ao GitHub |
| GitHub CLI (`gh`) | 2.46.0 | Comandos do GitHub; recebe o token da conta escolhida |
| systemd (`systemd-creds`) | 257 | Cifra o token em repouso, preso ao usuário e ao computador |

</details>

<details>
<summary>Peso, medido — clique para expandir</summary>

Medido em 2026-10-09, na versão `0.2.0`:

| Operação | Tempo |
|---|---|
| Decifrar o token (primeira chamada da sessão) | 2,2 s |
| Ler a cópia da sessão (todas as chamadas seguintes) | 2 ms |

</details>

<a name="configuracao"></a>

## ⚙️ Configuração

As contas ficam no `.env` desta pasta. Nenhum token entra nele.

| Variável | Para que serve | Padrão |
|---|---|---|
| `CONTA_<n>` | Uma conta: `<remoto>:<login>:<dono>[,<dono>...]`. A de menor número é a padrão | sem padrão |
| `GIT_NOME` | Nome usado nos commits (`user.name`); vazio não altera | vazio |
| `GIT_EMAIL` | E-mail usado nos commits (`user.email`); vazio não altera | vazio |
| `CIFRAR` | `auto` cifra quando o computador permite; `sim` exige; `nao` guarda em texto protegido | `auto` |
| `GH_LINKS` | Pastas, separadas por `:`, que recebem um link para o `gh` (caminho de programas dos agentes em Flatpak) | vazio |

<details>
<summary>Onde cada coisa fica depois de instalar — clique para expandir</summary>

| Caminho | O que é |
|---|---|
| `~/.config/github-multiconta/contas.conf` | Lista de contas gerada do `.env` |
| `~/.config/github-multiconta/.secrets/<login>.cred` | Token cifrado da conta |
| `~/.local/share/github-multiconta/lib.sh` | Biblioteca usada pelos três comandos |
| `~/.local/bin/gh` | Invólucro do `gh` |
| `~/.local/bin/git-credential-github-multiconta` | Auxiliar de credencial do `git` |
| `~/.local/bin/github-multiconta` | Comandos `contas`, `testar` e `esquecer` |

No `~/.gitconfig`, o instalador grava o auxiliar só para `https://github.com` e liga `useHttpPath`, para o `git` informar o dono do endereço. Outros servidores não são afetados.

</details>

<a name="seguranca"></a>

## 🔐 Segurança

- O token fica cifrado em disco, preso ao usuário e ao computador; o arquivo em texto posto em `.secrets/` é apagado na instalação.
- Nenhum comando mostra token em tela, log ou arquivo.
- O `gh` recebe o token só no processo do comando; nada fica gravado na configuração dele.
- O `.env` e o `.secrets/` ficam fora do Git.

<details>
<summary>Proteções aplicadas, uma a uma — clique para expandir</summary>

| Proteção | Como |
|---|---|
| Token em repouso | `systemd-creds --user`; sem systemd 256 ou mais novo, arquivo `0600` com aviso |
| Cópia da sessão | Em memória (`$XDG_RUNTIME_DIR`), `0600`, some ao encerrar a sessão; `github-multiconta esquecer` apaga na hora |
| Pastas e arquivos | `.secrets/` em `0700`; `contas.conf`, tokens e `.env` em `0600` |
| Auxiliar só de leitura | Responde só a `github.com` e ignora pedidos de gravar ou apagar credencial |
| `.env` lido como texto | Nunca é executado; nomes de conta, login e dono são validados |
| Token validado | Formato conferido antes de guardar; conta sem token faz o comando parar, sem usar outra conta |
| Escopo do token | `repo` e `read:org` bastam para tudo o que o kit faz |

</details>

<a name="testes"></a>

## 🧪 Testes

| Quero | Comando | Resultado esperado |
|---|---|---|
| Testar o kit sem tocar nas contas reais | `./testes/testar.sh` | `Resultado: 108 ok, 0 falha(s).` |
| Conferir as contas instaladas | `github-multiconta testar` | `ok` em `git` e em `gh` para cada conta |

A bateria roda em uma pasta de trabalho separada (`$TEMP_DIR/github-multiconta/testes`, ou a que for passada no comando), com contas e tokens fictícios e um `gh` de teste.

<a name="problemas"></a>

## 🚨 Solução de problemas

| Sintoma | Causa | Correção |
|---|---|---|
| `Repository not found` em repositório que existe | O dono do remoto não está em nenhuma conta | Acrescente o dono à linha `CONTA_<n>` da conta e rode `./instalar.sh` |
| O comando para dizendo que a conta está sem token | Falta o arquivo do token | Grave `.secrets/<login>.token` e rode `./instalar.sh` |
| `gh` usa a conta padrão fora de repositório | Não há remoto para decidir | Diga a conta: `GH_CONTA=<conta> gh ...` ou `-R <dono>/<repo>` |
| `missing required scope 'read:org'` | Token sem o escopo | Gere outro token com `repo` e `read:org` e troque |
| Primeira chamada do dia demora cerca de 2 s | O token está sendo decifrado | Esperado; as seguintes usam a cópia da sessão |

<a name="arquivos"></a>

## 🗂️ Estrutura de arquivos

| Caminho | O que é |
|---|---|
| [`instalar.sh`](instalar.sh) | Instalação em um comando |
| [`.env.example`](.env.example) | Modelo do `.env`, com comentário em cada variável |
| `.secrets/` | Onde o token de cada conta é posto antes de instalar |
| [`bin/gh`](bin/gh) | Invólucro do `gh` |
| [`bin/git-credential-github-multiconta`](bin/git-credential-github-multiconta) | Auxiliar de credencial do `git` |
| [`bin/github-multiconta`](bin/github-multiconta) | Comandos `contas`, `testar` e `esquecer` |
| [`lib/github-multiconta.sh`](lib/github-multiconta.sh) | Escolha da conta e leitura do token |
| [`testes/testar.sh`](testes/testar.sh) | Bateria de testes |
| [`doc/`](doc/README.md) | Guia dos comandos com fotos, imagens e fontes dos diagramas |

<a name="plano"></a>

## 🗺️ Plano

O plano de criação e mudança (alternativas, testes, evidências e progresso) é privado e fica em repositório próprio, fora deste. Status: versão 0.3.0 concluída.

<a name="versao"></a>

## 🏷️ Versão

Versão atual: **0.3.1** · histórico em [CHANGELOG.md](CHANGELOG.md).
