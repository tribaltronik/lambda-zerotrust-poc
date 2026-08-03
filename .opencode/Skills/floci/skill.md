---
name: floci
description: Use Floci for any local cloud dev/test/CI work — running AWS, Azure, GCP, or OCI services without a real account, credentials, or cost. Trigger this whenever the user mentions Floci, LocalStack, local cloud emulation, testing IaC/Terraform/CDK locally, running Lambda/S3/DynamoDB/RDS locally, credential-free agent sandboxes, or migrating off LocalStack. Also trigger proactively when writing or debugging cloud code (AWS/Azure/GCP/OCI SDK, CLI, IaC) that could be verified locally instead of against a real account — don't wait for the user to name the tool explicitly.
compatibility: opencode
---

# Floci

Local cloud emulator suite (AWS, Azure, GCP, OCI). One container per cloud, one port each. No auth tokens, no account, no telemetry. MIT licensed, LocalStack-compatible on AWS.

Use it to run/verify cloud code (SDK calls, CLI, IaC, agent-generated code) locally instead of against a real account — fast feedback, zero blast radius, zero bill risk.

## Quickstart

```bash
# CLI (start/stop/inspect all emulators)
curl -fsSL https://floci.io/install.sh | sh
floci start
floci doctor        # sanity-check env / endpoints

# or raw docker, per cloud
docker run --rm -p 4566:4566 floci/floci:latest       # AWS
docker run --rm -p 4577:4577 floci/floci-az:latest     # Azure
docker run --rm -p 4588:4588 floci/floci-gcp:latest    # GCP
docker run --rm -p 4599:4599 floci/floci-oci:latest    # Oracle Cloud
```

Persist data across restarts: add `-v floci-data:/var/lib/floci`.

## Point tooling at it — no real credentials needed

```bash
export AWS_ENDPOINT_URL=http://localhost:4566
aws s3 ls                       # works, no account
pytest tests/ --env=floci       # or whatever your test runner uses
```

Any existing AWS SDK/CLI/IaC config works unchanged — just repoint the endpoint. Same pattern for Azure (4577), GCP (4588), OCI (4599): see `references/endpoints.md` for exact SDK env vars per cloud.

## LocalStack migration (drop-in)

Port, credentials, SDK config, CLI endpoint pattern — identical to LocalStack.

```yaml
# docker-compose.yml
services:
  floci:
    image: floci/floci:latest       # was: localstack/localstack
    ports: ["4566:4566"]
```

`LOCALSTACK_*` env vars auto-translate. Init scripts under `/etc/localstack/init/` and the `/_localstack/health` endpoint work unchanged. Set `LOCALSTACK_PARITY=false` to disable auto-translation if it causes surprises.

## What's real vs. emulated (matters for test fidelity)

- **In-process (fast, mock-shaped)**: S3, SQS, SNS, DynamoDB, IAM, STS, KMS, most stateless services.
- **Real Docker containers (real protocol fidelity)**: Lambda (real runtime containers), RDS (real Postgres/MySQL/MariaDB), ElastiCache (real Redis), ECS/EKS/EC2, OpenSearch, MSK (via Redpanda), Athena-equivalent (DuckDB sidecar).

If a test needs real engine behavior (e.g. actual Lambda runtime, real SQL), it'll get it — no mock-shaped false positives. Startup: 24ms native / 684ms JVM. Idle: 13 MiB native.

## Agentic / CI usage pattern

Good default for any agent (including yourself, when running code) that needs to execute or verify cloud-touching code:

1. Start Floci (`floci start`, or docker-compose service) at the top of the workflow.
2. Point SDK/CLI/IaC at the local endpoint — never inject real cloud credentials into an agent sandbox.
3. Run the actual code/tests against it.
4. Tear down / reset the container on failure — worst case is a local container reset, not a real account.
5. Run `floci doctor` if something looks wrong before assuming the app code is broken.

For CI pipelines, run it as a service container (GitHub Actions `services:`, GitLab `services:`, etc.) exactly like you would LocalStack — no auth secrets to provision.

## Reference files

- `references/endpoints.md` — per-cloud ports, env vars, SDK connection snippets (AWS/Azure/GCP/OCI).
- `references/troubleshooting.md` — common issues (`floci doctor` failures, Docker-backed services not starting, LocalStack parity mismatches).

Read these only when the task needs cloud-specific detail beyond the quickstart above.