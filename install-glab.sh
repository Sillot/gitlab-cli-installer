#!/bin/bash

# Script pour installer/mettre à jour GitLab CLI (glab) depuis les sources
# Usage: ./install-glab.sh [version]
# Si aucune version n'est spécifiée, utilise la dernière version disponible
#
# Dépendances requises (installées automatiquement si manquantes) :
# - wget ou curl : téléchargement des fichiers
# - dpkg : installation des packages .deb
# - jq : analyse des réponses JSON de l'API GitLab
# - git : pour les fonctionnalités Git de glab
# - ssh : pour l'authentification SSH avec GitLab
# - gpg : pour la vérification des signatures (recommandé)

set -e  # Arrêter en cas d'erreur

# Variables globales
TEMP_DIR=""

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction d'affichage avec couleurs
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérifier les dépendances
check_dependencies() {
    local deps=("wget" "dpkg" "jq" "curl" "git" "ssh" "gpg")
    local missing_deps=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_warning "Dépendances manquantes détectées: ${missing_deps[*]}"
        install_dependencies "${missing_deps[@]}"
    fi
}

# Installer les dépendances manquantes
install_dependencies() {
    local deps=("$@")
    print_info "Installation des dépendances manquantes..."

    # Mapper les dépendances aux noms de packages Ubuntu/Debian
    local packages=()
    for dep in "${deps[@]}"; do
        case "$dep" in
            "wget") packages+=("wget") ;;
            "dpkg") packages+=("dpkg") ;;
            "jq") packages+=("jq") ;;
            "curl") packages+=("curl") ;;
            "git") packages+=("git") ;;
            "ssh") packages+=("openssh-client") ;;
            "gpg") packages+=("gnupg2") ;;
            *) packages+=("$dep") ;;
        esac
    done

    # Vérifier si on peut utiliser sudo
    if ! sudo -n true 2>/dev/null; then
        print_info "Privilèges administrateur requis pour installer les dépendances"
    fi

    # Mettre à jour la liste des packages
    print_info "Mise à jour de la liste des packages..."
    if ! sudo apt-get update; then
        print_error "Impossible de mettre à jour la liste des packages"
        exit 1
    fi

    # Installer les dépendances
    print_info "Installation des packages: ${packages[*]}"
    if sudo apt-get install -y "${packages[@]}"; then
        print_success "Dépendances installées avec succès"
    else
        print_error "Échec de l'installation des dépendances"
        print_info "Veuillez installer manuellement: sudo apt-get install ${packages[*]}"
        exit 1
    fi

    # Vérifier que toutes les dépendances sont maintenant disponibles
    local still_missing=()
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            still_missing+=("$dep")
        fi
    done

    if [ ${#still_missing[@]} -ne 0 ]; then
        print_error "Certaines dépendances sont toujours manquantes: ${still_missing[*]}"
        exit 1
    fi
}

# Obtenir la dernière version depuis l'API GitLab
get_latest_version() {
    local api_url="https://gitlab.com/api/v4/projects/gitlab-org%2Fcli/releases"
    
    # Utiliser curl avec jq pour une analyse JSON plus robuste
    local version
    if command -v jq &> /dev/null; then
        version=$(curl -s "$api_url" | jq -r '.[0].tag_name' | sed 's/^v//')
    else
        # Fallback vers la méthode précédente si jq n'est pas disponible
        version=$(wget -qO- "$api_url" | grep -oP '"tag_name":"v\K[^"]*' | head -n1)
    fi

    if [ -z "$version" ] || [ "$version" = "null" ]; then
        print_error "Impossible de récupérer la dernière version"
        print_info "Vérifiez votre connexion internet et réessayez"
        exit 1
    fi

    echo "$version"
}

# Valider le format de version
validate_version_format() {
    local version=$1

    # Vérifier que la version respecte le format X.Y.Z (ex: 1.61.0)
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_error "Format de version invalide: '$version'"
        print_info "Le format attendu est X.Y.Z (ex: 1.61.0, 1.62.1)"
        print_info "Exemples de versions valides:"
        print_info "  - 1.61.0"
        print_info "  - 1.62.1"
        print_info "  - 2.0.0"
        return 1
    fi

    return 0
}

# Vérifier si glab est déjà installé et sa version
check_current_version() {
    if command -v glab &> /dev/null; then
        local current_version=$(glab version 2>/dev/null | grep -oP 'version \K[0-9.]+' || echo "unknown")
        echo "$current_version"
    else
        echo "not_installed"
    fi
}

# Nettoyer les fichiers temporaires
cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        print_info "Nettoyage du dossier temporaire..."
        rm -rf "$TEMP_DIR"
    fi
}

