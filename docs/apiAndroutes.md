## BAES API Routes Summary (v1.0)

Ce document présente un récapitulatif de toutes les routes disponibles dans l'API BAES, avec leur utilité, les
paramètres attendus (path, query, body) et les formats de réponse.

---

### 1. Authentication

#### POST `/auth/login`

- **Utilité** : Authentifie un utilisateur.
- **Paramètres** :
    - **Body** (application/json) :
      ```json
      {
        "login": "monlogin",
        "password": "monmotdepasse"
      }
      ```
- **Réponses** :
    - **200 OK** :
      ```json
      {
        "message": "Connecté",
        "sites": [{ "id": 3, "name": "Site A", "roles": [{ "id":2, "name":"admin" }] }],
        "user_id": 1
      }
      ```
    - **401 Unauthorized** :
      ```json
      { "error": "Identifiants invalides" }
      ```

#### GET `/auth/logout`

- **Utilité** : Déconnecte l'utilisateur courant.
- **Paramètres** : aucun.
- **Réponses** :
    - **200 OK** :
      ```json
      { "message": "Déconnecté" }
      ```

---

### 2. Bâtiment CRUD

#### GET `/batiments/`

- **Utilité** : Récupère la liste de tous les bâtiments.
- **Paramètres** : aucun.
- **Réponses** :
    - **200 OK** :
      ```json
      [ { "id":1, "name":"Batiment 1", "polygon_points":{}, "site_id":1 } ]
      ```
    - **500 Internal Server Error**

#### POST `/batiments/`

- **Utilité** : Crée un nouveau bâtiment.
- **Paramètres** :
    - **Body** (application/json) :
      ```json
      { "name":"Batiment 1", "polygon_points":{ "points":[[0,0],[1,1]] }, "site_id":1 }
      ```
- **Réponses** :
    - **201 Created** :
      ```json
      { "id":1, "name":"Batiment 1", "polygon_points":{}, "site_id":1 }
      ```
    - **400 Bad Request**

#### GET `/batiments/{batiment_id}`

- **Utilité** : Récupère les détails d'un bâtiment par son ID.
- **Paramètres** :
    - **Path** : `batiment_id` (integer)
- **Réponses** :
    - **200 OK** :
      ```json
      { "id":1, "name":"Batiment 1", "polygon_points":{}, "site_id":1 }
      ```
    - **404 Not Found**

#### PUT `/batiments/{batiment_id}`

- **Utilité** : Met à jour un bâtiment existant.
- **Paramètres** :
    - **Path** : `batiment_id` (integer)
    - **Body** (application/json) :
      ```json
      { "name":"Batiment mis à jour", "polygon_points":{ "points":[[1,1],[2,2]] }, "site_id":2 }
      ```
- **Réponses** :
    - **200 OK** :
      ```json
      { "id":1, "name":"Batiment mis à jour", "polygon_points":{}, "site_id":2 }
      ```
    - **404 Not Found**

#### DELETE `/batiments/{batiment_id}`

- **Utilité** : Supprime un bâtiment par son ID.
- **Paramètres** :
    - **Path** : `batiment_id` (integer)
- **Réponses** :
    - **200 OK** :
      ```json
      { "message":"Bâtiment supprimé avec succès" }
      ```
    - **404 Not Found**

#### GET `/batiments/{batiment_id}/floors`

- **Utilité** : Récupère tous les étages d'un bâtiment par son ID.
- **Paramètres** :
    - **Path** : `batiment_id` (integer)
- **Réponses** :
    - **200 OK** :
      ```json
      [ { "id":1, "name":"Etage 1", "batiment_id":1 } ]
      ```
    - **404 Not Found**
    - **500 Internal Server Error**

---

### 3. Carte CRUD

#### GET `/cartes/carte/{carte_id}`

- **Utilité** : Récupère les métadonnées et l'URL de l'image d'une carte.
- **Paramètres** :
    - **Path** : `carte_id` (integer)
- **Réponses** :
    - **200 OK** :
      ```json
      { "id":1, "site_id":1, "etage_id":null, "center_lat":41.53, "center_lng":69.16, "zoom":-4.90, "chemin":"http://.../vue_site.jpg" }
      ```
    - **404 Not Found**

#### PUT `/cartes/carte/{carte_id}`

