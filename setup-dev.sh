#!/bin/bash

# =============================================================================
#  setup-dev.sh — Environnement de dev complet (WSL2/Linux + macOS)
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
#  FONCTION DE CONFIRMATION
# =============================================================================
confirm() {
  local prompt="$1"
  local default="${2:-y}"
  local reply

  if [[ "$default" == "y" ]]; then
    prompt="$prompt [Y/n] "
  else
    prompt="$prompt [y/N] "
  fi

  read -rp "  $prompt" reply
  [[ -z "$reply" ]] && reply="$default"

  if [[ "$reply" =~ ^[Yy]$ ]]; then
    return 0
  else
    return 1
  fi
}

# =============================================================================
#  DÉTECTION OS
# =============================================================================
detect_os() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="mac"
    info "Système détecté : macOS"
  elif [[ -f /etc/os-release ]]; then
    source /etc/os-release
    OS="linux"
    DISTRO=$ID
    info "Système détecté : Linux ($DISTRO)"
  else
    error "Système non supporté."
  fi
}

# =============================================================================
#  VÉRIFICATION : ne pas tourner en root
# =============================================================================
check_not_root() {
  if [[ "$EUID" -eq 0 ]]; then
    error "Ne lance pas ce script en root. Utilise ton utilisateur normal (sudo sera appelé si besoin)."
  fi
}

# =============================================================================
#  macOS — Homebrew
# =============================================================================
install_homebrew() {
  if ! command -v brew &>/dev/null; then
    info "Installation de Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null
    log "Homebrew installé"
  else
    log "Homebrew déjà présent"
    brew update
  fi
}

# =============================================================================
#  Linux — Dépendances de base
# =============================================================================
install_base_linux() {
  section "Dépendances système"
  sudo apt-get update -qq
  sudo apt-get install -y \
    curl wget git unzip zip \
    build-essential ca-certificates gnupg \
    lsb-release software-properties-common \
    apt-transport-https \
    jq make htop zsh fzf \
    xdg-utils
  log "Dépendances de base installées"
}

# =============================================================================
#  macOS — Dépendances de base
# =============================================================================
install_base_mac() {
  section "Dépendances système"
  brew install curl wget git jq make htop fzf zsh
  log "Dépendances de base installées"
}

# =============================================================================
#  ZSH + OH MY ZSH
# =============================================================================
install_zsh() {
  section "Zsh + Oh My Zsh"

  # Oh My Zsh
  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    info "Installation de Oh My Zsh..."
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    log "Oh My Zsh installé"
  else
    log "Oh My Zsh déjà présent"
  fi

  # Plugin : zsh-autosuggestions
  local ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
      "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    log "Plugin zsh-autosuggestions installé"
  fi

  # Plugin : zsh-syntax-highlighting
  if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
      "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
    log "Plugin zsh-syntax-highlighting installé"
  fi

  # Thème : Powerlevel10k
  if [[ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k \
      "$ZSH_CUSTOM/themes/powerlevel10k"
    log "Thème Powerlevel10k installé"
  fi

  # Mise à jour du .zshrc
  info "Configuration du .zshrc..."
  cat > "$HOME/.zshrc" << 'EOF'
# Powerlevel10k instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  docker
  kubectl
  terraform
  helm
  fzf
  history
  sudo
)

source $ZSH/oh-my-zsh.sh

# --- NVM ---
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"

# --- Pyenv ---
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)" 2>/dev/null || true

# --- FZF ---
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# --- Aliases utiles ---
alias k="kubectl"
alias tf="terraform"
alias d="docker"
alias dc="docker compose"
if command -v lazydocker >/dev/null 2>&1; then
  alias lzd="lazydocker"
fi
if command -v eza >/dev/null 2>&1; then
  alias ls="eza --icons --group-directories-first"
  alias ll="eza -lah --icons --group-directories-first"
else
  alias ll="ls -lah"
fi
alias gs="git status"
alias gp="git push"
alias gl="git pull"
alias gc="git commit -m"

# --- Powerlevel10k config ---
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
EOF

  # Changer le shell par défaut
  if [[ "$SHELL" != "$(which zsh)" ]]; then
    info "Changement du shell par défaut vers zsh..."
    if [[ "$OS" == "linux" ]]; then
      sudo chsh -s "$(which zsh)" "$USER"
    else
      chsh -s "$(which zsh)"
    fi
    log "Shell par défaut → zsh"
  fi
}

