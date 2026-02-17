
# Projet LDAP : Rapport de Raccordement

Ce projet a pour objectif de se familiariser avec le protocole LDAP, de comprendre son fonctionnement et de mettre en pratique ces connaissances via un raccordement à un serveur public puis au serveur de l'Université de Lorraine.

## 1. Découverte de LDAP et raccordement à un serveur de test

### Objectif
Comprendre le fonctionnement général du protocole LDAP et réaliser un raccordement depuis une application (ici un script Ruby simple).

### Travail préliminaire : comprendre LDAP
Avant le raccordement, voici une synthèse des concepts clés du protocole :

- **Concepts Fondamentaux** :
    - **Annuaire** : Base de données spécialisée optimisée pour la lecture.
    - **Entrée** : Objet stocké dans l'annuaire, identifié par un DN.
    - **DN (Distinguished Name)** : Identifiant unique d'une entrée (ex: `cn=admin,dc=example,dc=com`).
    - **Base DN** : Racine de la recherche dans l'arborescence.
    - **Attributs** : Paires clé-valeur décrivant une entrée (ex: `mail`, `cn`).

- **Structure Arborescente (DIT)** : 
    - L'annuaire est organisé hiérarchiquement (Directory Information Tree), similaire à un système de fichiers, reflétant souvent la structure organisationnelle (`dc`=domain component, `ou`=organizational unit).

- **Opérations Courantes** :
    - **Bind** : Authentification auprès du serveur.
    - **Search** : Recherche d'entrées selon des filtres.
    - **Compare** : Vérification de la valeur d'un attribut.
    - **Add/Modify/Delete** : Opérations d'écriture (ajout, modification, suppression).

- **Sécurité (LDAP vs LDAPS)** :
    - **LDAP (port 389)** : Protocole standard, échanges en clair (non sécurisé).
    - **LDAPS (port 636)** : LDAP sur SSL/TLS, échanges chiffrés (obligatoire pour l'authentification sécurisée).

- **Cas d'usage en entreprise** :
    - Authentification centralisée (SSO).
    - Annuaire d'entreprise (carnet d'adresses partagé).
    - Gestion fine des droits et des accès applications.

### Raccordement au Serveur de Test Public
Pour cette première étape, nous avons utilisé le serveur `ldap.forumsys.com`.

#### Configuration
- **Serveur** : `ldap.forumsys.com`
- **Port** : `389`
- **Bind DN** : `cn=read-only-admin,dc=example,dc=com`
- **Mot de passe** : `password`

#### Gems Utilisées
- `net-ldap` : La gem standard Ruby pour interagir avec les serveurs LDAP. Elle permet de gérer facilement les connexions, les binds et les recherches.

## 3. Raccordement au LDAP de l'Université de Lorraine

Cette étape impliquait une connexion sécurisée à un environnement de production.

### Différences avec le Serveur de Test
1.  **Sécurité (LDAPS vs LDAP)** :
    -   Le serveur public utilise le port **389** (texte clair).
    -   L'université utilise le port **636** avec **SSL/TLS** (LDAPS), ce qui est impératif pour la sécurité des identifiants.
2.  **Authentification** : 
    -   Utilisation des identifiants réels de l'université.
    -   Format du login : `login@univ-lorraine.fr`.
3.  **Structure (DN)** :
    -   Le Base DN est beaucoup plus complexe : `OU=Personnels,OU=_Utilisateurs,OU=UL,DC=ad,DC=univ-lorraine,DC=fr`.
4.  **Attributs Spécifiques** :
    -   Utilisation de `memberOf` pour déterminer l'appartenance (IUT, Département Info) via des groupes spécifiques comme `GGA_STP_FHB--`.

### Implémentation du Script `ldap_univ_poc.rb`
Le script réalisé permet de :
1.  Se connecter en toute sécurité (LDAPS).
2.  S'authentifier avec les variables d'environnement `LDAP_USERNAME` et `LDAP_PASSWORD` (pour ne jamais stocker les mots de passe dans le code).
3.  Rechercher l'utilisateur connecté et afficher ses informations (Nom, Email, Groupes).

## Instructions d'Utilisation

### Prérequis
- Ruby installé
- `bundler` installé

### Installation
```bash
bundle install
```

### Exécution du Test Public
```bash
ruby ldap_public_test.rb
```

### Exécution du PoC Université
**Attention** : Nécessite vos identifiants UL.

```bash
LDAP_USERNAME='votre_login' LDAP_PASSWORD='votre_mot_de_passe' ruby ldap_univ_poc.rb
```
