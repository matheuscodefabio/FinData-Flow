# FinData Flow

Infraestrutura AWS para ingestao e reconciliacao de transacoes financeiras, escrita em Terraform com modulos reutilizaveis.

## Objetivo

- Ingestao sincrona via API (baixa latencia)
- Processamento assincrono de lotes longos
- Separacao clara por ambiente: dev, staging e prod

## Arquitetura (resumo)

```text
Partner -> API Gateway -> Lambda -> SQS -> ECS Fargate
                                 |            |
                                 |            +-> RDS (dados)
                                 +-> DLQ      +-> DynamoDB (estado)

Frontend: CloudFront -> S3 privado (OAC)
```

Diagrama tecnico: [docs/architecture.md](docs/architecture.md)

## Estrutura do repositorio

```text
bootstrap/                 # cria backend remoto (S3 + DynamoDB lock)
modules/                   # modulos Terraform reutilizaveis
  networking/
  lambda-ingestor/
  sqs/
  ecs-processor/
  frontend/
environments/              # composicao por ambiente
  dev/
  staging/
  prod/
.github/workflows/         # CI/CD
  terraform-plan.yml
  terraform-apply.yml
  health-check.yml
scripts/
  smoke-test.sh
  canary-evaluate.sh
  lambda-rollback.sh
```

## CI/CD e rollback

- `terraform-plan.yml`: valida PR com fmt, tflint, checkov, validate e plan por ambiente.
- `terraform-apply.yml`: deploy sequencial dev -> staging -> prod com artefato imutavel e passos enxutos.
- Em prod: canary de Lambda (10%) via `scripts/canary-evaluate.sh`, com promocao para 100% ou rollback automatico.
- Rollback manual suportado via `workflow_dispatch` em `terraform-apply.yml`.

## Cobertura do desafio

- API <= 150ms P99: Lambda com alias `stable`, provisioned concurrency em prod e alarme de latencia.
- Processamento longo (10-40 min): ECS Fargate + SQS com visibility timeout de 45 min + DLQ.
- Borda segura: CloudFront com OAC e bucket S3 privado (sem acesso publico direto).
- Isolamento e promocao: ambientes dev/staging/prod separados em `environments/` com backends de state isolados.
- IaC: Terraform modular em `modules/` e composicao por ambiente em `environments/`.
- CI/CD: validacao de PR (`terraform-plan.yml`) e deploy sequencial com gates (`terraform-apply.yml`).
- Zero-downtime e rollback: canary de Lambda em prod e rollback automatico/manual no workflow de apply.

## Como subir

1. Bootstrap do state remoto:

```bash
cd bootstrap
terraform init
terraform apply
```

2. Deploy de um ambiente (exemplo dev):

```bash
cd environments/dev
terraform init
terraform plan
terraform apply
```

## Notas praticas

- Os ambientes usam os mesmos modulos; o que muda sao os `terraform.tfvars`.
- Se aparecer erro de sintaxe Terraform, valide primeiro os arquivos `variables.tf`.
- O health check em [ .github/workflows/health-check.yml ](.github/workflows/health-check.yml) roda por cron (a cada 6 horas) e tambem manualmente (`workflow_dispatch`).

