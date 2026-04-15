# WalkieTalkie - Design Spec

## Concept

App iOS de talkie-walkie avec messages vocaux asynchrones ephemeres. Les utilisateurs creent ou rejoignent des "frequences" (canaux de groupe) via un code partage, envoient des vocaux de 20 secondes max avec un effet de gresillement radio, et les messages s'auto-detruisent apres ecoute ou apres 10 minutes.

## Principes directeurs

- **Ephemere** : les messages ne persistent pas, comme une vraie communication radio
- **Zero friction** : pas de login, pas de compte, un pseudo et c'est parti
- **Minimaliste** : peu d'ecrans, peu de features, une seule chose bien faite
- **Zero serveur** : tout repose sur CloudKit, aucun cout d'infra
- **Authentique** : le gresillement, le bip "roger", le push-to-talk recreenent l'experience talkie-walkie

---

## 1. Modele de donnees CloudKit

Tous les records sont dans la **public database** CloudKit.

### Frequency (canal)

| Champ | Type | Description |
|-------|------|-------------|
| `name` | String | Nom de la frequence ("Les potes", "Bureau") |
| `code` | String | Code unique a partager (ex: "XKCD-4782") |
| `creatorID` | String | UUID de l'utilisateur qui a cree la frequence |
| `createdAt` | Date | Date de creation |

### FrequencyMember

| Champ | Type | Description |
|-------|------|-------------|
| `frequencyRef` | Reference → Frequency | La frequence |
| `userID` | String | UUID de l'utilisateur |
| `joinedAt` | Date | Date d'arrivee |
| `displayName` | String | Pseudo affiche |

### VoiceMessage

| Champ | Type | Description |
|-------|------|-------------|
| `frequencyRef` | Reference → Frequency | La frequence cible |
| `senderID` | String | UUID de l'expediteur |
| `senderName` | String | Pseudo de l'expediteur |
| `audio` | CKAsset | Le fichier audio (AAC, filtre gresillement deja applique) |
| `duration` | Double | Duree en secondes |
| `createdAt` | Date | Timestamp d'envoi |
| `expiresAt` | Date | createdAt + 10 min |

Pas de champ "lu/pas lu" dans CloudKit : chaque client gere ca localement.

---

## 2. Architecture audio

### Pipeline d'enregistrement

```
Micro → AVAudioEngine → Fichier AAC → Upload CloudKit
```

Chaine de traitement du gresillement via AVAudioEngine :

| Noeud AVAudioEngine | Role | Parametres cles |
|---------------------|------|-----------------|
| `inputNode` | Capture micro | Format natif du device |
| EQ (passe-bande) | Coupe graves et aigus, son "radio" | 300 Hz - 3000 Hz |
| Distortion | Ajoute du craquement | Preset leger type "radio" |
| Mixer (bruit blanc) | Bruit de fond statique faible | Volume ~5-10% du signal |
| `outputNode` → fichier | Ecriture en AAC compresse | 22050 Hz, mono, 32 kbps |

### Format de sortie

- AAC mono, 22050 Hz, ~32 kbps
- 20 sec max = ~80 Ko par message
- Qualite suffisante pour de la voix "gresillante"

### Deroulement push-to-talk

1. User appuie sur le bouton → `AVAudioEngine.start()`, debut enregistrement
2. Compteur de 20s demarre (progress bar circulaire visuelle)
3. User relache (ou 20s atteint) → `AVAudioEngine.stop()`
4. Son "roger" (bip) joue via `AVAudioPlayer` (fichier local `roger.caf`)
5. Fichier AAC envoye a CloudKit en background

### Lecture

- `AVAudioPlayer` standard, aucun traitement — le fichier est deja filtre
- Lecture une seule fois, puis suppression locale

---

## 3. Ecrans et navigation

4 ecrans, navigation simple via NavigationStack.

```
Mes frequences (NavigationStack)
├── → Frequence (detail, push)
├── → Rejoindre (sheet)
└── → Creer (sheet)
```

### Ecran 1 - Mes frequences (Home)

