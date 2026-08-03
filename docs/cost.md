# Cost Estimate — Lambda Zero-trust PoC (low-traffic tier)

## TL;DR

A serverless REST API on AWS (5 Python 3.13 Lambdas at 256 MB, API Gateway REST with a Cognito
authorizer, DynamoDB on-demand, X-Ray + CloudWatch) serving ~100k requests/month costs roughly
**$1.50/month during the first 12 months (free-tier eligible)** and roughly **$2.50/month
steady-state afterwards**. The dominant items are CloudWatch custom metrics and X-Ray; core
compute (Lambda + API Gateway + DynamoDB) is under a dollar. Numbers are approximate list
prices — prices change; this is an order-of-magnitude estimate, not a quote.

## 1. Assumptions (low-traffic tier)

| Input | Value | Basis |
|---|---|---|
| API requests / month | 100,000 (~3,333/day) | "Low traffic" tier per `docs/spec.md` NFR |
| Lambda invocations | 1 per API request | `AWS_PROXY` integration → 1 handler call (api-gateway module) |
| Lambda duration | 200 ms avg | config timeout 10 s, `modules/lambda/variables.tf` |
| Lambda memory | 256 MB | `modules/lambda/variables.tf` |
| GB-s / request | 0.256 GB × 0.2 s = **0.0512** | — |
| Read mix (get + list) | 0.7 RCU / request | ~20k Scan/Query (~2 RCU) + ~30k GetItem (1 RCU) |
| Write mix (create/update/delete) | 0.5 WCU / request | items < 1 KB, ~50k writes |
| X-Ray traces / month | 100,000 | 1 trace per invocation (tracing_mode = Active) |
| Log volume | ~150 MB / month | ~1 KB Lambda JSON log + ~0.5 KB API GW access log per request |
| Region | us-east-1 | `variables.tf` default |

Derived monthly usage: **5,120 GB-s** Lambda compute, **100k** Lambda/API requests, **70k** read
units + **50k** write units DynamoDB, **100k** traces, **0.15 GB** logs ingested.

## 2. Unit costs (approximate, list prices)

| Service | Unit price | Source page |
|---|---|---|
| Lambda compute | ~$0.0000166667 / GB-s | AWS Lambda pricing |
| Lambda requests | ~$0.20 / 1M | AWS Lambda pricing |
| API Gateway (REST) | ~$3.50 / 1M requests | Amazon API Gateway pricing |
| DynamoDB on-demand | ~$0.25 / 1M read units, ~$1.25 / 1M write units | Amazon DynamoDB pricing |
| CloudWatch Logs ingest | ~$0.50 / GB (5 GB free) | Amazon CloudWatch pricing |
| CloudWatch custom metrics | ~$0.30 / metric / month | Amazon CloudWatch pricing |
| X-Ray traces | ~$5.00 / 1M (100k free / month) | AWS X-Ray pricing |
| Cognito User Pools | ~$0.0055 / MAU (50k free) | Amazon Cognito pricing |

## 3. Monthly cost

| Service | Unit | Usage | Unit price | Line total | Free-tier / always-free |
|---|---|---|---|---|---|
| Lambda compute | GB-s | 5,120 | $0.0000166667 | $0.09 | 400k GB-s free (12 mo) |
| Lambda requests | 1M req | 0.1 | $0.20 | $0.02 | 1M req free (12 mo) |
| API Gateway REST | 1M req | 0.1 | $3.50 | $0.35 | 1M req free (12 mo) |
| DynamoDB writes | 1M units | 0.05 | $1.25 | $0.06 | 25 GB storage free (always) |
| DynamoDB reads | 1M units | 0.07 | $0.25 | $0.02 | — |
| CloudWatch Logs | GB | 0.15 | $0.50 | $0.00 | 5 GB ingest free (always) |
| CloudWatch metrics (Powertools) | metric | 5 | $0.30 | $1.50 | — |
| X-Ray | 1M traces | 0.1 | $5.00 | $0.00 | 100k traces free (12 mo) |
| Cognito User Pool | MAU | ~2 | $0.0055 | $0.00 | 50k MAU free (12 mo) |
| S3 state bucket + lock table | GB | <0.01 | ~$0.023 | $0.01 | — |

**First 12 months (free tier applied): ~$1.50/month** (custom metrics only).
**Steady-state after free tier: ~$2.50/month** (X-Ray ~$0.50 + API GW $0.35 + Lambda $0.11 +
DynamoDB $0.08 + metrics $1.50).

## 4. What would raise cost

- **Provisioned concurrency** — pays for warm capacity even at zero traffic; not used here (only
  considered as a documented cold-start tradeoff).
- **Higher memory** — Lambda is billed per GB-s; doubling memory doubles the compute line.
- **X-Ray sampling above 5%** — 100% tracing keeps the trace count at the free-tier edge; default
  sampling (~5%) would stay well under 100k.
- **Access-log retention** — the API GW log group is capped at 365 days; raising it (or leaving
  Lambda log groups to "never expire", which the config doesn't cap) grows storage cost.
- **Custom metrics** — the biggest line at this scale; each extra Powertools metric is ~$0.30/mo.
- **Dashboards** — the dashboard itself is free; the cost is the metrics it plots.

## 5. Cost-control notes (already in the config)

- DynamoDB is `billing_mode = "PAY_PER_REQUEST"` (on-demand) — pay per request, zero idle cost.
- No provisioned concurrency; no reserved concurrency either.
- Single region (us-east-1), no VPC, no NAT, no data-transfer routing.
- Access logs are a compact JSON format with a 365-day retention cap (not infinite).
- Free tiers cover this workload almost entirely for the first 12 months.
- State backend (S3 bucket + lock table) is negligible at <1 MB of state.
