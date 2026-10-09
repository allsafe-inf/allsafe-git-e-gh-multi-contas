#!/usr/bin/env bash
# Instala o github-multiconta neste equipamento: várias contas do GitHub para o git e para o gh,
# escolhidas pelo dono do repositório. Um comando, sem perguntas, e pode ser repetido.
#
# Uso: ./instalar.sh [--importar-do-git]
#   --importar-do-git  conta sem token em .secrets/ e sem token instalado: aproveita o que a versão
#                      antiga deste kit gravou no git (~/.git-credentials), sem mostrar nem apagar nada
#
# Lê:    .env (contas e opções) e .secrets/<login>.token (token novo de cada conta)
# Grava: ~/.config/github-multiconta/ (contas.conf e .secrets/), ~/.local/share/github-multiconta/,
#        ~/.local/bin/{gh,github-multiconta,git-credential-github-multiconta} e o ~/.gitconfig
# Nunca mostra token. O token lido de .secrets/ do kit é guardado (cifrado, se der) e o arquivo
# em texto é apagado.
set -Eeuo pipefail

AQUI="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
# Dentro do Flatpak não há systemd-creds: instala pelo host, que tem a mesma pasta pessoal.
if [[ -e /.flatpak-info ]] && command -v flatpak-spawn >/dev/null 2>&1; then
  exec flatpak-spawn --host --directory="$PWD" bash "$AQUI/instalar.sh" "$@"
fi

ARQ_ENV="${GHM_KIT_ENV:-$AQUI/.env}"
SEG_KIT="${GHM_KIT_SEGREDOS:-$AQUI/.secrets}"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}/github-multiconta"
SHARE="$HOME/.local/share/github-multiconta"
BIN="$HOME/.local/bin"
NOME_OK='^[A-Za-z0-9][A-Za-z0-9-]*$'

info()  { printf '%s\n' "$*"; }
aviso() { printf 'AVISO: %s\n' "$*" >&2; }
erro()  { printf 'ERRO: %s\n' "$*" >&2; exit 1; }

importar=false
for a in "$@"; do
  case "$a" in
    --importar-do-git) importar=true ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) erro "opção inválida: $a" ;;
  esac
done
command -v git >/dev/null 2>&1 || erro "git não está instalado"
[[ -r "$ARQ_ENV" ]] || erro "falta o $ARQ_ENV: copie o .env.example para .env e ajuste as contas"

