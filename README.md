# Vehicle Quote API: Laravel on Azure Container Apps

A small production-style Laravel 13 API, containerised with FrankenPHP. It is deployed to **Azure Container Apps** by **GitHub Actions** using **OIDC** (no stored cloud passwords), with the infrastructure defined in **Bicep**.

The domain comes from a real product I built: a vehicle-buying platform where a customer enters basic car data and gets an instant cash offer.

```
push to main ──► test (PHPUnit, Pint, Bicep build)
             ──► build image ──► smoke test ──► push to ghcr.io
             ──► azure/login (OIDC) ──► az deployment group create (Bicep)
             ──► verify that /api/info on the live URL serves the new git SHA
```

## API

| Method | Path | Description |
|---|---|---|
| `POST` | `/api/quotes` | Returns a cash offer for a vehicle (validated, rate-limited to 30/min) |
| `GET` | `/api/info` | Running build: version (git SHA), region, PHP and Laravel versions |
| `GET` | `/up` | Health check, used by the Container Apps liveness and readiness probes |

```bash
curl -X POST "$URL/api/quotes" \
  -H 'Content-Type: application/json' -H 'Accept: application/json' \
  -d '{"year":2014,"body_type":"sedan","condition":"not_running","mileage":150000,"zip":"48201"}'
```

```json
{
  "id": "1dc09f13-…",
  "offer": 215,
  "currency": "USD",
  "breakdown": { "base": 900, "age_factor": 0.52, "mileage_factor": 0.7, "condition_factor": 0.65 },
  "valid_until": "2026-12-01"
}
```

## Design decisions

- **Container image.** A multi-stage build: Composer installs packages without dev dependencies, and the runtime is FrankenPHP (Caddy and PHP 8.4 in one binary) on Alpine. The container runs as the non-root user `www-data` and listens on port 8080. The image is about 335 MB.
- **Stateless by design.** Logs go to stdout and on to Log Analytics. There is no database, and sessions are stored in cookies, so any replica can serve any request and the app can **scale to zero**.
- **Configuration at start-up.** `config:cache` runs when the container starts, not at build time. The same image can therefore be promoted between environments with different settings.
- **Secrets.** `APP_KEY` is stored as a GitHub secret, passed to Bicep as a `@secure()` parameter, and saved as a Container Apps secret. It never appears in the image or the logs.
- **Least privilege.** The GitHub deploy identity is an Entra ID app with a federated credential that only trusts this repository's `main` branch. It holds **Contributor on one resource group**, not on the whole subscription.
- **Verified deploys.** The pipeline only passes once the live URL reports the new git SHA.
- **Cost.** The app runs on the consumption plan with 0–2 replicas, 0.25 vCPU and 0.5 GiB. The image lives in GHCR, so no container registry is billed. For a demo, the cost stays within the Azure free monthly grants.

## Run locally

```bash
docker build -t vehicle-quote-api .
docker run -p 8080:8080 -e APP_KEY="base64:$(openssl rand -base64 32)" vehicle-quote-api
curl localhost:8080/api/info
```

Tests: `composer install && cp .env.example .env && php artisan key:generate && php artisan test`

## Deploy your own copy

1. Install the Azure CLI and GitHub CLI, then run `az login` and `gh auth login`.
2. Run the one-time setup script:
   ```powershell
   ./infra/bootstrap.ps1 -Repo <owner>/<repo>
   ```
   It creates the resource group (in `germanywestcentral` by default), the OIDC app registration, its federated credential and role assignment, and the GitHub secrets.
3. Push to `main`. The URL appears in the summary of the deploy job.

## Project layout

```
app/Services/QuoteEstimator.php      pricing logic (pure, unit-tested)
app/Http/Controllers/Api/            QuoteController, InfoController
app/Http/Requests/StoreQuoteRequest  input validation
infra/main.bicep                     Log Analytics + Container Apps environment + Container App
infra/bootstrap.ps1                  one-time Azure/GitHub OIDC setup
.github/workflows/ci-deploy.yml      test → build → smoke test → deploy → verify
Dockerfile                           multi-stage, FrankenPHP, non-root
```
