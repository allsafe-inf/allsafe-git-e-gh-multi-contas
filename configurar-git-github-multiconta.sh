#!/usr/bin/env bash
set -Eeuo pipefail

info(){ printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
ok(){ printf '\033[1;32m[ OK ]\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m[AVISO]\033[0m %s\n' "$*"; }
err(){ printf '\033[1;31m[ERRO]\033[0m %s\n' "$*" >&2; }

cleanup(){ unset TOKEN_PESSOAL TOKEN_EMPRESA 2>/dev/null || true; }
trap cleanup EXIT

command -v git >/dev/null 2>&1 || { err "Git não está instalado."; exit 1; }

echo
echo "===================================================================="
echo " GitHub HTTPS Multi-conta - Pessoal + Empresa"
echo "===================================================================="
echo
warn "A pasta organizadora (ex.: ~/Músicas/Docker build) NÃO deve ter .git/"
warn "Cada subpasta/projeto deve ser um repositório Git independente."
warn "Os PATs serão salvos em ~/.git-credentials via credential.helper=store."
echo

read -r -p "Continuar? [s/N]: " CONFIRM
case "${CONFIRM,,}" in s|sim|y|yes) ;; *) info "Cancelado."; exit 0 ;; esac

CURRENT_NAME="$(git config --global --get user.name 2>/dev/null || true)"
CURRENT_EMAIL="$(git config --global --get user.email 2>/dev/null || true)"

echo
echo "--- Identidade dos commits ---"
if [[ -n "$CURRENT_NAME" ]]; then
  read -r -p "Nome para commits [$CURRENT_NAME]: " GIT_NAME
  GIT_NAME="${GIT_NAME:-$CURRENT_NAME}"
else
  read -r -p "Nome para commits: " GIT_NAME
fi

if [[ -n "$CURRENT_EMAIL" ]]; then
  read -r -p "E-mail para commits [$CURRENT_EMAIL]: " GIT_EMAIL
  GIT_EMAIL="${GIT_EMAIL:-$CURRENT_EMAIL}"
else
  read -r -p "E-mail para commits: " GIT_EMAIL
fi

echo
echo "--- GitHub pessoal ---"
read -r -p "Login GitHub pessoal [CarlosSuporteISP]: " PESSOAL_LOGIN
PESSOAL_LOGIN="${PESSOAL_LOGIN:-CarlosSuporteISP}"
read -r -p "Owner/namespace pessoal [$PESSOAL_LOGIN]: " PESSOAL_OWNER
PESSOAL_OWNER="${PESSOAL_OWNER:-$PESSOAL_LOGIN}"

echo
echo "--- GitHub empresa ---"
read -r -p "Login GitHub que possui o PAT da empresa [allsafe-inf]: " EMPRESA_LOGIN
EMPRESA_LOGIN="${EMPRESA_LOGIN:-allsafe-inf}"
read -r -p "Owner/organização dos repositórios da empresa [allsafe-inf]: " EMPRESA_OWNER
EMPRESA_OWNER="${EMPRESA_OWNER:-allsafe-inf}"

[[ -n "${GIT_NAME// }" ]] || { err "Nome para commits vazio."; exit 1; }
[[ -n "${GIT_EMAIL// }" ]] || { err "E-mail para commits vazio."; exit 1; }
[[ -n "${PESSOAL_LOGIN// }" ]] || { err "Login pessoal vazio."; exit 1; }
[[ -n "${PESSOAL_OWNER// }" ]] || { err "Owner pessoal vazio."; exit 1; }
[[ -n "${EMPRESA_LOGIN// }" ]] || { err "Login empresa vazio."; exit 1; }
[[ -n "${EMPRESA_OWNER// }" ]] || { err "Owner empresa vazio."; exit 1; }

echo
info "Configurando Git global..."

git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"
git config --global init.defaultBranch main
git config --global push.autoSetupRemote true
git config --global --unset-all credential.helper 2>/dev/null || true
git config --global credential.helper store
git config --global credential.useHttpPath false
git config --global --unset-all credential.username 2>/dev/null || true

echo
echo "--- Token GitHub pessoal ---"
echo "Cole o PAT da conta $PESSOAL_LOGIN. Ele não será exibido."
read -r -s -p "Token pessoal: " TOKEN_PESSOAL
echo
[[ -n "$TOKEN_PESSOAL" ]] || { err "Token pessoal vazio."; exit 1; }
printf 'protocol=https\nhost=github.com\nusername=%s\npassword=%s\n\n'   "$PESSOAL_LOGIN" "$TOKEN_PESSOAL" | git credential approve
unset TOKEN_PESSOAL
ok "Credencial pessoal cadastrada."

echo
echo "--- Token GitHub empresa ---"
echo "Cole o PAT da conta $EMPRESA_LOGIN. Ele não será exibido."
read -r -s -p "Token empresa: " TOKEN_EMPRESA
echo
[[ -n "$TOKEN_EMPRESA" ]] || { err "Token empresa vazio."; exit 1; }
printf 'protocol=https\nhost=github.com\nusername=%s\npassword=%s\n\n'   "$EMPRESA_LOGIN" "$TOKEN_EMPRESA" | git credential approve
unset TOKEN_EMPRESA
ok "Credencial da empresa cadastrada."

[[ -f "$HOME/.git-credentials" ]] && chmod 600 "$HOME/.git-credentials"

info "Configurando seleção automática da conta por owner/namespace..."

git config --global --unset-all "url.https://${PESSOAL_LOGIN}@github.com/${PESSOAL_OWNER}/.insteadOf" 2>/dev/null || true
git config --global --unset-all "url.https://${EMPRESA_LOGIN}@github.com/${EMPRESA_OWNER}/.insteadOf" 2>/dev/null || true

git config --global   "url.https://${PESSOAL_LOGIN}@github.com/${PESSOAL_OWNER}/.insteadOf"   "https://github.com/${PESSOAL_OWNER}/"

git config --global   "url.https://${EMPRESA_LOGIN}@github.com/${EMPRESA_OWNER}/.insteadOf"   "https://github.com/${EMPRESA_OWNER}/"

echo
echo "===================================================================="
echo " CONFIGURAÇÃO CONCLUÍDA"
echo "===================================================================="
echo
echo "Em cada projeto, configure apenas os remotes necessários:"
echo
echo "  git remote add origin  https://github.com/${PESSOAL_OWNER}/NOME-DO-REPO.git"
echo "  git remote add empresa https://github.com/${EMPRESA_OWNER}/NOME-DO-REPO.git"
echo
echo "Depois:"
echo
echo '  git add .'
echo '  git commit -m "Atualização"'
echo '  git push origin main'
echo '  git push empresa main'
echo
echo "Os pushes são separados e cada remoto usa automaticamente seu PAT."
echo
echo "IMPORTANTE:"
echo "  - Não execute git init em ~/Músicas/Docker build se ela for só organizadora."
echo "  - Não use cat ~/.git-credentials: isso exibe os tokens."
echo "  - Se o owner da empresa for uma organização, EMPRESA_LOGIN deve ser"
echo "    a conta que possui o PAT e permissão de escrita nela."
