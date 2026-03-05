# Projet SAÉ : Déploiement d'une application / LDAP

Ce projet a pour objectif de se familiariser avec le protocole LDAP (Lightweight Directory Access Protocol), de comprendre son fonctionnement et ses usages, puis de mettre en pratique ces connaissances dans un contexte réel (annuaire de l'Université de Lorraine).

---

## Table des matières

1. [Synthèse sur le protocole LDAP](#1-synthèse-sur-le-protocole-ldap)
2. [Étape 1 : Raccordement au serveur de test public](#2-étape-1--raccordement-au-serveur-de-test-public)
3. [Étape 2 : Raccordement au LDAP de l'Université de Lorraine](#3-étape-2--raccordement-au-ldap-de-luniversité-de-lorraine)
4. [Instructions d'installation et d'utilisation](#4-instructions-dinstallation-et-dutilisation)
5. [Étape 3 : Déploiement d'une application existante (BookStack)](#5-étape-3--déploiement-dune-application-existante-bookstack)
6. [Étape 4 : Documentation des difficultés rencontrées](#6-étape-4--documentation-des-difficultés-rencontrées)

---

## 1. Synthèse sur le protocole LDAP

### 1.1. Concepts fondamentaux

| Concept | Description |
|---------|-------------|
| **Annuaire** | Base de données spécialisée, optimisée pour la lecture. Contrairement à une BDD relationnelle, il est conçu pour des consultations fréquentes et des écritures rares. |
| **Entrée** | Objet stocké dans l'annuaire, représentant une entité (personne, groupe, machine, etc.). |
| **Attribut** | Paire clé-valeur décrivant une entrée (ex : `mail`, `cn`, `sAMAccountName`). Chaque attribut a un type et peut être mono- ou multi-valué. |
| **DN (Distinguished Name)** | Identifiant unique d'une entrée dans l'arborescence. Ex : `cn=admin,dc=example,dc=com`. |
| **Base DN** | Point de départ (racine) d'une recherche dans l'arborescence. |
| **Bind** | Opération d'authentification auprès du serveur LDAP. |

### 1.2. Structure arborescente (DIT – Directory Information Tree)

L'annuaire LDAP est organisé de manière hiérarchique, similaire à un système de fichiers. Cette structure reflète souvent l'organisation de l'entité :

```
dc=example,dc=com                    (domaine racine)
├── ou=People                        (unité organisationnelle)
│   ├── uid=einstein                 (utilisateur)
│   ├── uid=tesla                    (utilisateur)
│   └── uid=newton                   (utilisateur)
├── ou=Groups                        (unité organisationnelle)
│   ├── cn=Scientists                (groupe)
│   └── cn=Italians                  (groupe)
└── cn=read-only-admin               (compte admin)
```

Les composants principaux du DN :
- **`dc`** (Domain Component) : composant de domaine (`dc=example,dc=com`)
- **`ou`** (Organizational Unit) : unité organisationnelle
- **`cn`** (Common Name) : nom commun
- **`uid`** (User ID) : identifiant utilisateur

### 1.3. Opérations courantes

| Opération | Description |
|-----------|-------------|
| **Bind** | Authentification auprès du serveur (anonyme ou avec identifiants). |
| **Search** | Recherche d'entrées selon une base DN, un scope et un filtre. |
| **Compare** | Vérifie si un attribut d'une entrée contient une valeur spécifique. |
| **Add** | Ajoute une nouvelle entrée dans l'annuaire. |
| **Modify** | Modifie les attributs d'une entrée existante. |
| **Delete** | Supprime une entrée de l'annuaire. |

### 1.4. LDAP vs LDAPS

| Caractéristique | LDAP | LDAPS |
|-----------------|------|-------|
| **Port** | 389 | 636 |
| **Chiffrement** | Aucun (texte clair) | SSL/TLS |
| **Sécurité** | Les identifiants transitent en clair | Échanges entièrement chiffrés |
| **Usage** | Tests, environnements internes isolés | **Obligatoire en production** |

> ⚠️ **Important** : L'utilisation de LDAPS est impérative dès qu'il y a transmission d'identifiants réels. Un bind LDAP sur le port 389 expose le mot de passe en clair sur le réseau.

### 1.5. Cas d'usage en entreprise

- **Authentification centralisée (SSO)** : un seul identifiant pour accéder à toutes les applications de l'entreprise (ex : Active Directory de Microsoft).
- **Annuaire d'entreprise** : carnet d'adresses partagé avec coordonnées, photos, rattachement hiérarchique.
- **Gestion des droits et accès** : contrôle d'accès basé sur l'appartenance à des groupes LDAP (`memberOf`).
- **Service de messagerie** : résolution d'adresses mail via l'annuaire.
- **Provisioning automatisé** : création automatique de comptes dans les applications connectées.

---

## 2. Étape 1 : Raccordement au serveur de test public

### 2.1. Serveur utilisé

| Paramètre | Valeur |
|-----------|--------|
| **Serveur** | `ldap.forumsys.com` |
| **Port** | `389` (LDAP non sécurisé) |
| **Bind DN (admin)** | `cn=read-only-admin,dc=example,dc=com` |
| **Mot de passe** | `password` |
| **Utilisateurs de test** | `uid=einstein`, `uid=tesla`, `uid=newton`, etc. (mot de passe : `password`) |

### 2.2. Tests en ligne de commande (ldapsearch)

Avant de développer le script Ruby, nous avons validé la connectivité avec `ldapsearch` :

**Test de connectivité et exploration de la structure :**
```bash
# Recherche de toutes les entrées sous le domaine racine
ldapsearch -x -H ldap://ldap.forumsys.com -b "dc=example,dc=com" -D "cn=read-only-admin,dc=example,dc=com" -w password

# Recherche des utilisateurs uniquement
ldapsearch -x -H ldap://ldap.forumsys.com -b "dc=example,dc=com" -D "cn=read-only-admin,dc=example,dc=com" -w password "(objectClass=person)"

# Recherche d'un utilisateur spécifique (Einstein)
ldapsearch -x -H ldap://ldap.forumsys.com -b "dc=example,dc=com" -D "cn=read-only-admin,dc=example,dc=com" -w password "(uid=einstein)"

# Bind avec un utilisateur standard
ldapsearch -x -H ldap://ldap.forumsys.com -b "dc=example,dc=com" -D "uid=tesla,dc=example,dc=com" -w password "(uid=tesla)"
```

**Explication des paramètres :**
- `-x` : authentification simple (pas SASL)
- `-H` : URL du serveur LDAP
- `-b` : Base DN (point de départ de la recherche)
- `-D` : DN du compte utilisé pour le bind
- `-w` : mot de passe

### 2.3. Script Ruby (`ldap_public_test.rb`)

Le script de test effectue les opérations suivantes :
1. **Bind admin** : connexion avec le compte `read-only-admin`
2. **Exploration du DIT** : listing des unités organisationnelles et des groupes
3. **Liste des utilisateurs** : recherche et affichage de tous les utilisateurs avec leurs attributs
4. **Bind multi-utilisateurs** : authentification avec différents comptes (`einstein`, `tesla`, `newton`, etc.)
5. **Filtres de recherche** : démonstration des filtres LDAP (par attribut, combinés AND, OR)

### 2.4. Gem utilisée

- **`net-ldap`** : gem standard Ruby pour interagir avec les serveurs LDAP. Elle fournit :
  - Gestion des connexions (LDAP et LDAPS)
  - Opérations de bind, search, add, modify, delete
  - Construction de filtres de recherche (`Net::LDAP::Filter`)
  - Support SSL/TLS pour les connexions sécurisées

---

## 3. Étape 2 : Raccordement au LDAP de l'Université de Lorraine

### 3.1. Informations de connexion

| Paramètre | Valeur |
|-----------|--------|
| **Serveurs** | `ldaps://montet-dc1.ad.univ-lorraine.fr:636` / `ldaps://montet-dc2.ad.univ-lorraine.fr:636` |
| **Port** | `636` (LDAPS) |
| **Authentification** | `login@univ-lorraine.fr` |
| **Base DN (personnels)** | `OU=Personnels,OU=_Utilisateurs,OU=UL,DC=ad,DC=univ-lorraine,DC=fr` |
| **Base DN (utilisateurs)** | `OU=_Utilisateurs,OU=UL,DC=ad,DC=univ-lorraine,DC=fr` |

### 3.2. Tests en ligne de commande (ldapsearch)

```bash
# Recherche sur le serveur LDAPS de l'UL
ldapsearch -x -H ldaps://montet-dc1.ad.univ-lorraine.fr:636 \
  -b "OU=_Utilisateurs,OU=UL,DC=ad,DC=univ-lorraine,DC=fr" \
  -D "votre_login@univ-lorraine.fr" \
  -W \
  "(sAMAccountName=votre_login)"

# Le flag -W demande le mot de passe interactivement (plus sécurisé)
```

### 3.3. Différences avec le serveur de test public

| Aspect | Serveur public (test) | Serveur UL (production) |
|--------|----------------------|------------------------|
| **Protocole** | LDAP (port 389, texte clair) | LDAPS (port 636, SSL/TLS) |
| **Authentification** | DN complet (`cn=...`) | Format email (`login@univ-lorraine.fr`) |
| **Certificat** | Non applicable | Certificat SSL de l'UL (auto-signé, nécessite `VERIFY_NONE` ou ajout au truststore) |
| **Structure DN** | Simple (`dc=example,dc=com`) | Complexe (`OU=Personnels,OU=_Utilisateurs,...`) |
| **Type d'annuaire** | OpenLDAP standard | Active Directory (Microsoft) |
| **Attributs clés** | `uid`, `cn`, `mail` | `sAMAccountName`, `cn`, `mail`, `memberOf` |
| **Groupes** | `groupOfUniqueNames` / `uniqueMember` | Groupes AD / `memberOf` |
| **Scope** | Annuaire plat | Arborescence hiérarchique multi-OU |
| **Mot de passe** | Hardcodé (`password`) | Identifiants réels → **jamais dans le code** |

### 3.4. Script PoC (`ldap_univ_poc.rb`)

Le script de proof of concept permet :
1. **Connexion sécurisée (LDAPS)** au serveur de l'UL avec failover automatique entre les 2 serveurs
2. **Authentification** via les variables d'environnement (`LDAP_USERNAME`, `LDAP_PASSWORD`)
3. **Recherche d'utilisateur** par login (`sAMAccountName`) ou par nom (`cn`)
4. **Affichage des informations** : nom, login, email, téléphone
5. **Rattachement structurel** : détection automatique de l'IUTNC et du Département Informatique via les groupes `memberOf`

### 3.5. Précaution concernant le mot de passe

Le mot de passe **ne doit jamais apparaître en clair dans le code source**. Deux méthodes sont proposées :

1. **Fichier `.env`** (recommandé) : créer un fichier `.env` à partir de `.env.example`
2. **Variables d'environnement inline** : passer les variables directement dans la commande

Le fichier `.env` est ajouté au `.gitignore` pour ne jamais être versionné.

---

## 4. Instructions d'installation et d'utilisation

### 4.1. Prérequis

- **Système** : Linux (obligatoire)
- **Ruby** : version disponible sur la machine de développement
- **Bundler** : `gem install bundler` si non installé
- **ldapsearch** : `sudo apt install ldap-utils` (pour les tests CLI)

### 4.2. Installation

```bash
# Cloner le dépôt
git clone <url_du_depot>
cd pre_cdd

# Installer les dépendances Ruby
bundle install
```

### 4.3. Exécution du test public (Étape 1)

```bash
ruby ldap_public_test.rb
```

Ce script ne nécessite aucune configuration, il se connecte directement au serveur public de test.

### 4.4. Exécution du PoC Université (Étape 2)

**Méthode 1 : Fichier `.env` (recommandé)**
```bash
# Copier le fichier d'exemple
cp .env.example .env

# Editer avec vos identifiants UL
nano .env

# Exécuter le script
ruby ldap_univ_poc.rb
```

**Méthode 2 : Variables inline**
```bash
LDAP_USERNAME='votre_login' LDAP_PASSWORD='votre_mdp' ruby ldap_univ_poc.rb
```

**Options :**
```bash
LDAP_USERNAME='votre_login' LDAP_PASSWORD='votre_mot_de_passe' ruby ldap_univ_poc.rb
```

## 5. Étape 3 : Déploiement d'une application existante (BookStack)

L'objectif est de déployer BookStack via Docker et de déléguer l'authentification au LDAP de l'Université de Lorraine.

### 5.1. Prérequis

- **Docker** et **Docker Compose** installés sur la machine.
- Accès au réseau de l'Université de Lorraine (pour joindre `montet-dc1.ad.univ-lorraine.fr:636`).

### 5.2. Configuration

Toute la configuration LDAP est passée via les variables d'environnement définies dans le fichier `docker-compose.yml` et le fichier `.env`.

1. **Créer le fichier `.env`** :
   ```bash
   cp .env.example .env
   ```
2. **Modifier `.env`** avec vos identifiants UL. Remarquez que pour l'Active Directory, `LDAP_DN` doit être sous la forme UPN (`login@univ-lorraine.fr`) :
   ```env
   LDAP_DN=votre_login@univ-lorraine.fr
   LDAP_PASS=votre_mot_de_passe_ul
   ```

### 5.3. Lancement de l'application

Lancez la pile Docker :
```bash
docker-compose up -d
```

L'application sera disponible sur **[http://localhost:6875](http://localhost:6875)**.

### 5.4. Certificats TLS (Options A et B)

Par défaut, l'application est configurée avec **Option B** (pour le développement) : `LDAP_TLS_INSECURE=true`, ce qui ignore la validation du certificat auto-signé de l'UL.

Si vous souhaitez utiliser l' **Option A** (recommandée / production), vous devez :
1. Récupérer le certificat racine de l'UL :
   ```bash
   openssl s_client -connect montet-dc1.ad.univ-lorraine.fr:636 -showcerts </dev/null 2>/dev/null
   ```
   Copiez le dernier bloc `-----BEGIN CERTIFICATE-----` ... `-----END CERTIFICATE-----` dans un fichier nommé `ul-ca.crt` à la racine du projet.
2. Dans `docker-compose.yml`, décommentez la ligne de montage du volume et la variable `LDAP_TLS_CA_CERT`, puis commentez `LDAP_TLS_INSECURE=true`.

### 5.5. Test de connexion LDAP

Une fois BookStack lancé, connectez-vous avec :
- **Login** : Votre adresse mail (ou identifiant) en fonction de la configuration LDAP. Dans cette configuration, `LDAP_USER_FILTER` est paramétré sur `(&(objectClass=user)(sAMAccountName=${input}))` ce qui signifie que vous devez saisir **votre login court UL** (la partie avant le `@`).
- **Mot de passe** : Votre mot de passe UL.

Le profil se créera automatiquement en reprenant votre "displayName" (nom affiché) et votre "mail" configuré dans l'Active Directory.

## 6. Étape 4 : Documentation des difficultés rencontrées

Conformément aux travaux demandés, voici une synthèse des difficultés rencontrées lors du raccordement LDAP :

- **Certificat TLS** : Le certificat de l'UL n'est pas reconnu par défaut.
    - *Solution* : Utilisation de `LDAP_TLS_INSECURE=true` en développement.
- **Format du DN de bind** : L'Active Directory refuse le format DN classique.
    - *Solution* : Utilisation du format UPN (`login@univ-lorraine.fr`).
- **Filtre utilisateur** : Nécessité d'utiliser `sAMAccountName` (et non `uid` ou `cn`) pour le login UL.
- **Identifiant Unique** : Utilisation de `objectGUID` pour éviter les doublons en cas de changement de login.
- **Connectivité réseau** : Le serveur LDAP n'est accessible que via le réseau de l'UL ou le VPN.

