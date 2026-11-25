#!/bin/bash
# pam_ssh_log.sh - Journalise les tentatives SSH (appelé par pam_exec, géré par Ansible)
# Les messages passent par rsyslog, qui les écrit dans /var/log/user_ssh.log
case "${PAM_TYPE:-}:${1:-}" in
  auth:echec)      evenement="ECHEC OTP" ;;
  auth:*)          evenement="TENTATIVE (cle acceptee, OTP demande)" ;;
  account:*)       evenement="CONTROLE DU COMPTE" ;;
  open_session:*)  evenement="OUVERTURE DE SESSION" ;;
  close_session:*) evenement="FERMETURE DE SESSION" ;;
  *)               evenement="${PAM_TYPE:-inconnu}" ;;
esac
logger -t user_ssh -p authpriv.info -- \
  "${evenement} | utilisateur=${PAM_USER:-inconnu} | ip=${PAM_RHOST:-inconnue}"
exit 0
