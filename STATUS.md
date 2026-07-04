# Status do projeto

Atualizado em 2026-07-03.

## Implementado

- Estrutura Terraform com modulos reutilizaveis em [modules](modules)
- Ambientes separados em [environments/dev](environments/dev), [environments/staging](environments/staging) e [environments/prod](environments/prod)
- Backend remoto de state via [bootstrap/main.tf](bootstrap/main.tf)
- Pipeline CI/CD em [ .github/workflows/terraform-plan.yml ](.github/workflows/terraform-plan.yml) e [ .github/workflows/terraform-apply.yml ](.github/workflows/terraform-apply.yml)

## Ajustes recentes

- Correcao de sintaxe HCL nos arquivos de variaveis dos modulos
- Reducao de documentacao redundante para manter o repositorio mais objetivo

## Pendencias praticas

- Trocar placeholders `ACCOUNT_ID` e ARNs de exemplo nos `terraform.tfvars`
- Validar deploy real por ambiente (`terraform plan` e `terraform apply`)