# =============================================================================
#  DOCKER
# =============================================================================
install_docker() {
  section "Docker"
  if command -v docker &>/dev/null; then
    log "Docker déjà installé ($(docker --version))"
    return
  fi

  if [[ "$OS" == "linux" ]]; then
    info "Installation de Docker..."
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker "$USER"
    log "Docker installé — déconnecte/reconnecte-toi pour utiliser Docker sans sudo"
  else
    warn "Sur macOS, installe Docker Desktop manuellement : https://www.docker.com/products/docker-desktop/"
  fi
}

# =============================================================================
#  KUBECTL
# =============================================================================
install_kubectl() {
  section "kubectl"
  if command -v kubectl &>/dev/null; then
    log "kubectl déjà installé ($(kubectl version --client --short 2>/dev/null || kubectl version --client))"
    return
  fi

  if [[ "$OS" == "linux" ]]; then
    local VERSION
    VERSION=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
    curl -fsSL "https://dl.k8s.io/release/$VERSION/bin/linux/amd64/kubectl" -o /tmp/kubectl
    sudo install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl
    rm /tmp/kubectl
  else
    brew install kubectl
  fi
  log "kubectl installé ($(kubectl version --client --short 2>/dev/null || echo 'ok'))"
}

# =============================================================================
#  K9S
# =============================================================================
install_k9s() {
  section "k9s"
  if command -v k9s &>/dev/null; then
    log "k9s déjà installé"
    return
  fi

  if [[ "$OS" == "linux" ]]; then
    local VERSION
    VERSION=$(curl -fsSL https://api.github.com/repos/derailed/k9s/releases/latest | jq -r .tag_name)
    curl -fsSL "https://github.com/derailed/k9s/releases/download/$VERSION/k9s_Linux_amd64.tar.gz" | \
      sudo tar -xz -C /usr/local/bin k9s
  else
    brew install k9s
  fi
  log "k9s installé"
}

# =============================================================================
#  K3S
# =============================================================================
install_k3s() {
  section "k3s (Kubernetes léger)"
  if command -v k3s &>/dev/null; then
    log "k3s déjà installé ($(k3s --version | head -1))"
    return
  fi

  if [[ "$OS" == "linux" ]]; then
    info "Installation de k3s..."
    curl -sfL https://get.k3s.io | sh -
    # Donner accès au kubeconfig sans sudo
    sudo chmod 644 /etc/rancher/k3s/k3s.yaml
    mkdir -p "$HOME/.kube"
    sudo cp /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"
    sudo chown "$USER:$USER" "$HOME/.kube/config"
    log "k3s installé — cluster local prêt"
  else
    warn "Sur macOS, k3s n'est pas supporté nativement. Utilise Rancher Desktop à la place : https://rancherdesktop.io"
  fi
}

# =============================================================================
#  HELM
# =============================================================================
install_helm() {
  section "Helm"
  if command -v helm &>/dev/null; then
    log "Helm déjà installé ($(helm version --short))"
    return
  fi

  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  log "Helm installé ($(helm version --short))"
}

# =============================================================================
#  TERRAFORM
# =============================================================================
install_terraform() {
  section "Terraform"
  if command -v terraform &>/dev/null; then
    log "Terraform déjà installé ($(terraform version -json | jq -r .terraform_version))"
    return
  fi

  if [[ "$OS" == "linux" ]]; then
    curl -fsSL https://apt.releases.hashicorp.com/gpg | \
      sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
      https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
      sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt-get update -qq && sudo apt-get install -y terraform
  else
    brew tap hashicorp/tap
    brew install hashicorp/tap/terraform
  fi
  log "Terraform installé"
}

# =============================================================================
#  NVM + NODE
# =============================================================================
install_nvm() {
  section "NVM + Node.js"
  if [[ -d "$HOME/.nvm" ]]; then
    log "NVM déjà installé"
  else
    info "Installation de NVM..."
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    log "NVM installé"
  fi

  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"

  info "Installation de Node.js LTS..."
  nvm install --lts
  nvm use --lts
  nvm alias default node

  info "Installation des outils Node globaux..."
  npm install -g typescript ts-node prettier eslint nodemon
  log "Node.js $(node --version) + TypeScript installés"
}

# =============================================================================
#  PYENV + PYTHON
# =============================================================================
install_pyenv() {
  section "Pyenv + Python"

  if [[ "$OS" == "linux" ]]; then
    # Dépendances pyenv
    sudo apt-get install -y \
      libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
      libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev
  fi

  if [[ ! -d "$HOME/.pyenv" ]]; then
    info "Installation de Pyenv..."
    curl -fsSL https://pyenv.run | bash
    log "Pyenv installé"
  else
    log "Pyenv déjà installé"
  fi

  export PYENV_ROOT="$HOME/.pyenv"
  export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init -)"

  info "Installation de Python 3.12 (stable)..."
  pyenv install -s 3.12
  pyenv global 3.12

  info "Installation de pipx..."
  pip install --upgrade pip pipx
  pipx ensurepath

  info "Installation des outils Python globaux via pipx..."
  pipx install poetry       # gestion de dépendances
  pipx install black        # formatter
  pipx install ruff         # linter ultra-rapide
  pipx install httpie       # curl amélioré
  pipx install pre-commit   # hooks git

  log "Python $(python --version) + outils installés"
}

