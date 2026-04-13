#!/bin/bash

# =============================================================================
#  setup-git.sh — Configuration Git et Clé SSH (WSL2/Linux + macOS)
# =============================================================================

set -e

# --- Couleurs ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()     { echo -e "${GREEN}[✓]${NC} $1"; }
info()    { echo -e "${BLUE}[→]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; exit 1; }
section() { echo -e "\n${CYAN}${BOLD}━━━ $1 ━━━${NC}\n"; }

# =============================================================================
#  DÉTECTION OS
# =============================================================================
detect_os() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="mac"
  elif [[ -f /etc/os-release ]]; then
    OS="linux"
  else
    error "Système non supporté."
  fi
}

# =============================================================================
#  INSTALLATION GIT (si manquant)
# =============================================================================
install_git() {
  if ! command -v git &>/dev/null; then
    section "Installation de Git"
    if [[ "$OS" == "linux" ]]; then
      sudo apt-get update -qq && sudo apt-get install -y git
    else
      if ! command -v brew &>/dev/null; then
        info "Installation de Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Charger brew dans le shell courant pour macOS Intel/Silicon
        if [[ -f /opt/homebrew/bin/brew ]]; then
          eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -f /usr/local/bin/brew ]]; then
          eval "$(/usr/local/bin/brew shellenv)"
        fi
      fi
      brew install git
    fi
    log "Git installé"
  else
    log "Git est déjà présent ($(git --version))"
  fi
}

# =============================================================================
#  CONFIGURATION GIT
# =============================================================================
configure_git() {
  section "Configuration Git"
  
  # Demander les infos utilisateur si non fournies
  if [[ -z "$GIT_NAME" ]]; then
    read -rp "  Ton nom complet (ex: Jean Dupont) : " GIT_NAME
  fi
  if [[ -z "$GIT_EMAIL" ]]; then
    read -rp "  Ton adresse email Git : " GIT_EMAIL
  fi

  git config --global user.name "$GIT_NAME"
  git config --global user.email "$GIT_EMAIL"
  git config --global init.defaultBranch main
  git config --global pull.rebase false
  git config --global core.autocrlf false
  
  # Essayer de configurer VS Code comme éditeur par défaut, sinon nano
  if command -v code &>/dev/null; then
    git config --global core.editor "code --wait"
  else
    git config --global core.editor "nano"
  fi

  log "Git configuré ($GIT_NAME / $GIT_EMAIL)"
}

# =============================================================================
#  CLÉ SSH (Ed25519)
# =============================================================================
setup_ssh() {
  section "Génération Clé SSH"
  local KEY="$HOME/.ssh/id_ed25519"
  
  if [[ -f "$KEY" ]]; then
    warn "Une clé SSH existe déjà dans $KEY"
    read -rp "  Voulez-vous la remplacer ? (y/N) " choice
    if [[ ! "$choice" =~ ^[Yy]$ ]]; then
      log "Utilisation de la clé existante"
    else
      rm -f "$KEY" "$KEY.pub"
      generate_ssh "$KEY"
    fi
  else
    generate_ssh "$KEY"
  fi

  # Gestion de l'agent SSH : réutiliser l'existant ou en lancer un seul
  if [[ -z "$SSH_AUTH_SOCK" ]]; then
    info "Démarrage d'un nouvel agent SSH..."
    eval "$(ssh-agent -s)"
  else
    info "Utilisation de l'agent SSH existant ($SSH_AUTH_SOCK)"
  fi

  if [[ "$OS" == "mac" ]]; then
    # Spécifique macOS pour sauver dans le keychain
    ssh-add --apple-use-keychain "$KEY"
  else
    ssh-add "$KEY"
  fi
}

generate_ssh() {
  local KEY_PATH="$1"
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f "$KEY_PATH" -N ""
  log "Nouvelle clé SSH générée"
}

# =============================================================================
#  AFFICHAGE RÉSULTAT
# =============================================================================
print_instructions() {
  echo ""
  echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}${BOLD}  ✓ Configuration terminée !${NC}"
  echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo -e "  ${BOLD}Voici ta clé publique SSH :${NC}"
  echo ""
  cat "$HOME/.ssh/id_ed25519.pub"
  echo ""
  echo -e "  ${YELLOW}${BOLD}Copie la clé ci-dessus et ajoute-la ici :${NC}"
  echo "   • GitHub : https://github.com/settings/ssh/new"
  echo "   • GitLab : https://gitlab.com/-/profile/keys"
  echo ""
  echo -e "  ${BLUE}Test de connexion (après ajout) :${NC}"
  echo "   ssh -T git@github.com"
  echo "   ssh -T git@gitlab.com"
  echo ""
}

# =============================================================================
#  MAIN
# =============================================================================
main() {
  detect_os
  install_git
  configure_git
  setup_ssh
  print_instructions
}

main "$@"
