#!/bin/bash
# kernel_check.sh - Conformité ANSSI des paramètres noyau (géré par Ansible)
# kernel_check.sh : rapport détaillé à l'écran
# kernel_check.sh -q : silencieux (utilisé par le timer)
# Toute modification est journalisée dans /var/log/kernel_modif.log
REF="/etc/sysctl.d/99-anssi.conf"
LOG="/var/log/kernel_modif.log"
STATE="/var/lib/kernel_check/last_values"
QUIET=0; [[ ${1:-} == "-q" ]] && QUIET=1

if [[ $EUID -ne 0 ]]; then echo "A lancer en root (sudo)." >&2; exit 1; fi
mkdir -p "${STATE%/*}"
[[ -f $LOG ]] || install -m 600 /dev/null "$LOG"
log() { echo "$(date '+%F %T') $*" >> "$LOG"; }

declare -A LAST
FIRST=1
if [[ -f $STATE ]]; then
  FIRST=0
while IFS='=' read -r k v; do LAST[$k]=$v; done < "$STATE"
fi
TMP=$(mktemp)
OK=0; KO=0

check() {
  local key=$1 expected=$2 current status etat
  current=$(sysctl -n "$key" 2>/dev/null | xargs)
  [[ -z $current ]] && current="ABSENT"
  if [[ $current == "$expected" ]]; then status="OK"; OK=$((OK+1))
  else status="KO"; KO=$((KO+1)); fi
  (( QUIET )) || printf '[%s] %-45s attendu=%-12s actuel=%s\n' "$status"
  "$key" "$expected" "$current"
  if [[ -n ${LAST[$key]+x} ]]; then
    if [[ ${LAST[$key]} != "$current" ]]; then
      if [[ $status == OK ]]; then etat="conforme"; else etat="NON CONFORME"; fi
      log "MODIFICATION $key : ${LAST[$key]} -> $current ($etat)"
    fi
  elif [[ $status == KO ]]; then
    log "NON CONFORME $key : attendu=$expected actuel=$current"
  fi
  echo "$key=$current" >> "$TMP"
}

while read -r line; do
  [[ $line =~ ^[[:space:]]*(#|$) ]] && continue
  key=$(xargs <<< "${line%%=*}")
  value=$(xargs <<< "${line#*=}")
  check "$key" "$value"
done < "$REF"

# Le blocage des modules n'est vérifié que s'il est activé
if systemctl is-enabled -q modules-lock.timer 2>/dev/null; then
  check kernel.modules_disabled 1
fi

mv "$TMP" "$STATE"; chmod 600 "$STATE"
(( FIRST )) && log "INITIALISATION : $OK paramètres conformes, $KO non conformes"
(( QUIET )) || echo "Bilan : $OK conformes, $KO non conformes (journal : $LOG)"
[[ $KO -eq 0 ]]
