
# Documentation des Routes et Modèles de l'API BAES

Cette documentation détaille les modèles de données et les routes API disponibles dans l'application BAES (Bloc Autonome d'Éclairage de Sécurité). Elle explique comment utiliser chaque endpoint et les résultats attendus.

## Table des matières

1. [Introduction](#introduction)
2. [Modèles de données](#modèles-de-données)
3. [Routes API](#routes-api)
    - [Authentification](#authentification)
    - [Utilisateurs](#utilisateurs)
    - [Sites](#sites)
    - [Bâtiments](#bâtiments)
    - [Étages](#étages)
    - [Cartes](#cartes)
    - [BAES](#baes)
    - [Historique des erreurs](#historique-des-erreurs)
    - [Rôles](#rôles)
    - [Associations utilisateur-site-rôle](#associations-utilisateur-site-rôle)

## Introduction

L'API BAES est une application Flask qui permet de gérer les blocs autonomes d'éclairage de sécurité dans différents sites et bâtiments. Elle offre des fonctionnalités pour gérer les utilisateurs, les sites, les bâtiments, les étages, les cartes, les BAES et l'historique des erreurs.

## Modèles de données

### User (Utilisateur)
```
- id: Identifiant unique
- login: Nom d'utilisateur (unique)
- password: Mot de passe hashé
- user_site_roles: Relation avec les rôles de l'utilisateur sur les sites
```

### Site
```
- id: Identifiant unique
- name: Nom du site (unique)
- batiments: Relation avec les bâtiments du site
- carte: Relation avec la carte du site
```

### Batiment
```
- id: Identifiant unique
- name: Nom du bâtiment
- site_id: Référence au site parent
```

### Etage
```
- id: Identifiant unique
- name: Nom de l'étage
- batiment_id: Référence au bâtiment parent
```

### Carte
```
- id: Identifiant unique
- chemin: Chemin vers le fichier image
- etage_id: Référence à l'étage (optionnel)
- site_id: Référence au site (optionnel)
- center_lat: Latitude du centre de la carte
- center_lng: Longitude du centre de la carte
- zoom: Niveau de zoom de la carte
```

### BAES
```
- id: Identifiant unique
- name: Nom du BAES (unique)
- position: Position sur la carte (format JSON)
- etage_id: Référence à l'étage où se trouve le BAES
- erreurs: Relation avec l'historique des erreurs
```

### HistoriqueErreur
```
- id: Identifiant unique
- date: Date de l'erreur
- description: Description de l'erreur
- baes_id: Référence au BAES concerné
```

### Role
```
- id: Identifiant unique
- name: Nom du rôle
```

### UserSiteRole
```
- id: Identifiant unique
- user_id: Référence à l'utilisateur
- site_id: Référence au site
- role_id: Référence au rôle
```

## Routes API

### Authentification

#### POST /auth/login
- **Description**: Authentifie un utilisateur
- **Paramètres**:
    - `login`: Nom d'utilisateur
    - `password`: Mot de passe
- **Résultat**: Token d'authentification et informations utilisateur
- **Exemple de réponse**:
  ```json
  {
    "token": "jwt_token_here",
    "user": {
      "id": 1,
      "login": "admin"
    }
  }
  ```

#### POST /auth/logout
- **Description**: Déconnecte l'utilisateur actuel
- **Résultat**: Message de confirmation
- **Exemple de réponse**:
  ```json
  {
    "message": "Déconnexion réussie"
  }
  ```

### Utilisateurs

#### GET /users
- **Description**: Récupère la liste de tous les utilisateurs
- **Résultat**: Liste des utilisateurs
- **Exemple de réponse**:
  ```json
  [
    {
      "id": 1,
      "login": "admin"
    },
    {
      "id": 2,
      "login": "user1"
    }
  ]
  ```

#### GET /users/{id}
- **Description**: Récupère un utilisateur par son ID
- **Paramètres**:
    - `id`: ID de l'utilisateur (dans l'URL)
- **Résultat**: Détails de l'utilisateur
- **Exemple de réponse**:
  ```json
  {
    "id": 1,
    "login": "admin"
  }
  ```

#### POST /users
- **Description**: Crée un nouvel utilisateur
- **Paramètres**:
    - `login`: Nom d'utilisateur
    - `password`: Mot de passe
- **Résultat**: Utilisateur créé
- **Exemple de réponse**:
  ```json
  {
    "id": 3,
    "login": "nouveau_user"
  }
  ```

#### PUT /users/{id}
- **Description**: Met à jour un utilisateur existant
- **Paramètres**:
    - `id`: ID de l'utilisateur (dans l'URL)
    - `login`: Nouveau nom d'utilisateur (optionnel)
    - `password`: Nouveau mot de passe (optionnel)
- **Résultat**: Utilisateur mis à jour
- **Exemple de réponse**:
  ```json
  {
    "id": 1,
    "login": "admin_updated"
  }
  ```

#### DELETE /users/{id}
- **Description**: Supprime un utilisateur
- **Paramètres**:
    - `id`: ID de l'utilisateur (dans l'URL)
- **Résultat**: Message de confirmation
- **Exemple de réponse**:
  ```json
  {
    "message": "Utilisateur supprimé avec succès"
  }
  ```

### Sites

#### GET /sites
- **Description**: Récupère la liste de tous les sites
- **Résultat**: Liste des sites
- **Exemple de réponse**:
  ```json
  [
    {
      "id": 1,
      "name": "Site A"
    },
    {
      "id": 2,
      "name": "Site B"
    }
  ]
  ```

#### GET /sites/{id}
- **Description**: Récupère un site par son ID
- **Paramètres**:
    - `id`: ID du site (dans l'URL)
- **Résultat**: Détails du site
- **Exemple de réponse**:
  ```json
  {
    "id": 1,
    "name": "Site A"
  }
  ```

#### POST /sites
- **Description**: Crée un nouveau site
- **Paramètres**:
    - `name`: Nom du site
- **Résultat**: Site créé
- **Exemple de réponse**:
  ```json
  {
    "id": 3,
    "name": "Nouveau Site"
  }
  ```

#### PUT /sites/{id}
- **Description**: Met à jour un site existant
- **Paramètres**:
    - `id`: ID du site (dans l'URL)
    - `name`: Nouveau nom du site
- **Résultat**: Site mis à jour
- **Exemple de réponse**:
  ```json
  {
    "id": 1,
    "name": "Site A Modifié"
  }
  ```

#### DELETE /sites/{id}
- **Description**: Supprime un site
- **Paramètres**:
    - `id`: ID du site (dans l'URL)
- **Résultat**: Message de confirmation
- **Exemple de réponse**:
  ```json
  {
    "message": "Site supprimé avec succès"
  }
  ```

### Cartes

#### GET /cartes
- **Description**: Récupère la liste de toutes les cartes
- **Résultat**: Liste des cartes
- **Exemple de réponse**:
  ```json
  [
    {
      "id": 1,
      "chemin": "http://localhost:5000/uploads/carte1.jpg",
      "center_lat": 48.8566,
      "center_lng": 2.3522,
      "zoom": 1.0,
      "etage_id": null,
      "site_id": 1
    }
  ]
  ```

#### GET /cartes/{id}
- **Description**: Récupère une carte par son ID
- **Paramètres**:
    - `id`: ID de la carte (dans l'URL)
- **Résultat**: Détails de la carte
- **Exemple de réponse**:
  ```json
  {
    "id": 1,
    "chemin": "http://localhost:5000/uploads/carte1.jpg",
    "center_lat": 48.8566,
    "center_lng": 2.3522,
    "zoom": 1.0,
    "etage_id": null,
    "site_id": 1
  }
  ```

#### POST /cartes
- **Description**: Crée une nouvelle carte
- **Paramètres**:
    - `file`: Fichier image de la carte
    - `center_lat`: Latitude du centre
    - `center_lng`: Longitude du centre
    - `zoom`: Niveau de zoom
- **Résultat**: Carte créée
- **Exemple de réponse**:
  ```json
  {
    "id": 2,
    "chemin": "http://localhost:5000/uploads/nouvelle_carte.jpg",
    "center_lat": 48.8566,
    "center_lng": 2.3522,
    "zoom": 1.0,
    "etage_id": null,
    "site_id": null
  }
  ```

#### GET /sites/carte/get_by_site/{site_id}
- **Description**: Récupère la carte associée à un site
- **Paramètres**:
    - `site_id`: ID du site (dans l'URL)
- **Résultat**: Carte du site
- **Exemple de réponse**:
  ```json
  {
    "id": 1,
    "chemin": "http://localhost:5000/uploads/carte1.jpg",
    "center_lat": 48.8566,
    "center_lng": 2.3522,
    "zoom": 1.0,
    "etage_id": null,
    "site_id": 1
  }
  ```

#### POST /sites/{site_id}/assign
- **Description**: Assigne une carte existante à un site
- **Paramètres**:
    - `site_id`: ID du site (dans l'URL)
    - `card_id`: ID de la carte à assigner
- **Résultat**: Message de confirmation
- **Exemple de réponse**:
  ```json
  {
    "message": "Carte assignée au site avec succès."
  }
  ```

#### PUT /sites/carte/update_by_site/{site_id}
- **Description**: Met à jour la carte d'un site
- **Paramètres**:
    - `site_id`: ID du site (dans l'URL)
    - `file`: Nouveau fichier image (optionnel)
    - `center_lat`: Nouvelle latitude (optionnel)
    - `center_lng`: Nouvelle longitude (optionnel)
    - `zoom`: Nouveau zoom (optionnel)
- **Résultat**: Carte mise à jour
- **Exemple de réponse**:
  ```json
  {
    "message": "Carte mise à jour avec succès",
    "carte": {
      "id": 1,
      "chemin": "http://localhost:5000/uploads/carte_updated.jpg",
      "center_lat": 48.8566,
      "center_lng": 2.3522,
      "zoom": 1.5,
      "site_id": 1,
      "etage_id": null
    }
  }
  ```

### BAES

#### GET /baes
- **Description**: Récupère la liste de tous les BAES
- **Résultat**: Liste des BAES
- **Exemple de réponse**:
  ```json
  [
    {
      "id": 1,
      "name": "BAES 1",
      "position": {"x": 100, "y": 200},
      "etage_id": 1
    },
    {
      "id": 2,
      "name": "BAES 2",
      "position": {"x": 150, "y": 250},
      "etage_id": 1
    }
  ]
  ```

#### GET /baes/{id}
- **Description**: Récupère un BAES par son ID
- **Paramètres**:
    - `id`: ID du BAES (dans l'URL)
- **Résultat**: Détails du BAES
- **Exemple de réponse**:
  ```json
  {
    "id": 1,
    "name": "BAES 1",
    "position": {"x": 100, "y": 200},
    "etage_id": 1
  }
  ```

#### POST /baes
- **Description**: Crée un nouveau BAES
- **Paramètres**:
    - `name`: Nom du BAES
    - `position`: Position sur la carte (objet JSON)
    - `etage_id`: ID de l'étage
- **Résultat**: BAES créé
- **Exemple de réponse**:
  ```json
  {
    "id": 3,
    "name": "BAES 3",
    "position": {"x": 200, "y": 300},
    "etage_id": 2
  }
  ```

#### PUT /baes/{id}
- **Description**: Met à jour un BAES existant
- **Paramètres**:
    - `id`: ID du BAES (dans l'URL)
    - `name`: Nouveau nom (optionnel)
    - `position`: Nouvelle position (optionnel)
    - `etage_id`: Nouvel ID d'étage (optionnel)
- **Résultat**: BAES mis à jour
- **Exemple de réponse**:
  ```json
  {
    "id": 1,
    "name": "BAES 1 Modifié",
    "position": {"x": 120, "y": 220},
    "etage_id": 1
  }
  ```

#### DELETE /baes/{id}
- **Description**: Supprime un BAES
- **Paramètres**:
    - `id`: ID du BAES (dans l'URL)
- **Résultat**: Message de confirmation
- **Exemple de réponse**:
  ```json
  {
    "message": "BAES supprimé avec succès"
  }
  ```

### Bâtiments

#### GET /batiments
- **Description**: Récupère la liste de tous les bâtiments
- **Résultat**: Liste des bâtiments
- **Exemple de réponse**:
  ```json
  [
    {
      "id": 1,
      "name": "Bâtiment A",
      "site_id": 1
    },
    {
      "id": 2,
      "name": "Bâtiment B",
      "site_id": 1
    }
  ]
  ```

#### GET /batiments/{id}
- **Description**: Récupère un bâtiment par son ID
- **Paramètres**:
    - `id`: ID du bâtiment (dans l'URL)
- **Résultat**: Détails du bâtiment
- **Exemple de réponse**:
  ```json
  {
    "id": 1,
    "name": "Bâtiment A",
    "site_id": 1
  }
  ```

#### POST /batiments
- **Description**: Crée un nouveau bâtiment
- **Paramètres**:
    - `name`: Nom du bâtiment
    - `site_id`: ID du site parent
- **Résultat**: Bâtiment créé
- **Exemple de réponse**:
  ```json
  {
    "id": 3,
    "name": "Nouveau Bâtiment",
    "site_id": 2
  }
  ```

#### PUT /batiments/{id}
- **Description**: Met à jour un bâtiment existant
- **Paramètres**:
    - `id`: ID du bâtiment (dans l'URL)
    - `name`: Nouveau nom (optionnel)
    - `site_id`: Nouvel ID de site (optionnel)
- **Résultat**: Bâtiment mis à jour
- **Exemple de réponse**:
  ```json
  {
    "id": 1,
    "name": "Bâtiment A Modifié",
    "site_id": 1
  }
  ```

#### DELETE /batiments/{id}
- **Description**: Supprime un bâtiment
- **Paramètres**:
    - `id`: ID du bâtiment (dans l'URL)
- **Résultat**: Message de confirmation
- **Exemple de réponse**:
  ```json
  {
    "message": "Bâtiment supprimé avec succès"
  }
  ```

### Étages

#### GET /etages
- **Description**: Récupère la liste de tous les étages
- **Résultat**: Liste des étages
- **Exemple de réponse**:
  ```json
  [
    {
      "id": 1,
      "name": "Rez-de-chaussée",
      "batiment_id": 1
    },
    {
      "id": 2,
      "name": "1er étage",
      "batiment_id": 1
    }
  ]
  ```

#### GET /etages/{id}
- **Description**: Récupère un étage par son ID
- **Paramètres**:
    - `id`: ID de l'étage (dans l'URL)
- **Résultat**: Détails de l'étage
- **Exemple de réponse**:
  ```json
  {
    "id": 1,
    "name": "Rez-de-chaussée",
    "batiment_id": 1
  }
  ```

#### POST /etages
- **Description**: Crée un nouvel étage
- **Paramètres**:
    - `name`: Nom de l'étage
    - `batiment_id`: ID du bâtiment parent
- **Résultat**: Étage créé
- **Exemple de réponse**:
  ```json
  {
    "id": 3,
    "name": "2ème étage",
    "batiment_id": 1
  }
  ```

#### PUT /etages/{id}
- **Description**: Met à jour un étage existant
- **Paramètres**:
    - `id`: ID de l'étage (dans l'URL)
    - `name`: Nouveau nom (optionnel)
    - `batiment_id`: Nouvel ID de bâtiment (optionnel)
- **Résultat**: Étage mis à jour
- **Exemple de réponse**:
  ```json
  {
    "id": 1,
    "name": "RDC",
    "batiment_id": 1
  }
  ```

#### DELETE /etages/{id}
- **Description**: Supprime un étage
- **Paramètres**:
    - `id`: ID de l'étage (dans l'URL)
- **Résultat**: Message de confirmation
- **Exemple de réponse**:
  ```json
  {
    "message": "Étage supprimé avec succès"
  }
  ```

#### GET /etages/carte/get_by_floor/{floor_id}
- **Description**: Récupère la carte associée à un étage
- **Paramètres**:
    - `floor_id`: ID de l'étage (dans l'URL)
- **Résultat**: Carte de l'étage
- **Exemple de réponse**:
  ```json
  {
    "id": 3,
    "chemin": "http://localhost:5000/uploads/etage1.jpg",
    "center_lat": 48.8566,
    "center_lng": 2.3522,
    "zoom": 1.5,
    "etage_id": 1,
    "site_id": null
  }
  ```

### Historique des erreurs

#### GET /erreurs
- **Description**: Récupère la liste de tous les historiques d'erreurs
- **Résultat**: Liste des erreurs
- **Exemple de réponse**:
  ```json
  [
    {
      "id": 1,
      "date": "2023-05-15T10:30:00",
      "description": "Batterie faible",
      "baes_id": 1
    },
    {
      "id": 2,
      "date": "2023-05-16T14:45:00",
      "description": "Ampoule défectueuse",
      "baes_id": 2
    }
  ]
  ```

#### GET /erreurs/{id}
- **Description**: Récupère un historique d'erreur par son ID
- **Paramètres**:
    - `id`: ID de l'erreur (dans l'URL)
- **Résultat**: Détails de l'erreur
- **Exemple de réponse**:
  ```json
  {
    "id": 1,
    "date": "2023-05-15T10:30:00",
    "description": "Batterie faible",
    "baes_id": 1
  }
  ```

#### POST /erreurs
- **Description**: Crée un nouvel historique d'erreur
- **Paramètres**:
    - `date`: Date de l'erreur
    - `description`: Description de l'erreur
    - `baes_id`: ID du BAES concerné
- **Résultat**: Erreur créée
- **Exemple de réponse**:
  ```json
  {
    "id": 3,
    "date": "2023-05-17T09:15:00",
    "description": "Connexion perdue",
    "baes_id": 1
  }
  ```

#### PUT /erreurs/{id}
- **Description**: Met à jour un historique d'erreur existant
- **Paramètres**:
    - `id`: ID de l'erreur (dans l'URL)
    - `date`: Nouvelle date (optionnel)
    - `description`: Nouvelle description (optionnel)
    - `baes_id`: Nouvel ID de BAES (optionnel)
- **Résultat**: Erreur mise à jour
- **Exemple de réponse**:
  ```json
  {
    "id": 1,
    "date": "2023-05-15T10:45:00",
    "description": "Batterie très faible",
    "baes_id": 1
  }
  ```

#### DELETE /erreurs/{id}
- **Description**: Supprime un historique d'erreur
- **Paramètres**:
    - `id`: ID de l'erreur (dans l'URL)
- **Résultat**: Message de confirmation
- **Exemple de réponse**:
  ```json
  {
    "message": "Historique d'erreur supprimé avec succès"
  }
  ```

### Rôles

#### GET /roles
- **Description**: Récupère la liste de tous les rôles
- **Résultat**: Liste des rôles
- **Exemple de réponse**:
  ```json
  [
    {
      "id": 1,
      "name": "Admin"
    },
    {
      "id": 2,
      "name": "User"
    }
  ]
  ```

#### GET /roles/{id}
- **Description**: Récupère un rôle par son ID
- **Paramètres**:
    - `id`: ID du rôle (dans l'URL)
- **Résultat**: Détails du rôle
- **Exemple de réponse**:
  ```json
  {
    "id": 1,
    "name": "Admin"
  }
  ```

#### POST /roles
- **Description**: Crée un nouveau rôle
- **Paramètres**:
    - `name`: Nom du rôle
- **Résultat**: Rôle créé
- **Exemple de réponse**:
  ```json
  {
    "id": 3,
    "name": "Supervisor"
  }
  ```

### Associations utilisateur-site-rôle

#### GET /user_site_role
- **Description**: Récupère la liste de toutes les associations utilisateur-site-rôle
- **Résultat**: Liste des associations
- **Exemple de réponse**:
  ```json
  [
    {
      "id": 1,
      "user_id": 1,
      "site_id": 1,
      "role_id": 1
    },
    {
      "id": 2,
      "user_id": 2,
      "site_id": 1,
      "role_id": 2
    }
  ]
  ```

#### POST /user_site_role
- **Description**: Crée une nouvelle association utilisateur-site-rôle
- **Paramètres**:
    - `user_id`: ID de l'utilisateur
    - `site_id`: ID du site
    - `role_id`: ID du rôle
- **Résultat**: Association créée
- **Exemple de réponse**:
  ```json
  {
    "id": 3,
    "user_id": 1,
    "site_id": 2,
    "role_id": 1
  }
  ```

#### DELETE /user_site_role/{id}
- **Description**: Supprime une association utilisateur-site-rôle
- **Paramètres**:
    - `id`: ID de l'association (dans l'URL)
- **Résultat**: Message de confirmation
- **Exemple de réponse**:
  ```json
  {
    "message": "Association supprimée avec succès"
  }
  ```

## Conclusion

Cette documentation couvre l'ensemble des modèles et des routes disponibles dans l'API BAES. Pour plus de détails sur chaque endpoint, vous pouvez consulter la documentation Swagger accessible à l'adresse `/swagger/` de l'API.