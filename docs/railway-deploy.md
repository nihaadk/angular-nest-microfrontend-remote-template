# Was `railway-deploy.sh` macht — Schritt für Schritt

`railway-deploy.sh` deployt das aktuelle `fe/`/`be/` auf Railway. Läuft nach
`setup.sh`, ist im Gegensatz dazu **beliebig oft wiederholbar** (redeployt
einfach neu, statt zu scheitern, wenn schon etwas existiert).

```bash
./railway-deploy.sh [shell-fe-url]
```

## Schritt 1 — Vorab-Prüfungen

- Ist `railway` (CLI) installiert?
- Ist `python3` installiert? (wird gebraucht, um die JSON-Antworten der
  Railway-CLI auszuwerten — die CLI selbst hat kein eingebautes
  JSON-Query-Tool)
- Ist man bei Railway eingeloggt? (`railway whoami`)
- Liegen `fe/` und `be/` überhaupt neben dem Script?

Jede dieser Prüfungen bricht mit einer klaren Fehlermeldung ab, statt
mitten im Deploy mit einem kryptischen Fehler zu scheitern.

## Schritt 2 — Federation-Namen lesen

```bash
FEDERATION_NAME="$(sed -n "s/.*name: '\([^']*\)'.*/\1/p" fe/federation.config.mjs | head -1)"
```

Liest den `name`, den `setup.sh` in Schritt 4 gesetzt hat. Wird erst ganz
am Ende gebraucht (für die `REMOTES_JSON`-Zeile) — hat aber **nichts** mit
den Railway-Servicenamen zu tun, die kommen aus Schritt 4 weiter unten.
Zwei komplett unabhängige Namensräume:

| Name | Wofür | Herkunft |
|---|---|---|
| Federation-Name (`remote-2`) | wie sich das Remote bei Native Federation selbst registriert | `federation.config.mjs`, von `setup.sh` gesetzt |
| App-Name (`REMOTE-2`) | Präfix der beiden Railway-Servicenamen (`REMOTE-2-FE`/`-BE`) | wird in diesem Script interaktiv abgefragt |

Die beiden müssen nicht gleich lauten (auch wenn es in der Praxis oft
naheliegt, denselben Namen für beides zu verwenden).

## Schritt 3 — Railway-Projekte auflisten

```bash
railway list --json
```

Holt **alle** Railway-Projekte des Accounts (inkl. bereits gelöschter —
die werden per `deletedAt`-Feld rausgefiltert). Aus der Antwort wird eine
nummerierte Liste gebaut:

```
Available Railway projects:
  1) MicroFrontend-Angular-NestJS
  n) Create a new project
```

**Technisches Detail:** Die Liste wird über eine `while read`-Schleife in
ein Bash-Array eingelesen, nicht über `mapfile`/`readarray` — aus demselben
Grund wie in `setup.sh`: macOS' Standard-`bash` ist Version 3.2, `mapfile`
gibt es erst ab 4.0.

## Schritt 4 — Projekt auswählen (interaktiv, Prompt 1)

Eingabe: eine Nummer aus der Liste, oder `n` (bzw. irgendwas anderes) für
"neu anlegen".

- **Nummer gewählt:** `PROJECT_NAME` wird aus der Liste übernommen,
  `CREATE_PROJECT=false`.
- **Neu:** fragt nach einem Namen, `CREATE_PROJECT=true`. Leerer Name →
  Abbruch mit Fehler.

## Schritt 5 — App-Namen abfragen (interaktiv, Prompt 2)

```
App name (services will be named <name>-FE / <name>-BE):
```

Unabhängig vom Projekt — wichtig, weil ein *bestehendes* Projekt schon
andere Apps enthalten kann (z. B. eine Host-Shell mit `FE-SHELL`/`BE-SHELL`).
Aus der Eingabe werden `FE_SERVICE`/`BE_SERVICE` gebaut, z. B. `REMOTE-2` →
`REMOTE-2-FE` / `REMOTE-2-BE` (Groß-/Kleinschreibung wird 1:1 übernommen).

## Schritt 6 — Projekt auflösen oder anlegen

- **Bestehendes Projekt:** `PROJECT_ID`/`ENVIRONMENT_ID` werden aus der in
  Schritt 3 schon geladenen Liste rausgesucht (kein erneuter API-Call
  nötig).
- **Neues Projekt:**
  ```bash
  cd be && railway up --new -y --name "$PROJECT_NAME" --service "$BE_SERVICE"
  ```
  `railway up` lädt den **aktuellen Ordner** direkt bei Railway hoch und
  baut ihn dort — kein GitHub-Repo, kein Push nötig. `--new` legt dabei in
  einem Rutsch ein neues Projekt **und** den ersten Service an und deployt
  ihn auch gleich. Danach wird `railway list --json` erneut geholt, um die
  frisch vergebene `PROJECT_ID`/`ENVIRONMENT_ID` rauszulesen.

## Schritt 7 — Einmal linken

```bash
railway link --project "$PROJECT_ID" --environment "$ENVIRONMENT_ID"
```

**Wichtiger Grund, warum das hier steht:** `railway add` (Schritt 8, zum
Anlegen eines Service) hat — anders als `up`, `domain` und `variable set`
— **kein** `--project`/`--environment`-Flag. Es wirkt immer nur auf das,
was im aktuellen Verzeichnis gerade "gelinkt" ist. Ohne diesen Schritt
würde `railway add` mit `unexpected argument '--project' found`
fehlschlagen (live so passiert und gefixt).

