# Remote Template

A starter template for building a new **remote** microfrontend for a Native
Federation host shell: an Angular 22 + daisyUI frontend and a NestJS backend,
already wired together, ready to be renamed and developed.

Clone it, run one script, start coding.

## What's inside

**Frontend (`fe/`)**
- Angular 22, standalone components, signals
- daisyUI 5 + Tailwind CSS 4 pre-configured
- Native Federation pre-configured as a **remote**: exposes a `./Component`
  entry point (`src/app/app.ts`) that a host shell can load at runtime via
  `loadRemoteModule('<name>', './Component')`
- An `ExampleService` (using `httpResource`) that calls the backend and
  renders the result in a daisyUI card with loading/error states

**Backend (`be/`)**
- NestJS 11
- CORS and a global `/api` prefix pre-configured
- A `GET /api/example` endpoint the frontend already consumes

## Quickstart

```bash
git clone <this-repo-url> my-remote
cd my-remote
./setup.sh my-remote 4202 3002
```

- `my-remote` — kebab-case name for your remote. This becomes the Native
  Federation remote name, the manifest key / URL path a host mounts it
  under, and part of the npm package names.
- `4202` — optional, dev-server port for `fe` (default `4202`)
- `3002` — optional, port for `be` (default `3002`)

Pick ports that don't collide with the host shell (`4200`/`3000` by default)
or with any other remote you're already running.

`setup.sh` will:
- Set the Native Federation remote name in `fe/federation.config.mjs`
- Set the dev-server port in `fe/angular.json`
- Point `fe`'s example service at the right backend port
- Rename on-page titles/text and the npm package names
- Set the backend's port and CORS origin in `be/src/main.ts`
- Reset git history to a single fresh commit, so you're not carrying this
  template's own commit history into your new remote

You can delete `setup.sh` afterwards — it's a one-time bootstrap step.

Then start both apps:

```bash
cd fe && npm install && npm start   # http://localhost:4202
cd be && npm install && npm start   # http://localhost:3002
```

## Wiring it into a host shell

To make a host actually load and navigate to this remote:

1. Add it to the host's remotes manifest (e.g. the `REMOTES_JSON`
   environment variable on the host's backend):
   ```json
   { "my-remote": "https://my-remote-fe.example.com/remoteEntry.json" }
   ```
2. Add a route in the host that lazy-loads it:
   ```ts
   {
     path: 'my-remote',
     loadComponent: () => loadRemoteModule('my-remote', './Component').then((m) => m.App),
   }
   ```
3. Add a nav entry pointing at that route.

> **Important:** Native Federation registers a remote under the `name` it
> declares in its own `federation.config.mjs` - **not** under whatever key
> the host's manifest happens to use to request it. `setup.sh` already keeps
> these in sync for you, so as long as you don't hand-edit `name` afterwards,
> the manifest key and route/`loadRemoteModule` calls just need to match the
> `<name>` you gave `setup.sh`.

## Deployment

```bash
./railway-deploy.sh <project> [shell-fe-url]
```

Run after `setup.sh`. `<project>` is the Railway project to deploy into -
if a project with that exact name already exists in your account it's
reused (the two services are just added to it), otherwise a new project
with that name is created. Either way, the two services are always named
`<project>-FE` and `<project>-BE`, case preserved - e.g. `<project>=REMOTE-2`
gives you `REMOTE-2-FE` and `REMOTE-2-BE`. (This naming is independent of
the remote's own Native Federation name in `federation.config.mjs` - that
one only shows up in the `REMOTES_JSON` line printed at the end.)

Deploys via `railway up` - no GitHub repo or push required - generates a
public domain for each service, and wires `BE_URL`/`CORS_ORIGINS` between
them. Safe to re-run (e.g. to redeploy after code changes, or to add
`shell-fe-url` once you know it - required for the remote to work once
embedded, since its component then runs inside the shell's page and its
`fetch()` calls carry the shell's origin, not this remote's own).

Requires the [Railway CLI](https://docs.railway.com/guides/cli), logged in
(`railway login`).

### Manual alternative

`fe` and `be` are also deployable by hand as two separate Railway services
(root directories `fe` and `be`), each with its own `Dockerfile` - the
variables to set are documented at the top of each one:

- `be`: `CORS_ORIGINS`
- `fe`: `BE_URL` (reference the `be` service directly, e.g.
  `BE_URL=https://${{be.RAILWAY_PUBLIC_DOMAIN}}`, rather than hardcoding it)

Whichever way you deploy: when generating domains, don't pass an explicit
port to Railway - let it auto-detect. An explicit target port broke
Railway's routing for this exact template (502 "Application failed to
respond") the first time it was deployed.

`fe`'s image serves the built app with [`serve`](https://github.com/vercel/serve)
and `--cors` enabled - unlike a host shell, this app's JS has to be loadable
cross-origin by whatever shell embeds it. Its entrypoint script regenerates
`env.json` from `BE_URL` on every container start, so pointing the same
image at a different backend never needs a rebuild.
