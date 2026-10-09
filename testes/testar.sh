#!/usr/bin/env bash
# Bateria de testes do github-multiconta. Roda em uma pasta pessoal de mentira, com contas e tokens
# fictícios e um gh de mentira: não toca no ~/.gitconfig, nos tokens nem no GitHub de verdade.
# Uso: testes/testar.sh [pasta-de-trabalho]   (padrão: $TEMP_DIR/github-multiconta/testes; sem TEMP_DIR, a pasta temporária do sistema)
set -uo pipefail
KIT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
T="${1:-${TEMP_DIR:-${TMPDIR:-/tmp}}/github-multiconta/testes}"
rm -rf -- "$T"; mkdir -p "$T"/{home,stub,run,kit/.secrets,fora}; chmod 700 "$T/run"
export HOME="$T/home" XDG_RUNTIME_DIR="$T/run" GIT_TERMINAL_PROMPT=0
unset XDG_CONFIG_HOME GH_TOKEN GITHUB_TOKEN GH_CONTA GH_REPO GIT_ASKPASS SSH_ASKPASS
export GIT_CONFIG_NOSYSTEM=1
PATH_BASE="$PATH"
export PATH="$HOME/.local/bin:$T/stub:$PATH_BASE"
TA=ghp_ficticioAAAAAAAAAAAAAAAAAAAAAAAAAAAA1
TB=ghp_ficticioBBBBBBBBBBBBBBBBBBBBBBBBBBBB2
TC=github_pat_ficticioCCCCCCCCCCCCCCCCCCCCC3
printf '#!/usr/bin/env bash\nprintf "TOKEN=%%s ARGS=%%s\\n" "${GH_TOKEN:-vazio}" "$*"\n' > "$T/stub/gh"; chmod 755 "$T/stub/gh"

ok=0; falhou=0
confere() { # confere <descrição> <esperado> <obtido>
  if [[ "$3" == "$2" ]]; then ok=$((ok+1)); printf 'ok      %s\n' "$1"
  else falhou=$((falhou+1)); printf 'FALHOU  %s\n          esperado: %s\n          obtido:   %s\n' "$1" "$2" "$3"; fi
}
contem() { # contem <descrição> <trecho> <texto>
  if [[ "$3" == *"$2"* ]]; then ok=$((ok+1)); printf 'ok      %s\n' "$1"
  else falhou=$((falhou+1)); printf 'FALHOU  %s\n          faltou: %s\n' "$1" "$2"; fi
}
escreve_env() { printf '%s\n' "$@" > "$T/kit/.env"; }
tokens_no_kit() { printf '%s\n' "$TA" > "$T/kit/.secrets/pessoa-a.token"; printf '%s\n' "$TB" > "$T/kit/.secrets/empresa-b.token"; printf '  %s  \r\n' "$TC" > "$T/kit/.secrets/cliente-c.token"; }
instala() { GHM_KIT_ENV="$T/kit/.env" GHM_KIT_SEGREDOS="$T/kit/.secrets" bash "$KIT/instalar.sh" "$@" 2>&1; }
senha_git() { printf 'protocol=https\nhost=github.com\n%s\n' "$1" | git credential fill 2>/dev/null | sed -n 's/^\(username\|password\)=//p' | tr '\n' ' '; }
limpa_instalacao() { rm -rf -- "$HOME" "$T/run"; mkdir -p "$HOME" "$T/run"; chmod 700 "$T/run"; }

CONTAS=("CONTA_2=empresa:empresa-b:org-b" "CONTA_1=origin:pessoa-a:pessoa-a" "CONTA_10=cliente:cliente-c:org-c1,Org-C2")