## Schritt 8 — Beide Services sicherstellen und deployen

Für `BE_SERVICE` und dann `FE_SERVICE`, jeweils über `deploy_service()`:

1. `service_exists()` prüft per `railway status --json`, ob der
   Servicename im Projekt schon existiert.
2. Falls nicht: `railway add --service <name>` legt einen leeren Service
   an (ohne Quelle — kein Git, kein Image).
3. `cd <fe-oder-be-ordner> && railway up -y --service <name> --project ... --environment ...`
   lädt den Ordnerinhalt hoch und deployt ihn.

**Bekannter Stolperstein:** `railway up` **ohne** einen abschließenden
`.`-Pfad aufrufen. Ein explizites `.` am Ende lässt genau diesen Aufruf mit
`prefix not found` fehlschlagen (ein CLI-Bug/-Eigenheit) — ohne `.`
(Pfad-Default = aktuelles Verzeichnis) funktioniert es. Das war besonders
tückisch, weil das Script mit `set -e` läuft: Der BE-Service wurde
"erfolgreich" angelegt, aber nie deployt, und das Script brach ab, *bevor*
FE überhaupt drankam — Symptom war ein Service, der existiert, aber
"offline" ist (null Deployments).

**Zweiter Stolperstein (bisher nicht zuverlässig automatisiert lösbar):**
Wenn ein bereits bestehender `railway up`-Service später über die
Railway-API (`serviceInstanceUpdate`, z. B. um `dockerfilePath` zu
korrigieren) angefasst wird, kann er in einen Zustand geraten, in dem jeder
weitere `railway up` mit `failed to read Dockerfile at '<pfad>'`
fehlschlägt — und zwar dauerhaft, auch nachdem man die Felder per API
wieder zurücksetzt. Der einzige bisher zuverlässige Fix: den Service über
`railway service delete` komplett löschen und über `railway add` + `railway up`
sauber neu aufbauen, **ohne** die API-Felder manuell anzufassen.

## Schritt 9 — Domains erzeugen

```bash
railway domain --service <name> --project ... --environment ...
```

Für beide Services, aber **ohne** `--port`. Ein explizit gesetzter
Ziel-Port hat bei diesem Projekt schon zweimal dazu geführt, dass Railways
Routing nicht mehr funktioniert hat (502 "Application failed to respond"),
obwohl der Service selbst lief. Ohne `--port` erkennt Railway den
tatsächlich lauschenden Port automatisch — das hat zuverlässig
funktioniert. `ensure_domain()` prüft vorher per `railway domain list`, ob
schon eine Domain existiert, und erzeugt nur dann eine neue, wenn nicht
(macht das Script wiederholbar, ohne Domain-Dubletten anzuhäufen).

## Schritt 10 — Variablen setzen

```bash
BE_URL=https://<be-domain>            # auf FE_SERVICE
CORS_ORIGINS=https://<fe-domain>[,<shell-fe-url>]   # auf BE_SERVICE
```

- `BE_URL` sagt dem Frontend zur Laufzeit, wo sein Backend liegt (gelesen
  via `env.json`, siehe `fe/docker-entrypoint.sh`).
- `CORS_ORIGINS` erlaubt Anfragen von der eigenen Frontend-Domain — und,
  falls als Argument übergeben, zusätzlich von der Shell-Domain. Das ist
  nötig, weil die exponierte Komponente, sobald sie in eine Shell
  eingebettet ist, dort im Seiten-Kontext der Shell läuft — ihre
  `fetch()`-Aufrufe tragen dann die Origin der Shell, nicht die eigene.

Beide `railway variable set`-Aufrufe lösen automatisch einen Redeploy aus.

## Schritt 11 — Abschlussmeldung

Druckt beide öffentlichen URLs und die fertige Zeile für die
`REMOTES_JSON`-Variable der Host-Shell:

```json
{"<federation-name>":"https://<fe-domain>"}
```

(Nur die Basis-URL — die Shell hängt `/remoteEntry.json` selbst an, siehe
`shell/be/src/remotes/remotes.service.ts`.)

Falls keine `shell-fe-url` übergeben wurde, gibt es zusätzlich den
Hinweis, das Script später erneut mit der Shell-URL als Argument
auszuführen.

## Wichtige Fallstricke beim erneuten Ausführen

- **Immer im richtigen Ordner sein.** Das Script liegt sowohl in
  `remote-template/` (dessen `federation.config.mjs` nie umbenannt ist)
  als auch in jedem daraus per `setup.sh` konfigurierten Remote. Wird es
  aus dem falschen Ordner gestartet, deployt es unter dem *richtigen*
  Servicenamen den *falschen* (unveränderten Template-) Code — ohne
  Fehlermeldung, weil aus Railway-Sicht alles normal aussieht. Genau das
  ist uns einmal live passiert. Vor dem Ausführen: `pwd` prüfen.
- Bei Prompt 1 denselben Projektnamen und bei Prompt 2 denselben App-Namen
  wählen wie beim letzten Mal, um denselben Service zu treffen statt einen
  neuen danebenzustellen.
