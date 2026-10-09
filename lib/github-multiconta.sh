# Biblioteca do github-multiconta: contas, escolha da conta e leitura do token.
# Carregada pelo auxiliar de credencial do git, pelo invólucro do gh e pelo comando github-multiconta.
# Nenhuma função daqui escreve token em tela, log ou arquivo em disco.

GHM_CONF="${GHM_CONF:-${XDG_CONFIG_HOME:-$HOME/.config}/github-multiconta}"
GHM_REMOTOS=() GHM_LOGINS=() GHM_DONOS=()
GHM_I=0     # índice da conta escolhida
GHM_T=""    # token da conta, só na memória do processo
GHM_GH=""   # caminho do gh verdadeiro

# Dentro do Flatpak não há systemd-creds nem gh: roda o mesmo comando no host.
ghm_no_host() { # ghm_no_host <comando> [argumentos...]
  [[ -e /.flatpak-info ]] || return 0
  command -v flatpak-spawn >/dev/null 2>&1 || return 0
  local v env=()
  for v in "${!GH_@}" GITHUB_TOKEN GIT_DIR GIT_WORK_TREE NO_COLOR CLICOLOR CLICOLOR_FORCE TERM; do
    [[ -n "${!v:-}" ]] && env+=("--env=$v=${!v}")
  done
  exec flatpak-spawn --host --directory="$PWD" "${env[@]}" "$@"
}