# --- .env: lido como texto, nunca executado -------------------------------------------------
GIT_NOME="" GIT_EMAIL="" CIFRAR=auto GH_LINKS=""
declare -A linha_conta=()
while IFS= read -r l || [[ -n "$l" ]]; do
  [[ "$l" =~ ^[[:space:]]*([A-Z][A-Z0-9_]*)=(.*)$ ]] || continue
  chave="${BASH_REMATCH[1]}"; valor="${BASH_REMATCH[2]}"
  valor="${valor%$'\r'}"; valor="${valor%"${valor##*[![:space:]]}"}"
  [[ "$valor" == \"*\" || "$valor" == \'*\' ]] && valor="${valor:1:${#valor}-2}"
  case "$chave" in
    GIT_NOME) GIT_NOME="$valor" ;;
    GIT_EMAIL) GIT_EMAIL="$valor" ;;
    CIFRAR) CIFRAR="$valor" ;;
    GH_LINKS) GH_LINKS="$valor" ;;
    CONTA_*) [[ "${chave#CONTA_}" =~ ^[0-9]+$ ]] && linha_conta[${chave#CONTA_}]="$valor" ;;
  esac
done < "$ARQ_ENV"

remotos=() logins=() donos=()
while read -r n; do
  [[ -n "$n" ]] || continue
  IFS=: read -r r lg ds extra <<< "${linha_conta[$n]}"
  [[ -z "${extra:-}" && "$r" =~ $NOME_OK && "$lg" =~ $NOME_OK ]] || erro "CONTA_$n inválida: use <remoto>:<login>:<dono>[,<dono>...]"
  ds="${ds:-$lg}"
  IFS=, read -ra lista <<< "$ds"
  for d in "${lista[@]}"; do [[ "$d" =~ $NOME_OK ]] || erro "CONTA_$n: dono inválido: $d"; done
  remotos+=("$r"); logins+=("$lg"); donos+=("$ds")
done < <(printf '%s\n' "${!linha_conta[@]}" | sort -n)
[[ ${#logins[@]} -gt 0 ]] || erro "nenhuma conta no $ARQ_ENV (CONTA_1=<remoto>:<login>:<dono>)"

# --- pastas e programas -----------------------------------------------------------------------
umask 077
mkdir -p "$CONF/.secrets" "$SHARE" "$BIN"
chmod 700 "$CONF" "$CONF/.secrets"
install -m 0644 "$AQUI/lib/github-multiconta.sh" "$SHARE/lib.sh"
for p in gh github-multiconta git-credential-github-multiconta; do install -m 0755 "$AQUI/bin/$p" "$BIN/$p"; done
IFS=: read -ra links <<< "$GH_LINKS"
for d in "${links[@]}"; do
  [[ -n "$d" ]] || continue
  d="${d/#\~/$HOME}"
  mkdir -p "$d" && ln -sfn "$BIN/gh" "$d/gh" && info "gh também em $d"
done

# --- cifrar ou não ----------------------------------------------------------------------------
# 2>&1 >/dev/null: aqui o que interessa é só se o systemd-creds deste equipamento cifra para o usuário.
pode_cifrar() { command -v systemd-creds >/dev/null 2>&1 && printf t | systemd-creds --user --name=github-multiconta-teste encrypt - - >/dev/null 2>&1; }
case "$CIFRAR" in
  nao) cifra=false ;;
  sim) pode_cifrar || erro "CIFRAR=sim, mas o systemd-creds deste equipamento não cifra para o usuário (precisa do systemd 256 ou mais novo)"; cifra=true ;;
  auto) if pode_cifrar; then cifra=true; else cifra=false; aviso "sem systemd-creds para o usuário: tokens ficam em texto, com permissão 0600"; fi ;;
  *) erro "CIFRAR=$CIFRAR inválido: use auto, sim ou nao" ;;
esac

apagar() { # apaga um arquivo de segredo
  [[ -e "$1" ]] || return 0
  if command -v shred >/dev/null 2>&1; then shred -u -- "$1"; else rm -f -- "$1"; fi
}

TOK=""
guardar() { # guardar <login>: grava o token que está em TOK
  local login="$1" dest="$CONF/.secrets/$1"
  [[ "$TOK" =~ ^[A-Za-z0-9_]{20,}$ ]] || { aviso "token de $login com formato inesperado: não foi guardado"; return 1; }
  if $cifra; then
    printf '%s' "$TOK" | systemd-creds --user --name="github-multiconta-$login" encrypt - "$dest.cred.novo"
    chmod 600 "$dest.cred.novo"; mv -f "$dest.cred.novo" "$dest.cred"; apagar "$dest.token"
  else
    printf '%s\n' "$TOK" > "$dest.token.novo"; chmod 600 "$dest.token.novo"; mv -f "$dest.token.novo" "$dest.token"; rm -f -- "$dest.cred"
  fi
  [[ -n "${XDG_RUNTIME_DIR:-}" ]] && rm -f -- "$XDG_RUNTIME_DIR/github-multiconta/$login"
  return 0
}

# --- tokens -----------------------------------------------------------------------------------
faltam=0; estado=()
for i in "${!logins[@]}"; do
  lg="${logins[i]}"; TOK=""
  if [[ -s "$SEG_KIT/$lg.token" ]]; then
    TOK="$(<"$SEG_KIT/$lg.token")"; TOK="${TOK//[$'\r\n\t ']/}"
    if guardar "$lg"; then apagar "$SEG_KIT/$lg.token"; estado[i]="token novo guardado"; else estado[i]="SEM TOKEN"; faltam=$((faltam+1)); fi
  elif [[ -s "$CONF/.secrets/$lg.cred" ]]; then
    estado[i]="token mantido"
  elif [[ -s "$CONF/.secrets/$lg.token" ]]; then
    estado[i]="token mantido"
    if $cifra; then TOK="$(<"$CONF/.secrets/$lg.token")"; TOK="${TOK//[$'\r\n\t ']/}"; guardar "$lg" && estado[i]="token mantido, agora cifrado"; fi
  elif $importar; then
    while IFS='=' read -r chave valor; do [[ "$chave" == password ]] && TOK="$valor"; done \
      < <(printf 'protocol=https\nhost=github.com\nusername=%s\n\n' "$lg" | git credential-store get)
    if [[ -n "$TOK" ]] && guardar "$lg"; then estado[i]="token importado do git"; else estado[i]="SEM TOKEN"; faltam=$((faltam+1)); fi
  else
    estado[i]="SEM TOKEN"; faltam=$((faltam+1))
  fi
  TOK=""
done

# --- contas.conf ------------------------------------------------------------------------------
{
  echo "# Gerado pelo instalar.sh a partir do .env do kit. Não edite aqui: edite o .env e rode de novo."
  echo "# <remoto> <login> <dono>[,<dono>...]   (a primeira linha é a conta padrão)"
  for i in "${!logins[@]}"; do printf '%s %s %s\n' "${remotos[i]}" "${logins[i]}" "${donos[i]}"; done
} > "$CONF/contas.conf.novo"
chmod 600 "$CONF/contas.conf.novo"; mv -f "$CONF/contas.conf.novo" "$CONF/contas.conf"

# --- git --------------------------------------------------------------------------------------
gc() { git config --global "$@"; }
[[ -z "$GIT_NOME" ]] || gc user.name "$GIT_NOME"
[[ -z "$GIT_EMAIL" ]] || gc user.email "$GIT_EMAIL"
gc --get init.defaultBranch >/dev/null || gc init.defaultBranch main
gc --get push.autoSetupRemote >/dev/null || gc push.autoSetupRemote true
# Só o github.com passa a usar este auxiliar; o valor vazio tira da frente os auxiliares globais
# (o "store" da versão antiga), que continuam valendo para os outros servidores.
CH="credential.https://github.com"
printf -v auxiliar '%q' "$BIN/git-credential-github-multiconta"
if [[ "$(gc --get-all "$CH.helper" || true)" != $'\n'"$auxiliar" ]]; then   # sem a chave, o git sai com 1
  gc --unset-all "$CH.helper" || [[ $? -eq 5 ]]   # 5 = a chave ainda não existia
  gc --add "$CH.helper" ""
  gc --add "$CH.helper" "$auxiliar"
fi
[[ "$(gc --get "$CH.useHttpPath" || true)" == true ]] || gc "$CH.useHttpPath" true

# --- resumo -----------------------------------------------------------------------------------
info ""
info "Contas deste equipamento (tokens $($cifra && echo "cifrados com systemd-creds" || echo "em texto, 0600")):"
for i in "${!logins[@]}"; do printf '  %-10s %-22s donos: %-28s %s\n' "${remotos[i]}" "${logins[i]}" "${donos[i]}" "${estado[i]}"; done
for f in "$CONF/.secrets"/*; do
  [[ -e "$f" ]] || continue
  b="$(basename "$f")"; b="${b%.cred}"; b="${b%.token}"
  [[ " ${logins[*]} " == *" $b "* ]] || aviso "há token guardado de uma conta que saiu do .env: $f"
done
info ""
info "Em cada repositório, só o remoto:"
for i in "${!logins[@]}"; do printf '  git remote add %s https://github.com/%s/NOME-DO-REPOSITORIO.git\n' "${remotos[i]}" "${donos[i]%%,*}"; done
info ""
[[ ":$PATH:" == *":$BIN:"* ]] || aviso "$BIN não está no PATH deste terminal: o gh por conta só vale onde ele estiver na frente"
# -ef: o único gh encontrado é o próprio invólucro quando o gh verdadeiro não está instalado.
gh_real=""; for d in /usr/local/bin /usr/bin /bin /snap/bin /opt/homebrew/bin; do [[ -x "$d/gh" ]] && gh_real="$d/gh"; done
[[ -n "$gh_real" ]] || aviso "o gh não está instalado: o git já funciona; o gh passa a funcionar quando for instalado"
if [[ $faltam -gt 0 ]]; then
  aviso "$faltam conta(s) sem token: grave o token em $SEG_KIT/<login>.token e rode ./instalar.sh de novo"
  exit 1
fi
info "Pronto. Confira com: github-multiconta testar"
