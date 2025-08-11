# GitLab CLI (glab) - Installation et Configuration

Ce dépôt contient un script d'installation automatisé pour GitLab CLI (glab) ainsi que la documentation pour configurer glab avec des instances GitLab personnalisées.

## 📋 Table des matières

- [Installation](#-installation)
- [Configuration pour GitLab personnalisé](#-configuration-pour-gitlab-personnalisé)
- [Utilisation](#-utilisation)
- [Dépannage](#-dépannage)
- [Mise à jour](#-mise-à-jour)

## 🚀 Installation

### Installation automatique avec le script

```bash
# Rendre le script exécutable
chmod +x install-glab.sh

# Installer la dernière version
./install-glab.sh

# Installer une version spécifique
./install-glab.sh 1.61.0
```

### Fonctionnalités du script

- ✅ **Auto-détection** de la dernière version disponible
- ✅ **Vérification** de la version actuellement installée
- ✅ **Installation automatique** des dépendances manquantes
- ✅ **Installation propre** avec nettoyage automatique des fichiers temporaires
- ✅ **Analyse JSON robuste** avec jq pour l'API GitLab
- ✅ **Vérification post-installation** du bon fonctionnement
- ✅ **Gestion d'erreurs** robuste avec messages colorés
- ✅ **Support multi-outil** (wget/curl pour téléchargements)

### Prérequis

Le script gère automatiquement l'installation des dépendances suivantes :

#### Dépendances principales

- `wget` ou `curl` - Pour télécharger les packages
- `dpkg` - Pour installer les packages .deb
- `jq` - Pour analyser les réponses JSON de l'API GitLab

#### Dépendances pour le fonctionnement optimal de glab

- `git` - Nécessaire pour toutes les fonctionnalités Git de glab
- `ssh` - Pour l'authentification SSH avec GitLab
- `gpg` - Pour la vérification des signatures (recommandé pour la sécurité)

> 💡 **Note :** Si certaines dépendances sont manquantes, le script les installera automatiquement via `apt-get`. Privilèges administrateur requis.

### Première utilisation

Après l'installation, commencez par vous authentifier :

```bash
# Authentification avec GitLab.com
glab auth login

# Ou avec une instance GitLab personnalisée
glab auth login --hostname gitlab.example.com
```

Le script vérifie automatiquement que glab fonctionne correctement après l'installation.

## 🔧 Configuration pour GitLab personnalisé

### Cas d'usage : Domaines séparés pour SSH et API

Si votre instance GitLab utilise des domaines différents pour SSH et l'API web (comme dans un environnement d'entreprise), suivez cette configuration.

#### Exemple de configuration

**Domaines :**

- Interface web/API : `https://gitlab.example.com`
- SSH : `git@git.example.com:443`

### Étape 1 : Authentification initiale

```bash
# S'authentifier avec le domaine de l'API web
glab auth login --hostname gitlab.example.com
```

Répondez aux questions comme suit :

- **Comment vous connecter ?** → `Token`
- **Domaines pour registry ?** → `gitlab.example.com,gitlab.example.com:443,registry.gitlab.example.com`
- **Token personnel** → Générez un token avec les scopes `api` et `write_repository`
- **Protocole Git par défaut** → `SSH` ou `HTTPS` selon votre préférence
- **Protocole API** → `HTTPS`

### Étape 2 : Configuration du mapping de domaines

Si l'authentification échoue à cause de domaines différents, configurez manuellement :

1. **Sauvegarder la configuration actuelle :**

```bash
cp ~/.config/glab-cli/config.yml ~/.config/glab-cli/config.yml.backup
```

2. **Éditer la configuration :**

```bash
vi ~/.config/glab-cli/config.yml
```

3. **Ajouter/modifier la section pour le domaine SSH :**

```yaml
hosts:
  gitlab.example.com:
    token: YOUR_TOKEN_HERE
    api_host: gitlab.example.com
    git_protocol: ssh
    api_protocol: https
    user: your.username
    container_registry_domains: gitlab.example.com,gitlab.example.com:443,registry.gitlab.example.com

  git.example.com:
    token: YOUR_TOKEN_HERE
    api_host: gitlab.example.com
    git_protocol: ssh
    api_protocol: https
    user: your.username
    container_registry_domains: gitlab.example.com,gitlab.example.com:443,registry.gitlab.example.com
```

### Étape 3 : Vérification

```bash
cd /path/to/your/project
glab mr list
```

## 📚 Utilisation

### Commandes principales

```bash
# Lister les merge requests
glab mr list

# Voir les détails d'une MR
glab mr view 123

# Créer une nouvelle MR
glab mr create

# Lister les issues
glab issue list

# Voir les détails d'une issue
glab issue view 456

# Cloner un projet
glab repo clone group/project

# Voir l'aide complète
glab --help
```

### Utilisation avec les IA et scripts automatisés

Lors de l'utilisation de glab avec des IA (comme GitHub Copilot, ChatGPT, etc.) ou dans des scripts automatisés, ajoutez `| cat` après les commandes pour éviter le mode interactif :

```bash
# Au lieu de :
glab mr list
glab mr view 123
glab issue list

# Utilisez :
glab mr list | cat
glab mr view 123 | cat
glab issue list | cat
```

> 💡 **Pourquoi `| cat` ?** Cela force la sortie en mode non-interactif, évitant les problèmes de pagination et permettant aux IA de traiter correctement la sortie complète.

### Alias utiles

Ajoutez ces alias à votre `.bashrc` ou `.zshrc` :

```bash
alias glmr="glab mr"
alias glmrl="glab mr list"
alias glmrc="glab mr create"
alias glis="glab issue list"
alias gliv="glab issue view"

# Versions non-interactives pour usage avec IA/scripts
alias glmrl-ai="glab mr list | cat"
alias glmrv-ai="glab mr view"
alias glis-ai="glab issue list | cat"
alias gliv-ai="glab issue view"
```

## 🔍 Dépannage

### Problème : "none of the git remotes configured"

**Erreur :**

```
ERROR: none of the git remotes configured for this repository point to a known GitLab host.
```

**Solution :**

1. Vérifiez vos remotes : `git remote -v`
2. Assurez-vous que le domaine du remote correspond à votre configuration glab
3. Suivez la section [Configuration pour GitLab personnalisé](#-configuration-pour-gitlab-personnalisé)

### Problème : "tls: first record does not look like a TLS handshake"

**Cause :** Le port configuré ne répond pas en HTTPS/TLS.

**Solution :**

1. Vérifiez le bon domaine pour l'API web
2. Testez la connectivité : `curl -I https://your-gitlab-domain.com`
3. Utilisez le bon domaine dans `glab auth login`

### Problème : "i/o timeout"

**Cause :** Problème de connectivité réseau ou port fermé.

**Solution :**

1. Vérifiez votre connexion réseau
2. Testez la connectivité avec curl
3. Vérifiez les pare-feu/proxy d'entreprise

### Vérification de la configuration

```bash
# Voir la configuration actuelle
glab config get

# Voir les hôtes configurés
cat ~/.config/glab-cli/config.yml

# Tester la connexion
glab api projects
```

### Vérification des dépendances

Si vous rencontrez des problèmes, vérifiez que toutes les dépendances sont installées :

```bash
# Vérifier la présence des outils essentiels
command -v git && echo "✅ git installé" || echo "❌ git manquant"
command -v ssh && echo "✅ ssh installé" || echo "❌ ssh manquant"
command -v jq && echo "✅ jq installé" || echo "❌ jq manquant"
command -v curl && echo "✅ curl installé" || echo "❌ curl manquant"
command -v gpg && echo "✅ gpg installé" || echo "❌ gpg manquant"

# Re-exécuter le script pour installer les dépendances manquantes
./install-glab.sh --help  # Affiche l'aide et la liste des dépendances
```

## 🔄 Mise à jour

### Mise à jour automatique

```bash
# Mettre à jour vers la dernière version
./install-glab.sh

# Le script vérifie automatiquement :
# - La version actuelle installée
# - Les dépendances manquantes
# - Le bon fonctionnement après mise à jour
```

### Mise à jour manuelle

```bash
# Vérifier la version actuelle
glab version

# Installer une version spécifique
./install-glab.sh 1.62.0

# Afficher l'aide pour voir toutes les options
./install-glab.sh --help
```

## ⚠️ Notes importantes

- **Installation automatique** : Le script installe automatiquement toutes les dépendances nécessaires
- **Tokens personnels** : Gardez vos tokens en sécurité et ne les committez jamais
- **Permissions** : Assurez-vous que vos tokens ont les scopes `api` et `write_repository`
- **Privilèges administrateur** : Requis pour l'installation automatique des dépendances
- **Environnements d'entreprise** : Les configurations peuvent varier selon votre infrastructure
- **Sauvegarde** : Sauvegardez toujours votre configuration avant modification
- **Vérification post-installation** : Le script teste automatiquement le bon fonctionnement de glab

## 📖 Ressources supplémentaires

- [Documentation officielle glab](https://gitlab.com/gitlab-org/cli)
- [GitLab Personal Access Tokens](https://docs.gitlab.com/ee/user/profile/personal_access_tokens.html)
- [GitLab API Documentation](https://docs.gitlab.com/ee/api/)

## 🤝 Contribution

Si vous rencontrez des problèmes spécifiques à votre environnement ou avez des améliorations à proposer pour le script, n'hésitez pas à contribuer !

---

_Dernière mise à jour : Août 2025 - Script amélioré avec installation automatique des dépendances_