for modo in nao auto; do
  echo "== CIFRAR=$modo"
  limpa_instalacao
  escreve_env "# comentário" "${CONTAS[@]}" "CIFRAR=$modo" "GIT_NOME=\"Nome de Teste\"" "GIT_EMAIL=teste@exemplo.invalid" "GH_LINKS=$T/home/outro/bin"
  tokens_no_kit
  saida="$(instala)"; confere "[$modo] instala com três contas" 0 $?
  [[ "$saida" == *ficticio* ]] && confere "[$modo] instalador não mostra token" "sem token" "token na saída" || confere "[$modo] instalador não mostra token" x x
  confere "[$modo] token em texto some da pasta do kit" "" "$(ls "$T/kit/.secrets")"
  confere "[$modo] pasta de segredos 0700" 700 "$(stat -c %a "$HOME/.config/github-multiconta/.secrets")"
  confere "[$modo] arquivos de segredo 0600" "" "$(find "$HOME/.config/github-multiconta" -type f ! -perm 600)"
  if [[ "$modo" == nao ]]; then ext=token; else ext=cred; fi
  if [[ "$modo" == auto && "$saida" != *"cifrados com systemd-creds"* ]]; then ext=token; echo "        (este equipamento não cifra: conferindo o modo texto)"; fi
  confere "[$modo] um arquivo por conta (.$ext)" "cliente-c.$ext empresa-b.$ext pessoa-a.$ext" "$(ls "$HOME/.config/github-multiconta/.secrets" | tr '\n' ' ' | sed 's/ $//')"
  [[ "$ext" == cred ]] && confere "[$modo] arquivo cifrado não contém o token" 0 "$(grep -c ficticio "$HOME/.config/github-multiconta/.secrets/pessoa-a.cred")"
  confere "[$modo] conta de menor número é a padrão" "origin pessoa-a pessoa-a" "$(grep -v '^#' "$HOME/.config/github-multiconta/contas.conf" | head -1)"
  confere "[$modo] identidade dos commits" "Nome de Teste <teste@exemplo.invalid>" "$(git config --global user.name) <$(git config --global user.email)>"
  confere "[$modo] gh também na pasta extra" "$HOME/.local/bin/gh" "$(readlink "$T/home/outro/bin/gh")"

  confere "[$modo] git: dono da conta pessoal" "pessoa-a $TA " "$(senha_git path=pessoa-a/repo.git)"
  confere "[$modo] git: dono da empresa" "empresa-b $TB " "$(senha_git path=org-b/repo.git)"
  confere "[$modo] git: segundo dono do mesmo token, sem diferenciar maiúsculas" "cliente-c $TC " "$(senha_git path=org-c2/repo.git)"
  confere "[$modo] git: URL antiga com login e dono da empresa" "empresa-b $TB " "$(senha_git $'username=empresa-b\npath=org-b/repo.git')"
  confere "[$modo] git: dono vence o login que veio na URL" "empresa-b $TB " "$(senha_git $'username=pessoa-a\npath=org-b/repo.git')"
  confere "[$modo] git: só o login, dono desconhecido" "cliente-c $TC " "$(senha_git $'username=cliente-c\npath=terceiro/repo.git')"
  confere "[$modo] git: dono desconhecido sem login usa a padrão" "pessoa-a $TA " "$(senha_git path=terceiro/repo.git)"
  confere "[$modo] git: login desconhecido não recebe token" "" "$(senha_git $'username=ninguem\npath=terceiro/repo.git' | grep -o ficticio)"
  confere "[$modo] git: outro servidor não recebe token" "" "$(printf 'protocol=https\nhost=gitlab.com\npath=pessoa-a/x.git\n\n' | git credential fill 2>/dev/null | grep -o ficticio)"
  printf 'protocol=https\nhost=github.com\npath=org-b/repo.git\nusername=empresa-b\npassword=errada\n\n' | git credential reject
  confere "[$modo] git: recusa de senha não apaga o token" "empresa-b $TB " "$(senha_git path=org-b/repo.git)"

  cd "$T/fora" || exit 1
  confere "[$modo] gh: -R escolhe pelo dono" "TOKEN=$TB ARGS=-R org-b/x release list" "$(gh -R org-b/x release list)"
  confere "[$modo] gh: --repo=" "TOKEN=$TC ARGS=release list --repo=org-c1/x" "$(gh release list --repo=org-c1/x)"
  confere "[$modo] gh: GH_REPO" "TOKEN=$TB ARGS=release list" "$(GH_REPO=org-b/x gh release list)"
  confere "[$modo] gh: caminho da API" "TOKEN=$TC ARGS=api repos/org-c2/x/releases" "$(gh api repos/org-c2/x/releases)"
  confere "[$modo] gh: DONO/REPO em argumento" "TOKEN=$TB ARGS=repo view org-b/x" "$(gh repo view org-b/x)"
  confere "[$modo] gh: dono sozinho em argumento" "TOKEN=$TC ARGS=repo list org-c1" "$(gh repo list org-c1)"
  confere "[$modo] gh: GH_CONTA pelo nome do remoto" "TOKEN=$TB ARGS=api user" "$(GH_CONTA=empresa gh api user)"
  confere "[$modo] gh: GH_CONTA vence o -R" "TOKEN=$TA ARGS=-R org-b/x issue list" "$(GH_CONTA=pessoa-a gh -R org-b/x issue list)"
  confere "[$modo] gh: fora de repositório usa a padrão" "TOKEN=$TA ARGS=api user" "$(gh api user)"
  confere "[$modo] gh: GH_CONTA desconhecida falha" 4 "$(GH_CONTA=ninguem gh api user >/dev/null 2>&1; echo $?)"
  confere "[$modo] gh: GH_TOKEN de quem chamou passa direto" "TOKEN=de-fora ARGS=api user" "$(GH_TOKEN=de-fora gh -R org-b/x api user | sed 's/-R org-b\/x //')"
  confere "[$modo] gh: auth login sem token" "TOKEN=vazio ARGS=auth login" "$(gh auth login)"
  rm -rf "$T/repo"; git init -q "$T/repo"; git -C "$T/repo" remote add origin https://github.com/org-b/projeto.git; git -C "$T/repo" remote add outro https://github.com/pessoa-a/projeto.git
  confere "[$modo] gh: remoto origin da pasta" "TOKEN=$TB ARGS=pr list" "$(cd "$T/repo" && gh pr list)"
  confere "[$modo] gh: pela pasta extra (como no Flatpak)" "TOKEN=$TB ARGS=-R org-b/x pr list" "$(PATH="$T/home/outro/bin:$T/stub:$PATH_BASE" gh -R org-b/x pr list)"

  contem "[$modo] github-multiconta contas" "cliente-c" "$(github-multiconta contas)"
  confere "[$modo] github-multiconta contas não mostra token" 0 "$(github-multiconta contas | grep -c ficticio)"
  if [[ "$ext" == cred ]]; then
    confere "[$modo] cópia da sessão 0600" 600 "$(stat -c %a "$T/run/github-multiconta/pessoa-a")"
    ini=$(date +%s%N); for _ in 1 2 3 4 5; do gh api user >/dev/null; done; ms=$(( ($(date +%s%N) - ini) / 5000000 ))
    if [[ $ms -lt 300 ]]; then confere "[$modo] gh com a cópia da sessão: ${ms} ms por chamada" x x; else confere "[$modo] gh com a cópia da sessão abaixo de 300 ms" "<300" "$ms"; fi
    github-multiconta esquecer >/dev/null
    confere "[$modo] esquecer apaga as cópias da sessão" "" "$(ls "$T/run" 2>/dev/null)"
    confere "[$modo] depois de esquecer, decifra de novo" "pessoa-a $TA " "$(senha_git path=pessoa-a/repo.git)"
  fi

  antes="$(cat "$HOME/.gitconfig")"
  saida="$(instala)"; confere "[$modo] segunda instalação (idempotente)" 0 $?
  contem "[$modo] segunda instalação mantém os tokens" "token mantido" "$saida"
  confere "[$modo] segunda instalação não muda o .gitconfig" "$antes" "$(cat "$HOME/.gitconfig")"
  confere "[$modo] um só auxiliar para o github.com" 2 "$(git config --global --get-all credential.https://github.com.helper | wc -l)"

  NOVO=ghp_ficticioNOVOAAAAAAAAAAAAAAAAAAAAAAAA9
  printf '%s\n' "$NOVO" > "$T/kit/.secrets/pessoa-a.token"
  saida="$(instala)"; contem "[$modo] troca de token" "token novo guardado" "$saida"
  confere "[$modo] token trocado vale na hora" "pessoa-a $NOVO " "$(senha_git path=pessoa-a/repo.git)"
