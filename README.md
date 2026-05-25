# Lambda Auth Oficina

Function Serverless (AWS Lambda) para autenticação de clientes via CPF no Sistema de Gestão de Oficina Mecânica.

**Deploy completo da solução (aplicar este módulo por último):** [INFRA_DEPLOY.md](https://github.com/oliverthies/infra-geral-oficina/blob/main/INFRA_DEPLOY.md)

**Guia rápido (provisionar + testar):** [DEPLOY_LAMBDA.md](./DEPLOY_LAMBDA.md)

## Propósito

Este repositório contém a Lambda responsável por:
1. **Validar o CPF** do cliente (formato e dígitos verificadores)
2. **Consultar a existência e status** do cliente na base de dados (RDS PostgreSQL)
3. **Gerar e devolver um JWT** válido para consumo das APIs protegidas

O JWT gerado é compatível com o `JwtAuthenticationFilter` da API no EKS (`oficina-api` / [projeto-oficina](https://github.com/oliverthies/projeto-oficina)), compartilhando o mesmo secret e estrutura de claims.

## Arquitetura

```
┌──────────┐  POST /auth   ┌───────────────┐     ┌──────────────┐     ┌─────────┐
│  Cliente  │ ────────────► │  API Gateway  │ ──► │    Lambda    │ ──► │   RDS   │
│           │ {"cpf":"..."}│  (HTTP API)   │     │  auth-cpf    │     │PostgreSQL│
│           │ ◄──────────── │               │ ◄── │              │     │         │
└──────────┘  {token,...}   └───────────────┘     └──────────────┘     └─────────┘
                                                         │
      ┌──────────────────────────────────────────────────┘
      │  Mesma VPC / Subnets privadas
      ▼
┌──────────────┐
│  oficina-api │  ← Aceita o JWT gerado (mesmo secret HMAC-SHA256)
│  (EKS)       │
└──────────────┘
```

## Tecnologias

| Componente | Tecnologia |
|---|---|
| Runtime | Node.js 20 (AWS Lambda) |
| JWT | `jsonwebtoken` (HS256) |
| Banco de Dados | `pg` (PostgreSQL driver) |
| Gateway | AWS API Gateway HTTP |
| IaC | Terraform |
| CI/CD | GitHub Actions |

## Estrutura do Repositório

```
lambda-auth-oficina/
├── .github/workflows/deploy.yml   # CI/CD: plan em PR, apply em main
├── terraform/
│   ├── main.tf                    # Provider AWS
│   ├── lambda.tf                  # Lambda + IAM + Security Group
│   ├── api-gateway.tf             # API Gateway HTTP + rota POST /auth
│   ├── variables.tf               # Variáveis de entrada
│   ├── outputs.tf                 # URL do endpoint
│   └── terraform.tfvars.example   # Template de variáveis
├── src/
│   ├── index.mjs                  # Handler principal da Lambda
│   ├── cpf-validator.mjs          # Validação de CPF brasileiro
│   └── cpf-validator.test.mjs     # Testes unitários
├── package.json
└── README.md
```

## Endpoint

### `POST /auth`

Autentica um cliente via CPF e retorna um JWT.

**Request:**
```json
{
  "cpf": "52998224725"
}
```

O CPF pode ser enviado com ou sem formatação (`529.982.247-25` ou `52998224725`).

**Response (200):**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "expiresIn": 3600,
  "client": {
    "clientId": 1,
    "name": "João Silva",
    "cpf": "52998224725"
  }
}
```

**Erros:**

| Status | Cenário |
|---|---|
| 400 | CPF inválido (formato ou dígitos verificadores) |
| 404 | Cliente não encontrado na base |
| 403 | Usuário vinculado ao cliente está inativo |
| 500 | Erro interno (falha na conexão com banco, etc.) |

### Usando o token na API

```bash
# 1. Obter token via Lambda
TOKEN=$(curl -s -X POST https://<api-gw-url>/auth \
  -H "Content-Type: application/json" \
  -d '{"cpf":"52998224725"}' | jq -r '.token')

# 2. Consumir API protegida
curl -H "Authorization: Bearer $TOKEN" \
  https://<api-eks-url>/api/v1/clients
```

## Claims do JWT

O token gerado contém as mesmas claims do `JwtTokenProvider.java`:

| Claim | Tipo | Descrição |
|---|---|---|
| `sub` | String | Username do usuário (ou CPF se não houver user) |
| `userId` | Long | ID do usuário na tabela `users` |
| `role` | String | `ADMIN`, `OPERADOR` ou `CLIENTE` |
| `clientId` | Long | ID do cliente na tabela `client` |
| `iat` | Timestamp | Data de emissão |
| `exp` | Timestamp | Expiração (1 hora) |

## Pré-requisitos

- AWS CLI configurado
- Terraform >= 1.0
- Node.js 20
- Recursos de rede provisionados pelo `infra-geral-oficina`
- RDS provisionado pelo `infra-database-oficina`

## Deploy Local

```powershell
# 1. Lab AWS ativo; copie terraform/terraform.tfvars.example → terraform.tfvars
# 2. jwt_secret = MESMO valor da API (infra-geral-oficina/terraform.tfvars)
cd lambda-auth-oficina
.\scripts\deploy-lambda-auth.ps1

# 3. Testar CPF → JWT
.\scripts\test-lambda-auth.ps1 -Cpf "52998224725" -ApiBaseUrl "http://<elb>/api/v1"
```

Detalhes: [DEPLOY_LAMBDA.md](./DEPLOY_LAMBDA.md).

## CI/CD

| Evento | Ação |
|---|---|
| Pull Request → `main` | `terraform plan` (validação) |
| Push em `main` | `npm ci` + `terraform apply` (deploy) |

**Governança:** PR obrigatório para `main`; convide **`soat-architecture`** e use branch protection (1 approval + plan no PR).

### Secrets necessários no GitHub

| Secret | Descrição |
|---|---|
| `AWS_ACCESS_KEY_ID` | Credenciais AWS |
| `AWS_SECRET_ACCESS_KEY` | Credenciais AWS |
| `AWS_SESSION_TOKEN` | Token de sessão (Learner Lab) |
| `JWT_SECRET` | Chave de assinatura JWT (mesmo da API) |
| `DB_HOST` | Endpoint do RDS PostgreSQL |
| `DB_USER` | Usuário do banco |
| `DB_PASSWORD` | Senha do banco |

## Testes

```bash
npm test
```
