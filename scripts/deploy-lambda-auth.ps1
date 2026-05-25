<#
.SYNOPSIS
    Provisiona Lambda auth-cpf + API Gateway (Terraform).

.EXAMPLE
    cd lambda-auth-oficina
    .\scripts\deploy-lambda-auth.ps1
#>
[CmdletBinding()]
param(
    [switch]$PlanOnly,
    [switch]$UseLocalState
)

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
$TfDir = Join-Path $Root "terraform"
$TfVars = Join-Path $TfDir "terraform.tfvars"

Write-Host "==> Conta AWS" -ForegroundColor Cyan
aws sts get-caller-identity | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "Configure credenciais AWS (Learner Lab) antes de continuar."
}

if (-not (Test-Path $TfVars)) {
    $Example = Join-Path $TfDir "terraform.tfvars.example"
    throw "Crie terraform/terraform.tfvars (copie de terraform.tfvars.example). Exemplo: $Example"
}

if (Get-Command npm -ErrorAction SilentlyContinue) {
    Write-Host "==> npm ci" -ForegroundColor Cyan
    Push-Location $Root
    try {
        npm ci
        if ($LASTEXITCODE -ne 0) { throw "npm ci falhou" }
    }
    finally {
        Pop-Location
    }
}
elseif (-not (Test-Path (Join-Path $Root "node_modules"))) {
    Write-Host "AVISO: npm não encontrado e node_modules ausente. Instale Node 20 ou rode 'npm ci' antes do apply." -ForegroundColor Yellow
}
else {
    Write-Host "==> node_modules presente (npm ci ignorado)" -ForegroundColor DarkGray
}

$BackendS3 = Join-Path $TfDir "backend_s3.tf"
$BackendDisabled = Join-Path $TfDir "backend_s3.tf.disabled"
if ($UseLocalState -and (Test-Path $BackendS3)) {
    Write-Host "==> Learner Lab: state local (backend S3 desabilitado)" -ForegroundColor Yellow
    Rename-Item $BackendS3 $BackendDisabled -Force
    Remove-Item -Recurse -Force (Join-Path $TfDir ".terraform") -ErrorAction SilentlyContinue
}

Write-Host "==> terraform init" -ForegroundColor Cyan
Push-Location $TfDir
$restoreBackend = $false
try {
    terraform init -input=false -reconfigure
    if ($LASTEXITCODE -ne 0) {
        if (-not $UseLocalState -and (Test-Path $BackendS3)) {
            throw "terraform init falhou. Tente: .\scripts\deploy-lambda-auth.ps1 -UseLocalState"
        }
        throw "terraform init falhou"
    }

    $lockArg = if ($UseLocalState) { "-lock=false" } else { "" }

    if ($PlanOnly) {
        if ($lockArg) { terraform plan -lock=false } else { terraform plan }
        if ($LASTEXITCODE -ne 0) { throw "terraform plan falhou" }
        $restoreBackend = $UseLocalState
        return
    }

    Write-Host "==> terraform apply" -ForegroundColor Cyan
    if ($lockArg) {
        terraform apply -auto-approve -lock=false
    } else {
        terraform apply -auto-approve
    }
    if ($LASTEXITCODE -ne 0) { throw "terraform apply falhou" }

    Write-Host ""
    Write-Host "==> Endpoints" -ForegroundColor Green
    terraform output
    $AuthUrl = terraform output -raw api_gateway_auth_endpoint 2>$null
    if (-not $AuthUrl) {
        $AuthUrl = terraform output -state=terraform.tfstate -raw api_gateway_auth_endpoint 2>$null
    }
    if ($AuthUrl) {
        Write-Host ""
        Write-Host "POST $AuthUrl" -ForegroundColor Green
        Write-Host 'Body: {"cpf":"52998224725"}' -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Teste: .\scripts\test-lambda-auth.ps1 -AuthUrl '$AuthUrl' -Cpf '52998224725'" -ForegroundColor Cyan
    }
    $restoreBackend = $UseLocalState
}
finally {
    Pop-Location
}
if ($restoreBackend -and (Test-Path $BackendDisabled) -and -not (Test-Path $BackendS3)) {
    Rename-Item $BackendDisabled $BackendS3 -Force
}
