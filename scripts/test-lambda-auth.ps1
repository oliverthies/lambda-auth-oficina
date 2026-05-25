<#
.SYNOPSIS
    Testa POST /auth na Lambda (API Gateway) e opcionalmente a API EKS.

.PARAMETER AuthUrl
    URL completa, ex.: https://xxx.execute-api.us-east-1.amazonaws.com/auth

.PARAMETER Cpf
    CPF do cliente no RDS (11 dígitos).

.PARAMETER ApiBaseUrl
    Opcional: http://<elb>/api/v1 para validar Bearer na API.

.EXAMPLE
    .\scripts\test-lambda-auth.ps1 -Cpf "52998224725"

.EXAMPLE
    .\scripts\test-lambda-auth.ps1 -AuthUrl "https://xxx.execute-api.us-east-1.amazonaws.com/auth" -Cpf "52998224725" -ApiBaseUrl "http://elb.../api/v1"
#>
[CmdletBinding()]
param(
    [string]$AuthUrl,
    [string]$Cpf = "52998224725",
    [string]$ApiBaseUrl
)

$ErrorActionPreference = "Stop"
$TfDir = Join-Path (Split-Path $PSScriptRoot -Parent) "terraform"

if (-not $AuthUrl) {
    Push-Location $TfDir
    try {
        $AuthUrl = terraform output -raw api_gateway_auth_endpoint 2>$null
        if (-not $AuthUrl) {
            $AuthUrl = terraform output -state=terraform.tfstate -raw api_gateway_auth_endpoint 2>$null
        }
    }
    finally {
        Pop-Location
    }
}

if (-not $AuthUrl) {
    throw "AuthUrl não definida. Passe -AuthUrl ou rode deploy-lambda-auth.ps1 antes."
}

Write-Host "POST $AuthUrl" -ForegroundColor Cyan
$body = @{ cpf = $Cpf } | ConvertTo-Json
$resp = Invoke-RestMethod -Method Post -Uri $AuthUrl -ContentType "application/json" -Body $body
$resp | ConvertTo-Json -Depth 5 | Write-Host

$token = $resp.token
if (-not $token) {
    throw "Resposta sem token."
}
Write-Host "Token obtido (primeiros 40 chars): $($token.Substring(0, [Math]::Min(40, $token.Length)))..." -ForegroundColor Green

if ($ApiBaseUrl) {
    $ApiBaseUrl = $ApiBaseUrl.TrimEnd("/")
    Write-Host "GET $ApiBaseUrl/clients (Bearer)" -ForegroundColor Cyan
    Invoke-RestMethod -Uri "$ApiBaseUrl/clients" -Headers @{ Authorization = "Bearer $token" } | ConvertTo-Json -Depth 3 | Write-Host
}
