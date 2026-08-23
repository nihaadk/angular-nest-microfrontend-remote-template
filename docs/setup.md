# Was `setup.sh` macht — Schritt für Schritt

`setup.sh` konfiguriert einen frisch geklonten `remote-template`-Ordner
**in place** — es kopiert nichts irgendwohin, es passt die Dateien an, in
denen es liegt. Gedacht für genau einen Lauf, direkt nach `git clone`.

```bash
./setup.sh <name> [fe-port] [be-port]
```

## Schritt 1 — Eingaben prüfen

- `<name>` ist Pflicht (z. B. `orders`). Muss kebab-case sein (`a-z`, `0-9`,
  `-`) — wird per Regex geprüft, bei Verstoß bricht das Script sofort ab.
- `[fe-port]` / `[be-port]` sind optional, Default `4202` / `3002`. Werden
  ebenfalls per Regex auf "nur Ziffern" geprüft.
- Danach wird geprüft, ob `fe/` und `be/` überhaupt neben dem Script
  liegen — falls nicht (z. B. Script wurde woandershin kopiert), bricht es
  mit einer klaren Fehlermeldung ab, statt später mitten in den
  Ersetzungen zu scheitern.

## Schritt 2 — Anzeigename berechnen

Aus `orders` wird `Orders`, aus `user-profile` wird `User Profile`. Das
passiert über `awk`, **nicht** über `sed`s `\U` oder Bashs `${x^}` — beide
funktionieren auf macOS nicht zuverlässig, weil macOS standardmäßig ein
sehr altes `bash` (3.2) und BSD-`sed` mitbringt, die diese
Groß-/Kleinschreibungs-Syntax nicht unterstützen. `awk` ist auf jedem
System gleich.

## Schritt 3 — Portables `sed -i`

Eine kleine Helper-Funktion `sedi()`, die erkennt, ob GNU-`sed` (Linux) oder
BSD-`sed` (macOS) läuft — beide brauchen für "Datei direkt bearbeiten"
(`-i`) eine leicht unterschiedliche Syntax. Ohne das würde das Script auf
einem der beiden Systeme mit einer kryptischen Fehlermeldung abbrechen.

## Schritt 4 — Die eigentlichen Textersetzungen

Ab hier passiert die eigentliche Umbenennung, Datei für Datei:

| Datei | Was ersetzt wird |
|---|---|
| `fe/federation.config.mjs` | `name: 'remote-template'` → `name: '<name>'` — der **Native-Federation-Name**, unter dem dieses Remote sich selbst registriert |
| `fe/angular.json` | `"port": 4201` → `"port": <fe-port>` — der `ng serve`-Port |
| `fe/public/env.json` | `http://localhost:3001` → `http://localhost:<be-port>` — wohin das FE lokal nach seinem Backend sucht |
| `fe/src/app/app.html`, `fe/src/app/app.spec.ts` | `Remote Template` → Anzeigename aus Schritt 2 |
| `fe/src/index.html` | `<title>Fe</title>` → `<title><Anzeigename></title>` |
| `fe/package.json` | `"name": "fe"` → `"name": "<name>-fe"` |
| `be/package.json` | `"name": "be"` → `"name": "<name>-be"` |
| `be/src/main.ts` | Standard-Port `3001` → `<be-port>`; CORS-Origin `http://localhost:4201` → `http://localhost:<fe-port>` |
| `be/.env.example` | dieselben zwei Werte wie in `main.ts`, für die lokale `.env`-Vorlage |

**Wichtig:** `federation.config.mjs`s `name`-Feld ist die einzige Stelle,
die für die spätere Einbindung in eine Host-Shell wirklich zählt — Native
Federation registriert ein Remote unter **seinem eigenen** deklarierten
Namen, nicht unter dem Key, den die Shell in ihrem Manifest benutzt. Wenn
beide nicht exakt übereinstimmen, lädt die Shell das Remote nicht (Fehler:
`Remote 'x' is not initialized`) — das haben wir in diesem Projekt schon
zweimal live debuggt.

## Schritt 5 — Git-Historie zurücksetzen

```bash
rm -rf .git
git init -q
git add -A
git commit -q -m "Initial commit: <name> (from remote-template)"
```

Der geklonte Ordner hatte bis hierhin noch die komplette Commit-Historie
von `remote-template` selbst. Die wird bewusst verworfen — ein neues
Remote soll mit einer eigenen, sauberen Historie starten, nicht mit der
Entwicklungsgeschichte der Vorlage.

## Schritt 6 — Abschlussmeldung

Druckt:
- die nächsten Befehle (`npm install && npm start` für `fe`/`be`)
- den Hinweis, dass `setup.sh` jetzt gelöscht werden kann (macht es nicht
  automatisch — das bleibt eure Entscheidung)
- den Hinweis auf `railway-deploy.sh` als nächsten Schritt
- die drei Schritte, um das neue Remote in eine Host-Shell einzubinden
  (Manifest-Eintrag, Route, Nav-Eintrag), inklusive der Warnung aus
  Schritt 4 zum `name`-Feld

## Was `setup.sh` **nicht** macht

- Kein `npm install` — bewusst nicht automatisch, damit ihr seht, was
  passiert, und weil `fe`/`be` unabhängige Projekte mit eigenen
  `node_modules` sind.
- Kein Deploy, keine Railway-Interaktion — dafür ist
  [`railway-deploy.sh`](railway-deploy.md) da.
- Kein Push zu GitHub — der frische lokale Commit aus Schritt 5 hat
  absichtlich kein `origin`, das bleibt euch überlassen.