# =============================================================================
#  ANSIBLE
# =============================================================================
install_ansible() {
  section "Ansible"
  if command -v ansible &>/dev/null; then
    log "Ansible déjà installé ($(ansible --version | head -1))"
    return
  fi

  if [[ "$OS" == "linux" ]]; then
    info "Installation d'Ansible via pipx..."
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)" 2>/dev/null || true
    pipx install ansible --include-deps
  else
    brew install ansible
  fi
  log "Ansible installé ($(ansible --version | head -1))"
}

# =============================================================================
#  AWS CLI
# =============================================================================
install_aws_cli() {
  section "AWS CLI"
  if command -v aws &>/dev/null; then
    log "AWS CLI déjà installé ($(aws --version | head -n1))"
    return
  fi

  info "Installation de AWS CLI..."
  if [[ "$OS" == "linux" ]]; then
    local arch aws_arch aws_url
    arch="$(uname -m)"

    case "$arch" in
      x86_64|amd64)
        aws_arch="x86_64"
        ;;
      aarch64|arm64)
        aws_arch="aarch64"
        ;;
      *)
        error "Architecture Linux non supportée pour l'installation automatique d'AWS CLI: $arch"
        ;;
    esac

    aws_url="https://awscli.amazonaws.com/awscli-exe-linux-${aws_arch}.zip"
    info "Téléchargement de AWS CLI pour l'architecture ${aws_arch}..."
    curl -fsSL "$aws_url" -o "/tmp/awscliv2.zip"
    
    # Vérifier que le fichier est bien un zip avant d'unziper
    if ! file /tmp/awscliv2.zip | grep -q 'Zip archive data'; then
      error "Le téléchargement de AWS CLI a échoué ou le fichier est corrompu."
    fi

    unzip -q /tmp/awscliv2.zip -d /tmp
    sudo /tmp/aws/install
    rm -rf /tmp/aws /tmp/awscliv2.zip
  else
    brew install awscli
  fi
  log "AWS CLI installé"
}

# =============================================================================
#  GCLOUD SDK
# =============================================================================
install_gcloud() {
  section "Google Cloud SDK (gcloud)"
  if command -v gcloud &>/dev/null; then
    log "gcloud déjà installé"
    return
  fi

  if [[ "$OS" == "linux" ]]; then
    info "Installation de Google Cloud CLI..."
    # Ajout du repo officiel Google Cloud
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | \
      sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
      sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
    sudo apt-get update -qq && sudo apt-get install -y google-cloud-cli
  else
    brew install --cask google-cloud-sdk
  fi
  log "gcloud installé"
}

# =============================================================================
#  EZA (ls moderne)
# =============================================================================
install_eza() {
  section "eza (ls moderne)"
  if command -v eza &>/dev/null; then
    log "eza déjà installé"
    return
  fi

  info "Installation de eza..."
  if [[ "$OS" == "linux" ]]; then
    sudo mkdir -p /etc/apt/keyrings
    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | \
      sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] https://deb.gierens.de stable main" | \
      sudo tee /etc/apt/sources.list.d/gierens.list
    sudo apt-get update -qq && sudo apt-get install -y eza
  else
    brew install eza
  fi
  log "eza installé"
}

# =============================================================================
#  LAZYDOCKER (TUI pour Docker)
# =============================================================================
install_lazydocker() {
  section "lazydocker"
  if command -v lazydocker &>/dev/null; then
    log "lazydocker déjà installé"
    return
  fi

  info "Installation de lazydocker..."
  if [[ "$OS" == "linux" ]]; then
    curl -fsSL https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
  else
    brew install jesseduffield/lazydocker/lazydocker
  fi
  log "lazydocker installé"
}