# Lê contas.conf: uma conta por linha, "<remoto> <login> <dono>[,<dono>...]". A primeira é a padrão.
ghm_carregar() {
  local remoto login donos
  [[ -r "$GHM_CONF/contas.conf" ]] || return 1
  while read -r remoto login donos; do
    [[ -z "$remoto" || "$remoto" == \#* ]] && continue
    GHM_REMOTOS+=("$remoto"); GHM_LOGINS+=("$login"); GHM_DONOS+=("$donos")
  done < "$GHM_CONF/contas.conf"
  [[ ${#GHM_LOGINS[@]} -gt 0 ]]
}

# Conta que atende um dono (usuário ou organização da URL). Resultado em GHM_I.
ghm_por_dono() { # ghm_por_dono <dono>
  local alvo="${1,,}" i d donos
  [[ -n "$alvo" ]] || return 1
  for i in "${!GHM_LOGINS[@]}"; do
    IFS=, read -ra donos <<< "${GHM_DONOS[i],,}"
    for d in "${donos[@]}"; do
      [[ "$d" == "$alvo" ]] && { GHM_I=$i; return 0; }
    done
  done
  return 1
}

# Conta pelo nome que o usuário deu: dono, login ou nome do remoto. Resultado em GHM_I.
ghm_por_nome() { # ghm_por_nome <dono|login|remoto>
  local alvo="${1,,}" i
  ghm_por_dono "$alvo" && return 0
  for i in "${!GHM_LOGINS[@]}"; do
    [[ "${GHM_LOGINS[i],,}" == "$alvo" || "${GHM_REMOTOS[i],,}" == "$alvo" ]] && { GHM_I=$i; return 0; }
  done
  return 1
}

# Conta pelo dono de um endereço: DONO/REPO, URL do GitHub ou caminho da API (repos/DONO/..., orgs/DONO).
ghm_por_endereco() { # ghm_por_endereco <texto>
  local s="$1"
  [[ "$s" == */* ]] || return 1
  s="${s#*github.com[:/]}"; s="${s#/}"
  case "$s" in repos/*|orgs/*|users/*) s="${s#*/}" ;; esac
  ghm_por_dono "${s%%/*}"
}

# Conta de um pedido ao gh, nesta ordem: GH_CONTA, -R/--repo, GH_REPO, dono em um argumento (com ou sem o repositório),
# remoto origin da pasta atual, conta padrão. Resultado em GHM_I.
ghm_conta_do_pedido() { # ghm_conta_do_pedido <argumentos do gh...>
  local a espera=false url
  if [[ -n "${GH_CONTA:-}" ]]; then
    ghm_por_nome "$GH_CONTA" && return 0
    printf 'github-multiconta: GH_CONTA=%s não é dono, login nem remoto de %s\n' "$GH_CONTA" "$GHM_CONF/contas.conf" >&2
    return 1
  fi
  for a in "$@"; do
    if $espera; then ghm_por_endereco "$a" && return 0; espera=false; continue; fi
    case "$a" in
      -R|--repo) espera=true ;;
      --repo=*) ghm_por_endereco "${a#*=}" && return 0 ;;
    esac
  done
  [[ -n "${GH_REPO:-}" ]] && ghm_por_endereco "$GH_REPO" && return 0
  for a in "$@"; do
    [[ "$a" == -* ]] && continue
    # DONO/REPO, URL ou caminho da API; ou o dono sozinho (gh repo list <dono>).
    ghm_por_endereco "$a" && return 0
    ghm_por_dono "$a" && return 0
  done
  # 2>/dev/null: fora de repositório, ou sem remoto origin, o git reclama e isso é esperado aqui.
  if url="$(git remote get-url origin 2>/dev/null)" && ghm_por_endereco "$url"; then return 0; fi
  GHM_I=0
}

# Token da conta em GHM_T. Cifrado (<login>.cred): decifra uma vez por sessão e guarda a cópia
# em memória (tmpfs de XDG_RUNTIME_DIR, só do usuário). Em texto (<login>.token): lê direto.
ghm_token() { # ghm_token <login>
  local login="$1" dir="$GHM_CONF/.secrets" cache=""
  GHM_T=""
  if [[ -r "$dir/$login.cred" ]]; then
    if [[ -n "${XDG_RUNTIME_DIR:-}" && -d "$XDG_RUNTIME_DIR" ]]; then
      cache="$XDG_RUNTIME_DIR/github-multiconta/$login"
      if [[ -r "$cache" && ! "$dir/$login.cred" -nt "$cache" ]]; then
        GHM_T="$(<"$cache")"
        [[ -n "$GHM_T" ]] && return 0
      fi
    fi
    GHM_T="$(systemd-creds --user --name="github-multiconta-$login" decrypt "$dir/$login.cred" -)" || { GHM_T=""; return 1; }
    if [[ -n "$cache" ]]; then
      # A cópia em memória é opcional: se não der para gravar (pasta só de leitura), segue sem ela.
      ( umask 077; mkdir -p "${cache%/*}" && printf '%s' "$GHM_T" > "$cache.$$" && mv -f "$cache.$$" "$cache" ) 2>/dev/null || true
    fi
  elif [[ -r "$dir/$login.token" ]]; then
    GHM_T="$(<"$dir/$login.token")"
    GHM_T="${GHM_T//[$'\r\n\t ']/}"
  fi
  [[ -n "$GHM_T" ]]
}

# Onde está o token da conta, sem ler o valor: cifrado, texto ou ausente.
ghm_estado_token() { # ghm_estado_token <login>
  if [[ -s "$GHM_CONF/.secrets/$1.cred" ]]; then printf 'cifrado'
  elif [[ -s "$GHM_CONF/.secrets/$1.token" ]]; then printf 'texto'
  else printf 'ausente'; fi
}

# Primeiro gh do PATH que não é o invólucro. Resultado em GHM_GH.
ghm_gh_real() { # ghm_gh_real <caminho do invólucro>
  local d pastas
  IFS=: read -ra pastas <<< "$PATH:/usr/local/bin:/usr/bin"
  for d in "${pastas[@]}"; do
    [[ -n "$d" && -x "$d/gh" && ! -d "$d/gh" && ! "$d/gh" -ef "$1" ]] && { GHM_GH="$d/gh"; return 0; }
  done
  return 1
}