- **Utilité** : Met à jour une carte existante (image, centre, zoom, association site/étage).
- **Paramètres** :
    - **Path** : `carte_id` (integer)
    - **FormData** :
        - `file` (fichier image)
        - `center_lat` (number)
        - `center_lng` (number)
        - `zoom` (number)
        - `site_id` (integer)
        - `etage_id` (integer)
- **Réponses** :
    - **200 OK** :
      ```json
      { "carte":{...}, "message":"Carte mise à jour avec succès" }
      ```
    - **400 Bad Request**
    - **404 Not Found**

#### POST `/cartes/upload-carte`

- **Utilité** : Upload d'une nouvelle carte avec paramètres et association.
- **Paramètres** :
    - **FormData** :
        - `file` (fichier image) *
        - `center_lat` (number, default=0)
        - `center_lng` (number, default=0)
        - `zoom` (number, default=1)
        - `site_id` (integer) ou `etage_id` (integer) (exactement l'un)
- **Réponses** :
    - **200 OK** :
      ```json
      { "carte":{...}, "message":"Fichier uploadé avec succès" }
      ```
    - **400 Bad Request**

#### GET `/cartes/uploads/{filename}`

- **Utilité** : Sert le fichier image uploadé.
- **Paramètres** :
    - **Path** : `filename` (string)
- **Réponses** :
    - **200 OK** (image)
    - **404 Not Found**

#### GET `/sites/carte/get_by_floor/{floor_id}`

- **Utilité** : Récupère la carte associée à un étage.
- **Paramètres** :
    - **Path** : `floor_id` (integer)
- **Réponses** :
    - **200 OK** :
      ```json
      { "id":3, "etage_id":2, "site_id":null, "center_lat":0.3, "center_lng":0.4, "zoom":1.2, "chemin":"..." }
      ```
    - **404 Not Found**
    - **500 Internal Server Error**

#### GET `/sites/carte/get_by_site/{site_id}`

- **Utilité** : Récupère la carte associée à un site.
- **Paramètres** :
    - **Path** : `site_id` (integer)
- **Réponses** :
    - **200 OK** :
      ```json
      { "id":1, "site_id":1, "etage_id":null, "center_lat":41.53, "center_lng":69.16, "zoom":-4.90, "chemin":"..." }
      ```
    - **404 Not Found**
    - **500 Internal Server Error**

---

### 4. Étage CRUD

#### GET `/etages/`

- **Utilité** : Récupère la liste de tous les étages.
- **Paramètres** : aucun.
- **Réponses** :
    - **200 OK** :
      ```json
      [ { "id":1, "batiment_id":1, "name":"Etage 1" } ]
      ```
    - **500 Internal Server Error**

#### POST `/etages/`

- **Utilité** : Crée un nouvel étage.
- **Paramètres** :
    - **Body** (application/json) :
      ```json
      { "batiment_id":1, "name":"Etage 1" }
      ```
- **Réponses** :
    - **201 Created** :
      ```json
      { "id":1, "batiment_id":1, "name":"Etage 1" }
      ```
    - **400 Bad Request**

#### GET `/etages/{etage_id}`

- **Utilité** : Récupère un étage par son ID.
- **Paramètres** :
    - **Path** : `etage_id` (integer)
- **Réponses** :
    - **200 OK** :
      ```json
      { "id":1, "batiment_id":1, "name":"Etage 1" }
      ```
    - **404 Not Found**

#### PUT `/etages/{etage_id}`

- **Utilité** : Met à jour un étage existant.
- **Paramètres** :
    - **Path** : `etage_id` (integer)
    - **Body** (application/json) :
      ```json
      { "batiment_id":2, "name":"Etage mis à jour" }
      ```
- **Réponses** :
    - **200 OK** :
      ```json
      { "id":1, "batiment_id":2, "name":"Etage mis à jour" }
      ```
    - **404 Not Found**

#### DELETE `/etages/{etage_id}`

- **Utilité** : Supprime un étage par son ID.
- **Paramètres** :
    - **Path** : `etage_id` (integer)
- **Réponses** :
    - **200 OK** :
      ```json
      { "message":"Étage supprimé avec succès" }
      ```
    - **404 Not Found**

#### GET `/etages/{etage_id}/baes`

- **Utilité** : Récupère tous les BAES d'un étage par son ID.
- **Paramètres** :
    - **Path** : `etage_id` (integer)
- **Réponses** :
    - **200 OK** :
      ```json
      [ { "id":1, "name":"BAES 1", "position":{"x":100, "y":200}, "etage_id":1 } ]
      ```
    - **404 Not Found**
    - **500 Internal Server Error**

---

### 5. Assignation de carte

#### POST `/etages/carte/{etage_id}/assign`

- **Utilité** : Assigne une carte existante à un étage.
- **Paramètres** :
    - **Path** : `etage_id` (integer)
    - **Body** (application/json) : `{ "card_id":3 }`
- **Réponses** :
    - **200 OK** : `{ "message":"Carte assignée à l'étage avec succès." }`
    - **400 Bad Request**, **404 Not Found**, **500 Internal Server Error**

#### POST `/sites/carte/{site_id}/assign`

- **Utilité** : Assigne une carte existante à un site.
- **Paramètres** :
    - **Path** : `site_id` (integer)
    - **Body** (application/json) : `{ "card_id":5 }`
- **Réponses** :
    - **200 OK** : `{ "message":"Carte assignée au site avec succès." }`
    - **400 Bad Request**, **404 Not Found**, **500 Internal Server Error**

---

### 6. Données générales

#### GET `/general/user/{user_id}/alldata`

- **Utilité** : Retourne tous les sites, bâtiments, étages, BAES et historiques d'erreurs pour un utilisateur.
- **Paramètres** :
    - **Path** : `user_id` (integer)
- **Réponses** :
    - **200 OK** : Structure imbriquée JSON détaillant les sites, bâtiments, étages, BAES et erreurs.
    - **404 Not Found**

---

### 7. Rôles

#### POST `/roles/`

- **Utilité** : Crée un rôle.
- **Paramètres** :
    - **Body** (application/json) : `{ "name":"admin" }`
- **Réponses** :
    - **201 Created** : `{ "message":"Rôle créé","role":{ "id":1, "name":"admin" } }`
    - **400 Bad Request**

#### DELETE `/roles/{id}`

- **Utilité** : Supprime un rôle.
- **Paramètres** :
    - **Path** : `id` (integer)
- **Réponses** :
    - **200 OK**
    - **404 Not Found**

---

### 8. Site CRUD

#### GET `/sites/`

- **Utilité** : Récupère la liste de tous les sites.
- **Paramètres** : aucun.
- **Réponses** :
    - **200 OK** :
      ```json
      [ { "id":1, "name":"Site 1" } ]
      ```
    - **500 Internal Server Error**

#### POST `/sites/`

- **Utilité** : Crée un nouveau site.
- **Paramètres** :
    - **Body** (application/json) : `{ "name":"Site 1" }`
- **Réponses** :
    - **201 Created** : `{ "id":1, "name":"Site 1" }`
    - **400 Bad Request**

#### GET `/sites/{site_id}`

- **Utilité** : Récupère un site par son ID.
- **Paramètres** :
    - **Path** : `site_id` (integer)
- **Réponses** :
    - **200 OK** : `{ "id":1, "name":"Site 1" }`
    - **404 Not Found**

#### PUT `/sites/{site_id}`

- **Utilité** : Met à jour un site existant.
- **Paramètres** :
    - **Path** : `site_id` (integer)
    - **Body** (application/json) : `{ "name":"Site mis à jour" }`
- **Réponses** :
    - **200 OK** : `{ "id":1, "name":"Site mis à jour" }`
    - **404 Not Found**

#### DELETE `/sites/{site_id}`

- **Utilité** : Supprime un site par son ID.
- **Paramètres** :
    - **Path** : `site_id` (integer)
- **Réponses** :
    - **200 OK** : `{ "message":"Site supprimé avec succès" }`
    - **404 Not Found**

---

### 9. Association Utilisateur-Site-Rôle

#### POST `/user_site_role/`

- **Utilité** : Crée l'association utilisateur–site–rôle.
- **Paramètres** :
    - **Body** (application/json) : `{ "user_id":1, "site_id":2, "role_id":3 }`
- **Réponses** :
    - **201 Created** : `{ "association":{...}, "message":"Association créée avec succès." }`
    - **400 Bad Request**, **404 Not Found**

#### GET `/user_site_role/user/{user_id}`

- **Utilité** : Liste des sites et rôles d'un utilisateur.
- **Paramètres** :
    - **Path** : `user_id` (integer)
- **Réponses** :
    - **200 OK** : `[ { "site_id":2, "site_name":"Site A", "roles":[{ "role_id":3, "role_name":"admin" }] } ]`
    - **404 Not Found**

#### GET `/user_site_role/{user_id}/{site_id}`

- **Utilité** : Récupère toutes les associations pour un utilisateur sur un site.
- **Paramètres** :
    - **Path** : `user_id`, `site_id` (integer)
- **Réponses** :
    - **200 OK** : `[ { "user_id":1, "site_id":2, "role_id":3 } ]`
    - **404 Not Found**

#### DELETE `/user_site_role/{user_id}/{site_id}/{role_id}`

- **Utilité** : Supprime une association spécifique.
- **Paramètres** :
    - **Path** : `user_id`, `site_id`, `role_id` (integer)
- **Réponses** :
    - **200 OK** : `{ "message":"Association supprimée avec succès." }`
    - **404 Not Found**

---

### 10. Utilisateurs CRUD

#### GET `/users/`

- **Utilité** : Récupère tous les utilisateurs avec leurs sites et rôles.
- **Paramètres** : aucun.
- **Réponses** :
    - **200 OK** :
      ```json
      [ { "id":1, "login":"user1", "roles":["admin","user"], "sites":[{"id":3,"name":"Site test 1"},...] } ]
      ```
    - **500 Internal Server Error**

#### POST `/users/`

- **Utilité** : Crée un nouvel utilisateur (et associe rôles/sites).
- **Paramètres** :
    - **Body** (application/json) :
      ```json
      { "login":"nouveluser", "password":"motdepasse", "roles":["admin","user"], "sites":[3,4] }
      ````
- **Réponses** :
    - **201 Created** :
      ```json
      { "id":1, "login":"nouveluser", "roles":["admin","user"], "sites":[{"id":3,"name":"Site test 1"}] }
      ```
    - **400 Bad Request**

#### GET `/users/{user_id}`

- **Utilité** : Récupère un utilisateur par son ID (avec sites et rôles).
- **Paramètres** :
    - **Path** : `user_id` (integer)
- **Réponses** :
    - **200 OK** :
      ```json
      { "id":1, "login":"user1", "roles":["..."], "sites":[{"id":3,"name":"Site test 1"}] }
      ```
    - **404 Not Found**, **500 Internal Server Error**

#### PUT `/users/{user_id}`

- **Utilité** : Met à jour un utilisateur existant.
- **Paramètres** :
    - **Path** : `user_id` (integer)
    - **Body** (application/json) :
      ```json
      { "login":"updateduser", "password":"updatedpassword", "roles":["admin"] }
      ```
- **Réponses** :
    - **200 OK** : `{ "id":1, "login":"updateduser", "roles":["admin"] }`
    - **404 Not Found**, **500 Internal Server Error**

#### DELETE `/users/{user_id}`

- **Utilité** : Supprime un utilisateur par son ID.
- **Paramètres** :
    - **Path** : `user_id` (integer)
- **Réponses** :
    - **200 OK** : `{ "message":"Utilisateur supprimé avec succès" }`
    - **404 Not Found**, **500 Internal Server Error**

---

### 11. Relations Utilisateur–Sites

#### GET `/users/sites/{user_id}/sites`

- **Utilité** : Liste des sites associés à un utilisateur.
- **Paramètres** :
    - **Path** : `user_id` (integer)
- **Réponses** :
    - **200 OK** : `[ { "id":1, "name":"Site 1" } ]`
    - **404 Not Found**, **500 Internal Server Error**

#### POST `/users/sites/{user_id}/sites`

- **Utilité** : Associe un site à un utilisateur.
- **Paramètres** :
    - **Path** : `user_id` (integer)
    - **Body** (application/json) : `{ "site_id":1 }`
- **Réponses** :
    - **200 OK** : `{ "message":"Site ajouté à l'utilisateur." }`
    - **404 Not Found**, **500 Internal Server Error**

#### DELETE `/users/sites/{user_id}/sites/{site_id}`

- **Utilité** : Dissocie un site d'un utilisateur.
- **Paramètres** :
    - **Path** : `user_id`, `site_id` (integer)
- **Réponses** :
    - **200 OK** : `{ "message":"Site dissocié de l'utilisateur." }`
    - **404 Not Found**, **500 Internal Server Error**

---

**Fin du document**

