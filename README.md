# Mecânica DM - Gerenciamento Banco de Dados (Terraform)

Infrastructure as Code (IaC) para provisionamento e gerenciamento da camada de banco de dados PostgreSQL do sistema **Mecânica DM** na AWS.

Este repositório é parte do ecossistema **Mecânica DM v3**, responsável exclusivamente pela infraestrutura de banco de dados. A camada de aplicação (EKS, VPC, Lambda) é gerenciada pelo repositório [`mecanicadm-k8s-v3`](https://github.com/mecanica-dm/mecanicadm-k8s-v3).

## Documentação

### Componenetes de infraestrutura

![Componentes de infraestrutura](docs/assets/c4-componentes-infra-mecanicadm.png)

### Diagrama de Entidade-Relacionamento

[Link para imagem do diagrama](docs/assets/erd-mecanicadm.png)

```mermaid
erDiagram
    USERS ||--o{ USER_ROLES : "possui"
    USERS ||--o{ PASSWORD_RESET_TOKENS : "solicita"

    CLIENTS ||--o{ WORK_ORDERS : "possui"
    VEHICLE ||--o{ WORK_ORDERS : "é utilizado em"

    LABORS ||--o{ WORK_ORDER_LABOR_ITEMS : "é registrado em"
    MATERIALS ||--o{ WORK_ORDER_MATERIAL_ITEMS : "é usado em"
    MATERIALS ||--o{ STOCK_MOVEMENTS : "gera"

    WORK_ORDERS ||--o{ WORK_ORDER_LABOR_ITEMS : "tem"
    WORK_ORDERS ||--o{ WORK_ORDER_MATERIAL_ITEMS : "tem"
    WORK_ORDERS ||--o{ WORK_ORDER_BUDGETS : "tem"
    WORK_ORDERS ||--o{ STOCK_MOVEMENTS : "registra"
    WORK_ORDERS ||--o{ BUDGET_DECISION_TOKENS : "gera"

    USERS {
        uuid id PK
        timestamp date_created
        timestamp date_updated
        timestamp deleted_at
        varchar email UK
        varchar password
        varchar name
    }

    USER_ROLES {
        uuid user_id PK,FK
        varchar role PK
    }

    PASSWORD_RESET_TOKENS {
        uuid id PK
        varchar token UK
        uuid user_id FK
        timestamp expiry_date
    }

    VEHICLE {
        varchar license_plate PK
        varchar model
        varchar brand
        smallint model_year
        timestamp date_created
        timestamp date_updated
        timestamp deleted_at
    }

    CLIENTS {
        uuid id PK
        varchar name
        varchar email UK
        varchar document UK
        varchar phone
        timestamp date_created
        timestamp date_updated
        timestamp deleted_at
    }

    LABORS {
        uuid id PK
        varchar name
        decimal price
        timestamp date_created
        timestamp date_updated
        timestamp deleted_at
    }

    MATERIALS {
        uuid id PK
        varchar name
        varchar brand
        text description
        decimal price
        varchar type
        timestamp date_created
        timestamp date_updated
        timestamp deleted_at
    }

    WORK_ORDERS {
        uuid id PK
        uuid client_id FK
        varchar vehicle_id FK
        text description
        int status
        timestamp execution_start_at
        timestamp execution_end_at
        timestamp date_created
        timestamp date_updated
        timestamp deleted_at
    }

    WORK_ORDER_LABOR_ITEMS {
        uuid id PK
        uuid work_order_id FK
        uuid labor_id FK
        varchar status
        timestamp execution_start_at
        timestamp execution_end_at
    }

    WORK_ORDER_MATERIAL_ITEMS {
        uuid id PK
        uuid work_order_id FK
        uuid material_id FK
        int quantity
    }

    WORK_ORDER_BUDGETS {
        uuid work_order_id PK,FK
        decimal total_price
        varchar status
        text observation
    }

    STOCK_MOVEMENTS {
        uuid id PK
        uuid material_id FK
        uuid work_order_id FK
        int quantity
        varchar type
        timestamp date_created
        timestamp date_updated
        timestamp deleted_at
    }

    BUDGET_DECISION_TOKENS {
        uuid id PK
        uuid work_order_id FK
        varchar token UK
        boolean used
        timestamp created_at
    }
```

## Como Usar

### 1. Inicializar o Terraform

```bash
terraform init \
  -backend-config="bucket=<seu-bucket>" \
  -backend-config="key=mecanicadm-db-v3/terraform.tfstate" \
  -backend-config="region=us-east-1"
```

### 2. Planejar as mudanças

```bash
terraform plan -out=tfplan-prod
```

### 3. Aplicar as mudanças

```bash
terraform apply tfplan-prod
```

### 4. Destruir a infraestrutura

> ⚠️ **Atenção**: Utilize apenas quando necessário. A destruição remove todos os recursos e dados do banco.

```bash
terraform destroy
```

Ou utilize o workflow manual `destroy.yml` no GitHub Actions (requer digitar `DESTRUIR` como confirmação).

## CI/CD

### Pipeline Principal (`ci-cd.yml`)

Disparado em pushes para `main`, Pull Requests e dispatch manual:

```mermaid
flowchart LR
    A([push main / PR / manual]) --> B[Checkout]
    B --> C[Configurar Credenciais AWS]
    C --> D[Setup Terraform 1.8.0]
    D --> E[terraform init]
    E --> F[terraform fmt -check]
    F --> G[terraform validate]
    G --> H[terraform plan]
    H --> I{Aplicar?}
    I -- Sim --> J[terraform apply]
    I -- Nao --> K([Fim])
    J --> K
```

### Workflow de Destruição (`destroy.yml`)

Disparado apenas manualmente (`workflow_dispatch`):

```mermaid
flowchart LR
    A([Run Manual]) --> B{Confirmacao correta?}
    B -- Nao --> C([Abortado])
    B -- Sim --> D[Checkout]
    D --> E[Configurar Credenciais AWS]
    E --> F[Setup Terraform 1.8.0]
    F --> G[terraform init]
    G --> H[terraform destroy]
    H --> I[Verificar RDS orfaos]
    I --> J([Fim])
```

## Stack / Pré-requisitos

- [Terraform](https://www.terraform.io/downloads.html) >= 1.5.0
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configurado com credenciais válidas
- Acesso à AWS com permissões para criar recursos RDS, SSM, Secrets Manager, IAM, EC2 (Security Groups)
- O repositório [`mecanicadm-k8s-v3`](https://github.com/mecanica-dm/mecanicadm-k8s-v3) deve ter sido aplicado primeiro (fornece VPC, subnets e Security Groups via SSM)
