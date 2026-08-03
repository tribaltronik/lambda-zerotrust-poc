# API Examples

Paste-and-run `curl` examples for the five CRUD routes, first against the local **Floci**
emulator, then against a **real AWS** deployment. A ready-to-import Postman collection
mirrors these examples in [`api-examples.postman_collection.json`](api-examples.postman_collection.json).

Every route is protected by a Cognito User Pool authorizer and expects an `Authorization`
header (any value on Floci; a real Cognito ID token on AWS).

## Prerequisites
**Local (Floci):** `make up` (starts Floci, builds Lambda zips, runs terraform init + apply).
**Real AWS** — deploy the stack and create a Cognito user:
```bash
export TF_VAR_github_org="your-org" TF_VAR_github_repo="your-repo"
terraform -chdir=terraform/bootstrap init
terraform -chdir=terraform/bootstrap apply -auto-approve
terraform -chdir=terraform init -backend-config=backend-aws.tfvars
terraform -chdir=terraform apply -var="use_localstack=false" -var-file=terraform.tfvars.example
USER_POOL_ID=$(terraform -chdir=terraform output -raw cognito_user_pool_id)
aws cognito-idp admin-create-user --user-pool-id "$USER_POOL_ID" \
  --username "api-user@example.com" --message-action SUPPRESS
aws cognito-idp admin-set-user-password --user-pool-id "$USER_POOL_ID" \
  --username "api-user@example.com" --password "ChangeMe123!" --permanent
```

## Local (Floci)
The emulator accepts **any** `Authorization` value, so the literal string `test` works.
```bash
API_ID=$(terraform -chdir=terraform output -raw api_id)
BASE_URL="http://localhost:4566/restapis/${API_ID}/dev/_user_request_"

# 1. Create → 201
curl -i -X POST "$BASE_URL/items" -H "Authorization: test" -H "Content-Type: application/json" \
  -d '{"name": "Mechanical Keyboard", "description": "75% hot-swappable, tactile switches", "price": 129.99}'
# capture the UUID from the 201 body — or automate it:
# ITEM_ID=$(curl -s -X POST "$BASE_URL/items" -H "Authorization: test" -H "Content-Type: application/json" \
#   -d '{"name":"Demo item","description":"created via curl","price":9.99}' \
#   | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')
ITEM_ID="3f2c9a7e-0000-0000-0000-000000000001"

# 2. Get → 200
curl -i "$BASE_URL/items/$ITEM_ID" -H "Authorization: test"
# 3. Update (partial) → 200
curl -i -X PUT "$BASE_URL/items/$ITEM_ID" -H "Authorization: test" -H "Content-Type: application/json" \
  -d '{"name": "Mechanical Keyboard (rev B)", "price": 139.99}'
# 4. List → 200
curl -i "$BASE_URL/items" -H "Authorization: test"
# 5. Delete → 204 (empty body)
curl -i -X DELETE "$BASE_URL/items/$ITEM_ID" -H "Authorization: test"
```

Expected success bodies. Create / Get / Update return the stored record — including the
internal `PK`/`SK` partition keys (Update bumps `updated_at`):
```json
{
  "PK": "ITEM#3f2c9a7e-0000-0000-0000-000000000001",
  "SK": "METADATA",
  "id": "3f2c9a7e-0000-0000-0000-000000000001",
  "name": "Mechanical Keyboard",
  "description": "75% hot-swappable, tactile switches",
  "price": 129.99,
  "created_at": "2026-08-03T12:00:00Z",
  "updated_at": "2026-08-03T12:00:00Z"
}
```
- **List** → `{"items": [<record>, ...], "count": n}` (empty table: `{"items": [], "count": 0}`).
- **Delete** → 204 with an empty body.

