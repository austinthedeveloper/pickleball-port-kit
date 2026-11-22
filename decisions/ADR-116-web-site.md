# ADR-116 — The Web Build's Site

Status: **Accepted 2026-11-21** (asked for by the user: "has this been
deployed to azure in a while? I can't remember if we set up a pipeline
for the web version", then "yes set it up").
Milestone: `PORT-173`.
Builds on: ADR-089 (the lite Web build), the relay's Azure setup
(design/RELAY.md).

## Context

Every release since v0.2.1 has had a Web build, but only as
`Pickleball94-X.Y.Z-web.zip` on the GitHub release: nothing served it,
so playing it meant unzipping it and running a local web server. The
only thing on Azure was the relay. The lite build (ADR-089) still holds:
the Web zip is 21 MB from v0.35.0 to v0.44.0.

## Decision

**An Azure Static Web App, free plan, updated by each release.**

- **The site** (`infra/web/main.bicep`): `pickleball94` in the resource
  group `pickleball-web`, East US 2 (Static Web Apps' nearest region to
  the relay). The free plan allows 250 MB per app and 100 GB of
  traffic a month: unzipped, a first load is about 52 MB (the 40 MB
  engine and the 12 MB pack), so around 1,900 new players a month
  before it would matter.
- **No cross-origin isolation needed:** the Web preset exports without
  threads, so the page needs no COOP/COEP headers.
  `infra/web/staticwebapp.config.json` gives `.pck` and `.wasm` their
  types and `Cache-Control: no-cache`, because every release keeps the
  same file names (`index.pck`), so a browser must revalidate them.
- **Deploying** (`.github/workflows/web.yml`): release.yml calls it
  after the builds are published. It downloads that tag's web zip from
  the release (the bytes players download, not a second export), adds
  the config, deploys main.bicep, reads the site's deployment token,
  uploads, and checks that the served `index.pck` matches the zip's.
  Run by hand, it puts up any release again (empty tag: the latest),
  which is also the way to roll back.
- **Signing in:** GitHub's OIDC, as with the relay, through its own app
  registration (`pickleball-web-deploy`, Contributor on `pickleball-web`
  only). Its federated credential names the repo's `web` environment,
  not a ref, so tag pushes and a manual run from main share it; the
  environment only allows tags `v*` and `main`. The deployment token is
  read at run time and masked; no secret is stored in GitHub.
- **One-time setup** (`infra/web/setup.sh`, like the relay's): the
  provider, the resource group and site, the app registration, a $5
  budget with email alerts (deployed from the Mac so the address stays
  out of the public logs), the environment, and the AZURE_* repo
  variables. Until those variables exist, the `web` job is skipped, so
  releases work as before. Run 2026-11-21: the site is
  https://happy-tree-06dcdd90f.4.azurestaticapps.net.

## Consequences

- The site always shows the latest release, not `main`; testing an
  unreleased branch on the web is still a local export.
- The in-game updater (ADR-057) doesn't apply to the Web build: a reload
  gets the new release.
- Not done: a custom domain (free on this plan, needs DNS), Brotli
  pre-compression of `index.wasm` (the zip's 40 MB engine is most of a
  first load; ADR-089's smaller engine template is still open), and a
  staging slot per pull request.