# Installer glab
install_glab() {
    local version=$1
    TEMP_DIR=$(mktemp -d)
    local current_dir=$(pwd)

    # S'assurer que le dossier temporaire sera nettoyé
    trap 'cleanup; exit 1' INT TERM EXIT

    cd "$TEMP_DIR"

    # URLs des fichiers
    local base_url="https://gitlab.com/gitlab-org/cli/-/releases/v${version}/downloads"
    local deb_file="glab_${version}_linux_amd64.deb"

    print_info "Téléchargement de glab v${version}..."

    # Télécharger le fichier .deb directement
    if wget --progress=bar:force:noscroll "${base_url}/${deb_file}" 2>&1; then
        print_success "Téléchargement terminé"
    else
        print_error "Échec du téléchargement"
        cd "$current_dir"
        cleanup
        exit 1
    fi

    # Installer le package
    print_info "Installation de glab..."
    if sudo dpkg -i "$deb_file" 2>/dev/null; then
        print_success "glab v${version} installé avec succès"
    else
        print_warning "Échec de l'installation avec dpkg, résolution des dépendances..."
        sudo apt-get update
        sudo apt-get install -f -y
        if sudo dpkg -i "$deb_file"; then
            print_success "glab v${version} installé avec succès"
        else
            print_error "Échec de l'installation"
            cd "$current_dir"
            cleanup
            exit 1
        fi
    fi

    # Retourner au répertoire original et nettoyer
    cd "$current_dir"
    trap - INT TERM EXIT  # Désactiver le trap
    cleanup
}

# Vérifier que glab fonctionne correctement
verify_glab_installation() {
    print_info "Vérification du bon fonctionnement de glab..."
    
    # Test basique de la commande version
    if ! glab version &>/dev/null; then
        print_warning "Problème potentiel : impossible d'exécuter 'glab version'"
        return 1
    fi
    
    # Test de l'aide
    if ! glab --help &>/dev/null; then
        print_warning "Problème potentiel : impossible d'afficher l'aide de glab"
        return 1
    fi
    
    # Vérifier que les dépendances importantes sont disponibles pour glab
    local glab_deps=("git" "ssh")
    local missing_glab_deps=()
    
    for dep in "${glab_deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_glab_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_glab_deps[@]} -ne 0 ]; then
        print_warning "Dépendances manquantes pour le fonctionnement optimal de glab: ${missing_glab_deps[*]}"
        print_info "Certaines fonctionnalités peuvent ne pas fonctionner correctement"
        return 1
    fi
    
    print_success "glab semble fonctionner correctement"
    return 0
}

# Fonction principale
main() {
    local target_version=""

    print_info "Script d'installation/mise à jour de GitLab CLI (glab)"
    echo

    # Vérifier les dépendances
    check_dependencies

    # Déterminer la version à installer
    if [ $# -eq 0 ]; then
        print_info "Récupération de la dernière version..."
        target_version=$(get_latest_version)
        print_info "Dernière version disponible: v${target_version}"
    else
        target_version=$1
        print_info "Version demandée: v${target_version}"

        # Valider le format de la version fournie par l'utilisateur
        if ! validate_version_format "$target_version"; then
            exit 1
        fi
    fi

    # Vérifier la version actuellement installée
    local current_version=$(check_current_version)

    if [ "$current_version" = "not_installed" ]; then
        print_info "glab n'est pas installé, installation en cours..."
    elif [ "$current_version" = "$target_version" ]; then
        print_success "glab v${target_version} est déjà installé"
        exit 0
    else
        print_info "Version actuelle: v${current_version}"
        print_info "Mise à jour vers v${target_version}..."
    fi

    # Installer/mettre à jour
    install_glab "$target_version"

    # Vérifier l'installation
    if command -v glab &> /dev/null; then
        local installed_version=$(glab version 2>/dev/null | grep -oP 'version \K[0-9.]+' || echo "unknown")
        print_success "Installation vérifiée: glab v${installed_version}"
        
        # Vérification du bon fonctionnement
        verify_glab_installation
        
        echo
        print_info "Vous pouvez maintenant utiliser 'glab' dans votre terminal"
        print_info "Commencez par: 'glab auth login' pour vous authentifier"
    else
        print_error "Problème avec l'installation, glab n'est pas disponible"
        exit 1
    fi
}

# Gestion des signaux pour nettoyer en cas d'interruption
trap cleanup EXIT INT TERM

# Affichage de l'aide
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Script d'installation/mise à jour de GitLab CLI (glab)"
    echo
    echo "Usage: $0 [version]"
    echo "  version    Version spécifique à installer au format X.Y.Z (ex: 1.61.0)"
    echo "             Si non spécifiée, installe la dernière version"
    echo
    echo "Dépendances (installées automatiquement si manquantes):"
    echo "  - wget/curl    : téléchargement des fichiers"
    echo "  - dpkg         : installation des packages .deb"
    echo "  - jq           : analyse des réponses JSON de l'API GitLab"
    echo "  - git          : pour les fonctionnalités Git de glab"
    echo "  - ssh          : pour l'authentification SSH avec GitLab"
    echo "  - gpg          : pour la vérification des signatures"
    echo
    echo "Exemples:"
    echo "  $0           # Installe la dernière version"
    echo "  $0 1.61.0    # Installe la version 1.61.0"
    echo "  $0 1.62.1    # Installe la version 1.62.1"
    echo
    echo "Format de version attendu: X.Y.Z où X, Y, Z sont des nombres"
    echo
    echo "Après l'installation, utilisez 'glab auth login' pour vous authentifier"
    exit 0
fi

# Exécuter le script principal
main "$@"