# =============================================================================
#  GH CLI (GitHub)
# =============================================================================
install_gh() {
  section "GitHub CLI (gh)"
  if command -v gh &>/dev/null; then
    log "gh déjà installé ($(gh --version | head -1))"
    return
  fi

  if [[ "$OS" == "linux" ]]; then
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
      sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
      https://cli.github.com/packages stable main" | \
      sudo tee /etc/apt/sources.list.d/github-cli.list
    sudo apt-get update -qq && sudo apt-get install -y gh
  else
    brew install gh
  fi
  log "gh installé"
}

# =============================================================================
#  RÉSUMÉ FINAL
# =============================================================================
print_summary() {
  echo ""
  echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}${BOLD}  ✓ Terminé !${NC}"
  echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo -e "  ${BOLD}État de l'installation :${NC}"
  
  [[ $(command -v zsh) ]]         && echo -e "  - ${GREEN}✓${NC} Zsh"
  [[ -d "$HOME/.oh-my-zsh" ]]    && echo -e "  - ${GREEN}✓${NC} Oh My Zsh + P10k"
  [[ $(command -v docker) ]]      && echo -e "  - ${GREEN}✓${NC} Docker"
  [[ $(command -v kubectl) ]]     && echo -e "  - ${GREEN}✓${NC} Kubernetes (kubectl/k9s/Helm)"
  [[ $(command -v terraform) ]]   && echo -e "  - ${GREEN}✓${NC} Terraform"
  [[ $(command -v nvm) ]]         && echo -e "  - ${GREEN}✓${NC} NVM / Node.js"
  [[ $(command -v pyenv) ]]       && echo -e "  - ${GREEN}✓${NC} Pyenv / Python"
  [[ $(command -v ansible) ]]     && echo -e "  - ${GREEN}✓${NC} Ansible"
  [[ $(command -v aws) ]]         && echo -e "  - ${GREEN}✓${NC} AWS CLI"
  [[ $(command -v gcloud) ]]      && echo -e "  - ${GREEN}✓${NC} Google Cloud SDK"
  [[ $(command -v gh) ]]          && echo -e "  - ${GREEN}✓${NC} GitHub CLI"
  [[ $(command -v eza) ]]         && echo -e "  - ${GREEN}✓${NC} eza"
  [[ $(command -v lazydocker) ]]  && echo -e "  - ${GREEN}✓${NC} lazydocker"

  echo ""
  echo -e "  ${YELLOW}${BOLD}Actions manuelles restantes :${NC}"
  echo "   1. Si besoin, lance : ./setup-git.sh pour configurer Git et générer une clé SSH"
  echo "   2. Lance : gh auth login"
  echo "   3. Relance ton terminal (ou : exec zsh)"
  echo "   4. Configure Powerlevel10k : p10k configure"
  if [[ "$OS" == "linux" ]]; then
    echo "   5. Déconnecte/reconnecte-toi pour utiliser Docker sans sudo"
  fi
  echo ""
}

# =============================================================================
#  MAIN
# =============================================================================
main() {
  echo -e "${CYAN}${BOLD}"
  echo "  ╔══════════════════════════════════════╗"
  echo "  ║     Setup Dev Env                    ║"
  echo "  ║     WSL2 / Linux / macOS             ║"
  echo "  ╚══════════════════════════════════════╝"
  echo -e "${NC}"

  check_not_root
  detect_os

  # On suppose Git déjà configuré ou géré séparément
  # Si besoin, l'utilisateur peut lancer ./setup-git.sh avant

  if [[ "$OS" == "linux" ]]; then
    install_base_linux
  else
    install_homebrew
    install_base_mac
  fi

  confirm "Installer Zsh + Oh My Zsh ?"           && install_zsh
  confirm "Installer Docker ?"                   && install_docker
  confirm "Installer kubectl ?"                  && install_kubectl
  confirm "Installer k9s ?"                      && install_k9s
  confirm "Installer k3s (Kubernetes local) ?"   && install_k3s
  confirm "Installer Helm ?"                     && install_helm
  confirm "Installer Terraform ?"                && install_terraform
  confirm "Installer NVM + Node.js ?"            && install_nvm
  confirm "Installer AWS CLI ?"                  && install_aws_cli
  confirm "Installer Google Cloud SDK ?"         && install_gcloud
  confirm "Installer Pyenv + Python ?"           && install_pyenv
  confirm "Installer Ansible ?"                  && install_ansible
  confirm "Installer GitHub CLI (gh) ?"          && install_gh
  confirm "Installer eza ? (ls moderne avec icônes)" && install_eza
  confirm "Installer lazydocker ? (interface TUI pour Docker)" && install_lazydocker
  
  print_summary
}

main "$@"