done

echo "== conta sem token, .env inválido e importação"
limpa_instalacao
escreve_env "${CONTAS[@]}" "CIFRAR=nao"
printf '%s\n' "$TA" > "$T/kit/.secrets/pessoa-a.token"
saida="$(instala)"; confere "conta sem token: termina com erro" 1 $?
contem "conta sem token: diz quantas faltam" "2 conta(s) sem token" "$saida"
confere "conta sem token: a que tem token funciona" "pessoa-a $TA " "$(senha_git path=pessoa-a/repo.git)"
confere "conta sem token: git não recebe senha" "" "$(senha_git path=org-b/repo.git | grep -o ficticio)"
confere "conta sem token: gh avisa e sai com 4" 4 "$(gh -R org-b/x pr list >/dev/null 2>&1; echo $?)"

printf 'https://empresa-b:%s@github.com\nhttps://cliente-c:%s@github.com\n' "$TB" "$TC" > "$HOME/.git-credentials"; chmod 600 "$HOME/.git-credentials"
soma="$(sha256sum < "$HOME/.git-credentials")"
saida="$(instala --importar-do-git)"; confere "importação do git: instala" 0 $?
contem "importação do git: avisa de onde veio" "token importado do git" "$saida"
confere "importação do git: não mostra token" 0 "$(grep -c ficticio <<< "$saida")"
confere "importação do git: token vale" "cliente-c $TC " "$(senha_git path=org-c1/repo.git)"
confere "importação do git: ~/.git-credentials intacto" "$soma" "$(sha256sum < "$HOME/.git-credentials")"

