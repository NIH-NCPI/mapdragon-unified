# Deploying

Map Dragon (front end) and Locutus (back end) ship together as one image, built
from the commits pinned in the `Dockerfile`. GitHub Actions builds and deploys
it. Nothing is deployed by hand from a laptop.

There are two destinations, funded separately:

- **GCP Cloud Run**: Primarily ACR related effort as well as basic DEV and UAT.
  There are currently 3 distinct github environments: `dev`, `uat` and `alpha`.

- **ghcr.io**: Release image for deployment into AWS to support the KF and
  INCLUDE projects. These images are picked up by Terraform and deployed into
  the KF/INCLUDE security boundary. There is currently no separation between KF
  and INCLUDE, beyond the traditional environments: `dev`, `qa` and `prod`.

## The flow

| Step                      | Trigger          | Workflow                                    | What happens                                                                                              |
| ------------------------- | ---------------- | ------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| Pull request into `main`  | automatic        | CI (`ci.yml`)                               | Builds the image and checks that it starts, serves `/api/version` and the front end. Nothing is deployed. |
| Merge to `main`           | automatic        | Dev Deploy (`deploy_dev.yml`)               | Deploys `main` to **dev**, so dev always matches `main`.                                                  |
| Push a release tag (`v*`) | automatic        | UAT Deploy (`deploy_uat.yml`)               | Deploys the tagged release to **UAT** for people to try.                                                  |
| Promote to prod           | manual, approved | Prod Deploy (`deploy_prod.yaml`)            | Deploys a release tag to **prod** (`alpha`).                                                              |
| Publish for AWS           | manual           | Package Container (`package_container.yml`) | Pushes a release tag's image to `ghcr.io/carrollaboratory/<IMAGE_NAME>:<tag>`.                            |

Dev, UAT and prod all deploy through one shared workflow,
`cloud_run_deploy.yml`, so they build and configure the service the same way.

## Making a release

1. **Update the pins.** In a branch, set `MAPDRAGON_COMMIT`,
   `VITE_MAPDRAGON_VERSION` and `LOCUTUS_COMMIT` in the `Dockerfile`.
2. **Test locally.** Run `just test` (see [QUICKSTART.md](QUICKSTART.md)). If
   the Locutus commit moved, also run `just test-dump` against a recent copy of
   real data.
3. **Open a PR into `main`.** CI has to pass before merging.
4. **Merge.** Dev updates on its own. Check it.
5. **Tag the release.** Use the Map Dragon version being released, with a suffix
   such as `r2` for a re-release of the same version:

   ```bash
   git switch main && git pull
   git tag v2.4.1
   git push origin v2.4.1
   ```

   UAT updates on its own. Check it.

6. **Back up prod if the Locutus commit moved.** Dump the prod database before
   promoting (`just db-dump-remote` with `SOURCE_MONGO_URI` pointing at prod),
   in case the new release changes stored data.
7. **Promote to prod.** Go to Actions → Prod Deploy → Run workflow, choose the
   tag under "Use workflow from", then approve the run.
8. **Publish for AWS** when the collaborators are ready for it. Go to Actions →
   Package Container → Run workflow and choose the same tag.

UAT, prod and the AWS package refuse to run from a branch. They only take
release tags.

## Trying a branch on dev

Go to Actions → Dev Deploy → Run workflow and choose the branch under "Use
workflow from". Dev runs that branch until the next merge to `main` puts it
back. Dev is shared, so let the team know.

## Settings

Each deploy builds the image with two build args. Map Dragon and Locutus
versions always come from the `Dockerfile` pins.

- `VITE_CLIENT_ID`: the environment's OAuth client, baked into the front end.
- `DEPLOY_ENV`: `dev`, `uat`, `prod` or `aws`, shown after the front-end
  version.

The Cloud Run service's environment is then replaced with exactly this list:

| Variable           | Source                                          |
| ------------------ | ----------------------------------------------- |
| `MONGO_URI`        | `MONGO_URI` secret of the GitHub environment    |
| `UMLS_API_KEY`     | `UMLS_API_KEY` secret (repository)              |
| `GOOGLE_CLIENT_ID` | the environment's `VITE_CLIENT_ID` variable     |
| `LOCUTUS_LOGLEVEL` | `LOCUTUS_LOGLEVEL` variable if set, else `INFO` |

**Don't change these in the Cloud Run console.** The next deploy replaces them.
Change the GitHub environment's variables or secrets, then redeploy.

`GOOGLE_CLIENT_ID` has to be the same client the front end was built with, since
Locutus only accepts sign-in tokens issued for that client. If they differ,
every login fails with a 401. Both therefore come from the one `VITE_CLIENT_ID`
variable.

`VERSION` isn't set, so `/api/version` reports the Locutus release that's
running. `locutils dump`/`load` use that to check releases. The deployed release
tag is in the image name, shown on the Cloud Run revision.

Each GitHub environment (`dev`, `uat`, `alpha`) needs these:

- **Variables:** `GCP_PROJECT_ID`, `GCP_SERVICE`, `VITE_CLIENT_ID`. Also
  `LOCUTUS_LOGLEVEL`, which is optional.
- **Secrets:** `GCP_CREDENTIALS`, `MONGO_URI`.

`GCP_REGION`, `IMAGE_NAME`, `UMLS_API_KEY` and `GHRCIO_PAT` are set once for the
repository. A deploy stops at its first step and names anything missing.

### The AWS image

The ghcr.io image is built with the `alpha` environment's `VITE_CLIENT_ID`, so
the AWS deployment signs in through that OAuth client. That client lives in the
GCP project, which is funded by the other grant. To make it work:

- The AWS deployment's URL has to be added to the client's authorized JavaScript
  origins.
- The AWS deployment has to set `GOOGLE_CLIENT_ID` to the same ID.

If the AWS side should own its own OAuth client, give Package Container its own
GitHub environment holding that client's `VITE_CLIENT_ID`.

## One-time GitHub setup

These live in the repository settings, not in the workflows:

- **Required reviewers on `alpha`** (Settings → Environments). This is what
  makes prod a deliberate, approved step. It gates Package Container too, since
  that uses the same environment.
- **A tag ruleset for `v*`** (Settings → Rules) limiting who can create release
  tags, since pushing one deploys to UAT.
- **Branch protection on `main`** requiring the CI check, so a broken image
  can't reach dev.
- **Retire the `release` branch.** Releases are tags now, so nothing deploys
  from it anymore.
