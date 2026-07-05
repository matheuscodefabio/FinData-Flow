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
                                 +-> CloudWatch (logs, metricas, alarmes)

Frontend: CloudFront -> S3 privado (OAC)
```

Diagrama tecnico: [docs/architecture.md](docs/architecture.md)

## Estrutura do repositorio

```text
bootstrap/                 # cria backend remoto (S3 + DynamoDB lock)
modules/                   # modulos Terraform reutilizaveis
  networking/
  lambda-ingestor/
  dynamodb-state/
  sqs/
  ecs-processor/
  frontend/
docs/                      # arquitetura e diagramas
environments/              # composicao por ambiente
  dev/
  staging/
  prod/
.github/workflows/         # CI/CD
  terraform-plan.yml
  terraform-apply.yml
scripts/
  smoke-test.sh
```

## CI/CD e rollback

- `terraform-plan.yml`: valida PR com fmt, tflint, checkov, validate e plan por ambiente.
- `terraform-apply.yml`: deploy sequencial dev -> staging -> prod com artefato imutavel e passos enxutos.
- Em prod: CodeDeploy nativo para Lambda com `CodeDeployDefault.LambdaCanary10Percent15Minutes`.
- Rollback automatico por alarmes CloudWatch (P99 > 130ms e error rate > 2%), independente do estado do runner/pipeline.
- Rollback manual de emergencia via `workflow_dispatch` com `aws lambda update-alias` imediato.

## Deployment strategy

- Canary em producao via CodeDeploy (10% por 15 minutos) para zero-downtime.
- Alarmes de seguranca: P99 em 130ms (margem antes do SLO de 150ms) e taxa de erro acima de 2%.
- Durante a janela de canary, o trafego desviado para a nova versao pode executar sem provisioned concurrency, com possibilidade de cold start; thresholds e `evaluation_periods` foram definidos considerando esse comportamento.
- Auto rollback por `DEPLOYMENT_FAILURE` e `DEPLOYMENT_STOP_ON_ALARM`.
- Rollback de emergencia usa `aws lambda update-alias` direto para retorno imediato da versao `stable`, sem esperar janela de canary.
- O smoke test pos-promocao e uma verificacao final do endpoint; a decisao de auto-rollback ja foi tomada durante o canary com trafego real.

## Contrato de imagens

- Este repositório de infraestrutura nao builda imagem Docker.
- O repositório de aplicacao deve buildar, escanear e publicar no ECR.
- A promocao usa imagem imutavel com digest (`@sha256`) em `vars.LAMBDA_IMAGE_URI` e `vars.PROCESSOR_IMAGE_URI`.

## Escopo

- O RDS e provisionado em stack separada por ter ciclo de vida distinto (dados vs aplicacao), alinhado ao item B.1 do edital.
- Este repositorio provisiona e opera a camada de aplicacao e processamento, consumindo `db_secret_arn` e o acesso de rede ao banco.

## Escolha IaC

- O edital prefere CDK, mas a implementacao usa Terraform por especialidade operacional em ambientes de producao e estrategia multi-conta/multi-regiao com modulos reutilizaveis.

## Cobertura do desafio

- API <= 150ms P99: Lambda com alias `stable`, provisioned concurrency em prod e alarme de latencia.
- Processamento longo (10-40 min): ECS Fargate + SQS com visibility timeout de 45 min + DLQ.
- Idempotencia/estado: DynamoDB para estado por `transaction_id` com TTL.
- Borda segura: CloudFront com OAC e bucket S3 privado (sem acesso publico direto).
- Isolamento e promocao: ambientes dev/staging/prod separados em `environments/` com backends de state isolados.
- IaC: Terraform modular em `modules/` e composicao por ambiente em `environments/`.
- Observabilidade: CloudWatch Logs, Metric Alarms e dashboards/metricas para Lambda, SQS e ECS.
- CI/CD: validacao de PR (`terraform-plan.yml`) e deploy sequencial com gates (`terraform-apply.yml`).
- Zero-downtime e rollback: CodeDeploy canary para Lambda em prod com rollback automatico/manual.

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

## Configuracao do GitHub Actions

- Secrets por environment (`dev`, `staging`, `prod`): `AWS_ROLE_ARN`, `DB_SECRET_ARN`, `SNS_ALERT_ARN`.
- Secrets do repositorio: `AWS_ACCOUNT_ID`.
- Variables do repositorio: `LAMBDA_IMAGE_URI`, `PROCESSOR_IMAGE_URI` com digest `@sha256`.
- Criar os environments `dev`, `staging` e `prod` em Settings > Environments.
- Em `prod`, habilitar required reviewers como gate de aprovacao.

## Notas praticas

- Os ambientes usam os mesmos modulos; o que muda sao os `terraform.tfvars`.
- Antes de abrir PR, rode `terraform fmt -check -recursive` e `terraform validate`.