escreve_env "CONTA_1=origin:pessoa-a" "CIFRAR=nao"
saida="$(instala)"; confere "dono omitido vale o login" 0 $?
confere "dono omitido vale o login (contas.conf)" "origin pessoa-a pessoa-a" "$(grep -v '^#' "$HOME/.config/github-multiconta/contas.conf")"
contem "conta que saiu do .env é avisada, não apagada" "saiu do .env" "$saida"
for ruim in "CONTA_1=origin:../../etc:x" "CONTA_1=origin:pessoa a:x" "CONTA_1=ori gin:pessoa-a:x" "CONTA_1=origin:pessoa-a:dono;rm" "CONTA_1=a:b:c:d" "CIFRAR=talvez"; do
  escreve_env "CONTA_2=origin:pessoa-a:pessoa-a" "$ruim"
  instala >/dev/null; confere ".env inválido é recusado: $ruim" 1 $?
done
escreve_env "CONTA_1=origin:pessoa-a:pessoa-a" "CIFRAR=nao"
printf 'isto nao e token\n' > "$T/kit/.secrets/pessoa-a.token"
saida="$(instala)"; contem "token com formato estranho não é guardado" "formato inesperado" "$saida"
rm -f "$T/kit/.secrets/pessoa-a.token"
rm -f "$T/kit/.env"; instala >/dev/null; confere "sem .env: erro claro" 1 $?

echo
echo "Resultado: $ok ok, $falhou falha(s). Pasta de trabalho: $T"
[[ $falhou -eq 0 ]]
