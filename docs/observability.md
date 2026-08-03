# Observability — dashboard, X-Ray, and cold starts

How the PoC is instrumented, how to read the CloudWatch dashboard, how to review
X-Ray traces, and how to measure (and reason about) Lambda cold starts.

## 1. What is instrumented today

| Signal | Where | Details |
|---|---|---|
| Structured logs | CloudWatch Logs, `/aws/lambda/lambda-zerotrust-poc-*` | Powertools `Logger` emits JSON lines, `LOG_LEVEL=INFO`, `POWERTOOLS_SERVICE_NAME` = the function name |
| Custom metrics | Namespace `LambdaZeroTrustPOC` | Powertools `Metrics`: `ItemsListed`, `ItemCreated`, `ItemRetrieved`, `ItemUpdated`, `ItemDeleted` (each `Count=1` per successful call) |
| Distributed tracing | X-Ray | `tracing_mode = "Active"` on every Lambda; `xray_tracing_enabled = true` on the API Gateway stage |
| API Gateway access logs | `/aws/apigateway/lambda-zerotrust-poc-api` | Structured JSON: `requestId`, `httpMethod`, `resourcePath`, `status`, `responseLatency`, `sourceIp`, `userAgent`, `cognitoIdentity` |

## 2. CloudWatch dashboard

Defined in `terraform/cloudwatch.tf` and deployed as **`lambda-zerotrust-poc-dashboard`**
(name is prefixed `${var.project_name}-` so the GitHub Actions deploy role's
`cloudwatch:PutDashboard` permission covers it). It is skipped when
`use_localstack=true` because Floci does not emulate CloudWatch dashboards.

Open it in the console: **CloudWatch → Dashboards → `lambda-zerotrust-poc-dashboard`**
(region = `aws_region`, default `us-east-1`).

| Widget | Answers |
|---|---|
| Title | Environment + what the dashboard covers |
| Lambda Invocations (per function) | Is this route being called? Traffic trend |
| Lambda Errors & Throttles | Are functions failing or being rate-limited? |
| Lambda Duration (p50/p95/p99) | Latency distribution per function (includes cold starts on the tail) |
| API Gateway 4XX/5XX errors | Client errors vs server errors at the edge |
| API Gateway Latency (p95) | End-to-end latency and its Lambda/Integration split |
| DynamoDB UserErrors / ThrottledRequests | Is the table erroring or throttling? |
| Cold starts (log widget) | Max `Init Duration` + cold-start count per function, parsed from `REPORT` lines |

All metric widgets use the `metrics`-array (metricWidget) form with real module
outputs for function names, the API Gateway stage, and the table name, so the
dashboard stays correct if resource names change.

## 3. X-Ray trace review

X-Ray is Active on both Lambda and API Gateway, so every request produces one
end-to-end trace with segments from API Gateway, the Lambda service, the handler,
and (via subsegments) DynamoDB.

- **Service map**: X-Ray → Service map. Shows the client → API Gateway → Lambda →
  DynamoDB topology, with error/fault edges in red/amber. Click an edge for
  latency + trace count.
- **Trace list**: X-Ray → Traces. Filter by service name — the Powertools
  `POWERTOOLS_SERVICE_NAME` is the function name, so
  `service("lambda-zerotrust-poc-list-items")` narrows to one handler.
- **What to look for**:
  - A cold start shows up as the Lambda `Init` phase (an `Init Duration` subsegment)
    before the handler segment.
  - DynamoDB latency: check the `DynamoDB` subsegment per call; high p99 there
    points at table issues (see the DynamoDB widget).
  - 4xx/5xx: the API Gateway and Lambda segments carry HTTP status; filter for
    error segments (`resp.status >= 400`) to find failed requests and retries.
- **Correlate a requestId to a trace**: API Gateway records the access-log
  `requestId` as the `http.request_id` attribute on its segment. Take a
  `requestId` from `/aws/apigateway/lambda-zerotrust-poc-api`, then filter the
  X-Ray trace list for that value (or search the trace by that string) to jump
  straight to the request's full trace.

## 4. Cold starts

A cold start happens when a request is routed to a freshly-provisioned
execution environment (no warm container available): the runtime + dependencies
must load before the handler runs. It shows up as `Init Duration` on the first
`REPORT` line of that invocation.

**Measure it:**

```bash
# all 5 lambda-zerotrust-poc-* functions, 5 samples each
./scripts/measure-cold-start.sh

# a single function, 20 samples
./scripts/measure-cold-start.sh --function lambda-zerotrust-poc-get-item --samples 20
```

The script forces a cold start by writing a unique `COLDSTART_PROBE` value into
the function's environment (a config change recycles the environment — existing
env vars are preserved), then invokes `--samples` times and reports, per
function: samples, cold-start count, min/median/max `Init Duration`, and median
total `Duration`.

**What to expect**: on real AWS, Python 3.13 at 256 MB with these dependencies
typically initializes in tens to low hundreds of milliseconds. On Floci the
numbers are much higher (~seconds) and not representative — measure against real
AWS. Only the first invoke after the env change is cold, so `ColdStarts` should
be ≈ 1 per function.

**Reducing cold starts — provisioned concurrency**: keeps N environments warm at
an hourly per-environment cost (effectively paying for idle compute). It is the
right tool for latency-critical, spiky paths; for a low-traffic PoC the default
(pay-per-invoke) model is cheaper. See `docs/cost.md` for the numbers and the
tradeoff. The dashboard's Duration widget shows whether the cold-start tail is
actually hurting p95 before you spend money on it.

## 5. Adding a CloudWatch alarm (next step)

The natural follow-up is a small `aws_cloudwatch_metric_alarm` in
`terraform/cloudwatch.tf`, e.g.:
- `Errors >= 5` over 5 min on `AWS/Lambda/Errors` for the whole function set,
- `Throttles > 0`, or
- `4XXError/5XXError` on `AWS/ApiGateway`.

An alarm only needs `cloudwatch:PutMetricAlarm` added to the GitHub Actions
deploy-role policy in `terraform/oidc.tf`. Not implemented yet — keep an eye on
the dashboard first, then add alarms for whatever actually bites.
