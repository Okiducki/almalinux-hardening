# Durcissement automatisé d'AlmaLinux 10 avec Ansible

![ansible-lint](https://github.com/Okiducki/almalinux-hardening/actions/workflows/ansible-lint.yml/badge.svg)

Playbook Ansible qui durcit un serveur **AlmaLinux 10** (compatible Red Hat Enterprise Linux 10)
en une seule commande, à partir des recommandations de l'ANSSI.
Un serveur neuf est durci en **2 minutes**, et un second passage ne modifie rien (`changed=0`).

## Résultat

| Mesure | Avant | Après |
| --- | --- | --- |
| Score Lynis (Hardening index) | 69 | 73 |
| Paramètres noyau ANSSI conformes | 15 / 45 | 45 / 45 |
| Connexion SSH de root | autorisée | refusée |
| Authentification SSH | mot de passe | clé + code OTP |
| Élévation de privilèges (sudo) | mot de passe | code OTP |
| Verrouillage après échecs | non | 3 échecs = 15 min |
| Traçabilité | journaux système par défaut | auditd, journal sudo dédié, journal des tentatives SSH |
| Pare-feu | services par défaut ouverts | SSH uniquement |

![Connexion SSH avec clé puis code OTP](docs/img/ssh-otp.png)

## Ce que fait chaque rôle

| Rôle | Contenu |
| --- | --- |
| `kernel_anssi` | 44 paramètres sysctl ANSSI, blocage des modules après le démarrage, contrôle de conformité chaque minute |
| `audit` | auditd : exécutions, chmod, connexions, fichiers de sécurité ; `audit=1` au démarrage |
| `comptes_sudo` | comptes d'administration et de secours, journal sudo, umask 0007, root verrouillé |
| `auth_pam` | profil authselect personnalisé : faillock, politique de mots de passe, restriction horaire |
| `ssh_mfa` | SSH par clé puis OTP, sudo par OTP, journalisation des tentatives |
| `grub` | mot de passe pour modifier le démarrage |
| `socle` | firewalld (SSH seul), SELinux enforcing, mises à jour de sécurité automatiques |

## Comptes

| Compte | Usage | Connexion SSH | sudo |
| --- | --- | --- | --- |
| `ansible` | Automatisation | Clé seule | Sans mot de passe |
| `localadm` | Administration quotidienne | Clé + code OTP | Code OTP |
| `rescue` | Secours, console uniquement | Interdite | Mot de passe |
| `root` | — | Interdite | Mot de passe verrouillé |

## Prérequis

- Un nœud de contrôle avec Ansible et la collection `ansible.posix`
- Une cible AlmaLinux 10 joignable en SSH par clé avec un compte `ansible` disposant de sudo
- Une application OTP sur téléphone (Google Authenticator, Aegis, FreeOTP)

## Utilisation

```bash
git clone https://github.com/Okiducki/almalinux-hardening.git
cd almalinux-hardening
cp group_vars/all/vault.yml.example group_vars/all/vault.yml   # puis remplir les valeurs
ansible-vault encrypt group_vars/all/vault.yml
ansible-playbook durcissement.yml
```

Le premier passage s'arrête volontairement au rôle `ssh_mfa` tant que la clé OTP de l'administrateur n'existe pas.
Pour la générer, connecte-toi en `localadm` et lance :

```bash
google-authenticator -t -d -f -r 3 -R 30 -w 3 -s ~/.ssh/.google_authenticator
```

Relance ensuite le playbook, puis redémarre la cible pour activer `audit=1` et le blocage des modules.

## Choix techniques

- **authselect plutôt que des modifications manuelles de PAM** : sur Red Hat, `/etc/pam.d/system-auth`
  est régénéré par authselect. Le projet crée un profil personnalisé pour que les réglages survivent aux mises à jour.
- **Clé OTP dans `~/.ssh`** : SELinux n'autorise sshd à lire et réécrire que les fichiers de type `ssh_home_t`.
- **Compte d'automatisation sans OTP** : une exception `Match User` permet à Ansible de se connecter par clé seule.
- **Configurations validées avant installation** : `visudo -cf` et `sshd -t` empêchent toute erreur de syntaxe de bloquer l'accès.
- **Garde-fous** : le rôle `ssh_mfa` refuse d'activer le 2FA tant que la clé OTP n'existe pas,
  et le rôle `grub` refuse un hash de mot de passe factice.
- **Secrets chiffrés** : mots de passe et hash GRUB sont stockés dans Ansible Vault ; seul le modèle `vault.yml.example` est publié.

## Spécificités d'AlmaLinux 10

Le projet a été conçu pour EL9, puis adapté à EL10 lors des tests :

- **audit 4.x** : le paquet `audit` a été scindé. `/etc/audit/rules.d/`, `augenrules` et `auditctl` sont désormais
  fournis par `audit-rules`, et les règles sont chargées au démarrage par le service `audit-rules.service`.
- **dnf-automatic** : les options sont placées explicitement dans la section `[commands]` de `automatic.conf`.

## Origine du projet

TP de durcissement Linux réalisés manuellement sur Arch Linux en master cybersécurité,
automatisés et adaptés à l'environnement Red Hat.

## Licence

MIT