## Real AWS
```bash
API_URL=$(terraform -chdir=terraform output -raw api_url)   # https://<api-id>.execute-api.<region>.amazonaws.com/dev
CLIENT_ID=$(terraform -chdir=terraform output -raw cognito_user_pool_client_id)
USER_POOL_ID=$(terraform -chdir=terraform output -raw cognito_user_pool_id)

TOKEN=$(aws cognito-idp initiate-auth \
  --client-id "$CLIENT_ID" \
  --auth-flow USER_PASSWORD_AUTH \
  --auth-parameters "USERNAME=api-user@example.com,PASSWORD=ChangeMe123!" \
  --query 'AuthenticationResult.IdToken' --output text)
```
`initiate-auth` returns a JSON envelope; the ID token lives under
`AuthenticationResult` (extracted by the `--query` above). `USER_PASSWORD_AUTH` is the
non-admin flow the client enables in `terraform/cognito.tf` (`ALLOW_USER_PASSWORD_AUTH`).
```json
{
  "AuthenticationResult": {
    "IdToken": "<id-token>",
    "AccessToken": "<access-token>",
    "RefreshToken": "<refresh-token>",
    "ExpiresIn": 3600,
    "TokenType": "Bearer"
  }
}
```
Same five routes, sending the token as a Bearer credential:
```bash
# 1. Create → 201
curl -i -X POST "$API_URL/items" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"name": "Mechanical Keyboard", "description": "75% hot-swappable, tactile switches", "price": 129.99}'
# 2. Get → 200
curl -i "$API_URL/items/$ITEM_ID" -H "Authorization: Bearer $TOKEN"
# 3. Update → 200
curl -i -X PUT "$API_URL/items/$ITEM_ID" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"name": "Mechanical Keyboard (rev B)", "price": 139.99}'
# 4. List → 200
curl -i "$API_URL/items" -H "Authorization: Bearer $TOKEN"
# 5. Delete → 204
curl -i -X DELETE "$API_URL/items/$ITEM_ID" -H "Authorization: Bearer $TOKEN"
```
Responses match the Floci shapes. ID tokens expire after an hour (`ExpiresIn: 3600`); re-run the `initiate-auth` block to refresh.

## Error cases
Errors are JSON with a `message` field (plus an `errors` array for validation failures).
A 401 is returned by API Gateway itself before any Lambda runs.

| Case | Call | Status | Body |
|------|------|--------|------|
| Missing item | `GET /items/{id}` | 404 | `{"message": "Item not found: <id>"}` |
| Missing item | `PUT /items/{id}` | 404 | `{"message": "Item not found: <id>"}` |
| Missing item | `DELETE /items/{id}` | 404 | `{"message": "Item not found: <id>"}` |
| Missing / empty `name` | `POST /items` | 400 | `{"message": "Validation failed", "errors": [...]}` |
| Negative `price` | `POST /items` | 400 | `{"message": "Validation failed", "errors": [...]}` |
| Malformed JSON | `POST /items` | 400 | `{"message": "Invalid JSON in request body"}` |
| No body | `POST /items` | 400 | `{"message": "Request body is required"}` |
| Missing / invalid token | any | 401 | `{"message": "Unauthorized"}` (real AWS only) |

Example 400 body for a POST missing `name` (pydantic detail; the `url` value varies by pydantic version):
```json
{
  "message": "Validation failed",
  "errors": [
    {
      "type": "missing",
      "loc": ["name"],
      "msg": "Field required",
      "input": {"description": "no name"},
      "url": "https://errors.pydantic.dev/2.9/v/missing"
    }
  ]
}
```

## Notes
- **POST body** (`ItemCreate`): `name` (string, required, 1–255 chars), `description`
  (optional, ≤1024), `price` (number, optional, ≥0).
- **PUT body** (`ItemUpdate`): the same three fields, **all optional** — partial update;
  an empty body `{}` returns the unchanged item (200).
- **Cognito caveat**: creating the user needs admin API calls (`admin-create-user`,
  `admin-set-user-password`), but token minting uses the standard non-admin
  `USER_PASSWORD_AUTH` flow that the client enables in `terraform/cognito.tf`.
