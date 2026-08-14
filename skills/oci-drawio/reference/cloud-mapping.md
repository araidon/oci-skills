# AWS / Azure → OCI サービス対応

他クラウドの構成図（画像・XML・説明文）から OCI 構成図へ変換するときの対応表。

**このマッピングは自動適用されない。** `components/aliases.json` は OCI 内の別名だけを
扱う。変換時はここを見て、OCI 側のコンポーネント名を選ぶこと。

1:1 で対応しないものが多いので、対応表を出力するときは「差異・注意点」も必ず添える
（`reference/explanation.md`）。

---

## ネットワーク

| AWS | Azure | OCI | 備考 |
|---|---|---|---|
| VPC | VNet | `VCN` | |
| Subnet | Subnet | Subnet（コンテナ） | OCI は Regional Subnet が既定。AZ単位ではない |
| Internet Gateway | — | `Internet Gateway` | |
| NAT Gateway | NAT Gateway | `NAT Gateway` | |
| VPC Endpoint (Gateway) | Service Endpoint | `Service Gateway` | OCI は Service Gateway 1つで OCI サービス全体に到達 |
| PrivateLink | Private Endpoint | `Private Endpoint IP` | |
| Transit Gateway | Virtual WAN | `DRG` | OCI は DRG が VCN間・オンプレ接続を一手に担う |
| VPC Peering | VNet Peering | `Local Peering Gateway` / `Remote Peering` | 同一リージョン=LPG、跨ぎ=RPC |
| Direct Connect | ExpressRoute | `CPE` + `DRG` | FastConnect は CPE アイコンで表現 |
| Site-to-Site VPN | VPN Gateway | `CPE` + `DRG` | |
| ALB / NLB | Application Gateway / Load Balancer | `Load Balancer` / `Flexible Load Balancer` | L7=Load Balancer, L4=Flexible(Network) LB |
| Route 53 | Azure DNS | `DNS` | |
| CloudFront | Front Door / CDN | `CDN` | |
| Security Group | NSG | `NSG` | |
| NACL | — | `Security List` | |

## コンピュート

| AWS | Azure | OCI |
|---|---|---|
| EC2 | Virtual Machine | `VM Instance` |
| EC2 Dedicated Host / Bare Metal | Bare Metal | `Bare Metal` |
| Auto Scaling Group | VM Scale Set | `Autoscaling` / `Instance Pools` |
| Lambda | Functions | `Functions` |
| ECS / Fargate | Container Instances | `Container Instances` |
| EKS | AKS | `OKE` |
| ECR | Container Registry | `OCIR` |

## ストレージ

| AWS | Azure | OCI |
|---|---|---|
| S3 | Blob Storage | `Object Storage` / `Buckets` |
| EBS | Managed Disk | `Block Volume` |
| EFS | Azure Files | `File Storage` |
| Storage Gateway | — | `Storage Gateway` |
| Glacier | Archive Storage | `Object Storage`（Archive 階層。ラベルで補足） |

## データベース

| AWS | Azure | OCI |
|---|---|---|
| RDS (Oracle) | — | `DB System` |
| RDS (MySQL) | Database for MySQL | `MySQL DB System` / `MySQL HeatWave` |
| RDS (PostgreSQL) | Database for PostgreSQL | `PostgreSQL Cache` |
| Aurora | SQL Database | `Autonomous Database` |
| Redshift | Synapse | `Autonomous Database Warehouse` |
| DynamoDB | Cosmos DB | `NoSQL Database` |
| ElastiCache | Cache for Redis | `PostgreSQL Cache`（近似。注記が必要） |
| OpenSearch Service | Cognitive Search | `OpenSearch` |
| DMS | Database Migration Service | `Database Migration` |

## セキュリティ / ID

| AWS | Azure | OCI |
|---|---|---|
| IAM | Entra ID | `IAM` / `Identity` / `Policies` |
| Organizations / 複数アカウント | Management Group / Subscription | `Compartments` |
| KMS | Key Vault | `Vault` / `Key Management` |
| Secrets Manager | Key Vault | `Vault` |
| WAF | WAF | `WAF` |
| Shield | DDoS Protection | `DDoS Protection` |
| GuardDuty / Security Hub | Defender for Cloud | `Cloud Guard` |
| Inspector | Defender | `Vulnerability Scanning` |
| ACM | App Service Certificate | `Certificates` |
| Systems Manager Session Manager / 踏み台EC2 | Bastion | `Bastion` |

## 運用 / 連携

| AWS | Azure | OCI |
|---|---|---|
| CloudWatch (metrics) | Monitor | `Monitoring` / `Alarms` |
| CloudWatch Logs | Log Analytics | `Logging` / `Logging Analytics` |
| CloudTrail | Activity Log | `Auditing` |
| SNS | Event Grid / Notification Hubs | `Notifications` |
| SQS | Service Bus / Queue Storage | `Queuing` |
| Kinesis | Event Hubs | `Streaming` |
| EventBridge | Event Grid | `Events` |
| Step Functions | Logic Apps | `Logic Flow` / `Process Automation` |
| CloudFormation | ARM / Bicep | `Resource Manager` |
| CodePipeline | Azure DevOps | `DevOps` |
| API Gateway | API Management | `API Gateway` |
| SES | Communication Services | `Email Delivery` |
| Glue | Data Factory | `Data Integration` |
| SageMaker | Machine Learning | `Data Science` |
| Bedrock | Azure OpenAI | `Generative AI` |

---

## 構成パターンの読み替え

| 元の設計 | OCI での表現 |
|---|---|
| マルチアカウント / サブスクリプション分割 | コンパートメント分割（`Compartments`） |
| Transit Gateway ハブ&スポーク | DRG を中心にした VCN 接続 |
| AZ をまたぐ冗長化 | Fault Domain / Availability Domain。図では枠を描かず、アイコンを複数並べてラベルで示す |
| 踏み台 EC2 | マネージドな `Bastion` サービスに置き換える |
| VPC Endpoint を各サービスごとに配置 | `Service Gateway` 1つに集約 |
| ALB + NAT + IGW | OCI も同構成。ただし Service Gateway で OCI サービス向け通信を分離する |

## 変換時の注意

- **AZ の粒度が違う**: AWS の AZ ≒ OCI の Availability Domain だが、東京など AD が1つの
  リージョンがある。冗長化は Fault Domain で表現する
- **サブネットが Regional**: OCI のサブネットは既定でリージョナル。AZ ごとにサブネットを
  切る AWS の図をそのまま持ち込まない
- **Security List と NSG が併存**: AWS の SG は NSG に相当。NACL 相当が Security List
- **1:1 でないものは注記する**: ElastiCache、Step Functions などは近似なので、
  変換表に「完全な等価ではない」と明記すること
