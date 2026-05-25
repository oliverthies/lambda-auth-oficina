# Deploy da Lambda Auth (CPF → JWT)

Auth **serverless** separada do `POST /api/v1/auth/login` da API no EKS. Este módulo cria **Lambda + API Gateway HTTP**.

## Pré-requisitos

- Lab AWS ativo (`aws sts get-caller-identity`)
- **EKS + RDS** já no ar
- `terraform.tfvars` preenchido em `terraform/` (copie de `terraform.tfvars.example`)
- **`jwt_secret` idêntico** ao da API (`infra-geral-oficina/terraform.tfvars` → `jwt_secret`)

## Valores do `terraform.tfvars`

| Variável | Onde obter |
|----------|------------|
| `vpc_id`, `private_subnet_ids` | `terraform output` em `infra-geral-oficina` ou console VPC |
| `db_host`, `db_user`, `db_password` | RDS / `infra-database` |
| `rds_security_group_id` | `terraform output rds_security_group_id` em `infra-database` |
| `jwt_secret` | Mesmo da API no K8s |

## Deploy local (PowerShell)

**Learner Lab** (S3/DynamoDB bloqueados): use state local:

```powershell
cd lambda-auth-oficina
# Instale Node 20 e rode: npm ci
.\scripts\deploy-lambda-auth.ps1 -UseLocalState
```

Sem `-UseLocalState` se o backend S3 `oficina-terraform-state-...` estiver acessível.

**GitHub Actions:** o workflow desabilita `backend_s3.tf` no CI e usa `terraform.tfstate` versionado no repositório (evita prompt de migração S3 no runner).

O script roda `npm ci`, `terraform init`, `terraform apply` e mostra a URL `POST .../auth`.

## Deploy via GitHub Actions

Repositório **lambda-auth-oficina** → configure **Secrets**:

| Secret | Exemplo |
|--------|---------|
| `AWS_ACCESS_KEY_ID` | Lab |
| `AWS_SECRET_ACCESS_KEY` | Lab |
| `AWS_SESSION_TOKEN` | Lab |
| `VPC_ID` | `vpc-...` |
| `PRIVATE_SUBNET_IDS` | `subnet-aaa,subnet-bbb` (vírgula, sem colchetes) — o CI converte para JSON |
| `RDS_SECURITY_GROUP_ID` | `sg-...` |
| `DB_HOST` | endpoint RDS |
| `DB_USER` / `DB_PASSWORD` | oficina |
| `JWT_SECRET` | mesmo da API |

Push na `main`, **Run workflow** (Actions → Deploy Lambda Auth) ou:

```powershell
gh workflow run "Deploy Lambda Auth" --ref main
```

## Testar após o deploy

```powershell
.\scripts\test-lambda-auth.ps1 -Cpf "52998224725"
```

Ou Postman: `POST https://<api-gw>/auth` com body `{"cpf":"52998224725"}`.

Use o `token` em `Authorization: Bearer` nas chamadas ao ELB da API.

## Se `terraform output` vier vazio

O backend S3 pode estar vazio nesta conta. Use:

```powershell
terraform output -state=terraform.tfstate api_gateway_auth_endpoint
```

Ou console **API Gateway** → HTTP API → Invoke URL + `/auth`.

## Erros comuns

| Erro | Solução |
|------|---------|
| API Gateway vazio | Rode este deploy |
| 404 CPF | Cliente não existe no RDS — use `GET /clients` com admin |
| 401 na API com token Lambda | `jwt_secret` diferente entre Lambda e API |
| 500 Lambda | SG RDS sem regra da Lambda — confira `rds_security_group_id` |
| `init` falha no S3 | Credenciais Academy; bucket `oficina-terraform-state-...` na conta do lab |
