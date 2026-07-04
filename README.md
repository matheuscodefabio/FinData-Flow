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
  pr-validate.yml
  deploy.yml
  health-check.yml
```

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