- Liste des frequences rejointes
- Chaque ligne : nom, nombre de membres, pastille orange si message(s) non ecoute(s)
- Bouton "+" pour creer une frequence
- Bouton "Rejoindre" pour entrer un code
- Au tout premier lancement : ecran de choix de pseudo (avant d'arriver ici)

### Ecran 2 - Frequence (ecran principal)

- **En haut** : nom de la frequence, nombre de membres, bouton partager le code
- **Au centre** : liste des vocaux recus non ecoutes
  - Pseudo de l'expediteur
  - Duree du message
  - Countdown avant expiration
  - Tap pour ecouter (une seule fois, puis disparait avec animation)
- **En bas** : gros bouton push-to-talk rond central
  - Maintenir = enregistrer
  - Progress bar circulaire autour du bouton (20s max)
  - Relacher = bip roger + envoi

### Ecran 3 - Rejoindre une frequence (sheet)

- Champ de saisie du code (ex: "XKCD-4782")
- Choix du pseudo pour cette frequence
- Bouton "Rejoindre"

### Ecran 4 - Creer une frequence (sheet)

- Champ nom de la frequence
- Code genere automatiquement (affiche, copiable)
- Bouton "Creer" → redirige vers ecran Frequence avec le code a partager

---

## 4. Notifications et sync

### Abonnements CloudKit

Quand un user rejoint une frequence, l'app cree un `CKQuerySubscription` :

```
"VoiceMessage WHERE frequencyRef == [cette frequence]"
```

CloudKit envoie une push silencieuse a tous les abonnes a la creation d'un nouveau record.

### Flux de reception

1. Push silencieuse recue (`application(_:didReceiveRemoteNotification:)`)
2. Fetch du nouveau `VoiceMessage` via `CKFetchRecordChangesOperation`
3. Telechargement du `CKAsset` (fichier audio)
4. Stockage local (dossier temporaire)
5. Notification locale visible : "Nouveau message sur [frequence] de [pseudo]"
6. Demarrage du timer d'expiration local (10 min)

### Cas limites

| Situation | Comportement |
|-----------|-------------|
| App ouverte, sur la bonne frequence | Vocal apparait dans la liste avec animation |
| App ouverte, autre ecran | Badge sur la frequence + notif locale |
| App en background | Push silencieuse → fetch → notif locale |
| App killed / pas lancee | Push silencieuse reveille l'app (30s runtime pour fetch) |
| Pas de connexion | Sync des messages non expires au prochain lancement |
| Message deja expire a la reception | Ignore, pas affiche |

### Desabonnement

Quand un user quitte une frequence, suppression du `CKQuerySubscription` correspondant.

---

## 5. Expiration et cleanup des messages

### Logique d'expiration

- Un message a une duree de vie de 10 minutes apres envoi (`expiresAt = createdAt + 10 min`)
- Apres ecoute (une seule ecoute autorisee), le recepteur supprime sa copie locale
- Si pas ecoute et `expiresAt < now`, le recepteur supprime sa copie locale sans la jouer

### Suppression du record CloudKit

L'expediteur est responsable de la suppression dans CloudKit :

1. A l'envoi, l'expediteur planifie une suppression a `expiresAt` via `Timer` ou `BGTaskScheduler`
2. Quand le timer se declenche, l'app supprime le `CKRecord` (le `CKAsset` est supprime automatiquement avec)
3. Si l'app n'est pas ouverte au moment de l'expiration, la suppression se fait au prochain lancement : verification de tous les messages envoyes dont `expiresAt < now`

### Compromis connu

Si l'expediteur n'ouvre jamais son app, les vieux messages restent dans CloudKit. Impact negligeable : ~80 Ko par message, quota de 10 Go.

---

## 6. Identite

- **Pas de login** : aucun ecran d'authentification
- UUID genere au premier lancement, stocke dans le **Keychain** iOS (persiste meme si l'app est desinstallee/reinstallee)
- L'utilisateur choisit un pseudo au premier lancement
- CloudKit fonctionne avec le compte iCloud du device (invisible pour l'utilisateur, actif sur 99% des iPhones)
- Si iCloud est desactive, l'app affiche un message demandant de l'activer

---

## 7. Securite et permissions

### Permissions iOS

| Permission | Moment de la demande | Justification |
|------------|---------------------|---------------|
| Microphone | Premier push-to-talk | "Pour enregistrer vos messages vocaux" |
| Notifications push | Apres avoir rejoint la 1ere frequence | "Pour vous prevenir des nouveaux messages" |

Seulement 2 permissions. Pas de carnet de contacts, pas de localisation.

### Securite des frequences

- Le code de frequence est le seul secret pour rejoindre
- Pas de mot de passe supplementaire (v1 simple)
- Le createur peut voir la liste des membres
- Les fichiers audio dans CloudKit sont dans la public database, proteges par la logique applicative

### Donnees personnelles

- Aucun email stocke
- Pseudo choisi par l'utilisateur
- Messages ephemeres par design
- Aucun tracking, aucune revente de donnees

---

## 8. Stack technique

| Couche | Techno |
|--------|--------|
| UI | SwiftUI (iOS 17+) |
| Navigation | NavigationStack |
| Donnees locales | SwiftData (metadonnees, statut ecoute, timers expiration) |
| Identite | UUID Keychain + pseudo |
| Backend | CloudKit (public database) |
| Stockage audio | CKAsset (AAC mono, ~80 Ko/message) |
| Notifications | CKQuerySubscription → push silencieuse → notif locale |
| Audio capture | AVAudioEngine (pipeline filtre gresillement) |
| Audio playback | AVAudioPlayer |
| Son roger | Fichier .caf local |
| Expiration | Timer local + cleanup au lancement |
| Minimum iOS | 17.0 |
| Architecture | MVVM simple, monolithique |

**Dependances externes : aucune.** Tout est natif Apple.

---

## 9. Hors scope (v1)

- Version Android
- Expulsion de membres d'une frequence
- Mot de passe sur une frequence
- Messages texte
- Historique des messages (ephemere = pas d'historique)
- Mode temps reel / live
- Personalisation du son de gresillement
- Backend serveur pour le cleanup
