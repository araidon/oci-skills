# コンポーネント一覧

> このファイルは `scripts/gen_component_list.py` が `components/index.json` から
> 生成する。手で編集しないこと。

全 234 コンポーネント / 13 カテゴリ / 別名 114 件（`components/aliases.json`）

コンポーネント名は `components/{カテゴリ}.json` のキーと一致する。
名前の解決には別名・略称・部分一致も使えるので、
`python3 scripts/oci_components.py "<名前>"` で確認できる。

| カテゴリ | ファイル | 件数 | コンポーネント |
|---|---|---|---|
| **Analytics & AI** | `components/ai.json` | 20 | Analytics Cloud, Artificial Intelligence, Big Data, Data Catalog, Data Flow, Data Integration, Data Science, Digital Assistant, Document Understanding, Essbase, Forecasting, Generative AI, Language, Machine Learning, Message Listener, Message Producer, Service Connector Hub, Speech, Streaming, Vision |
| **Applications** | `components/applications.json` | 26 | BI Cloud Connector, CPQ, Cloud Operations, Digital Media, E-Business Suite, EPM, ERP, Engagement, Financials, Fusion, HCM, Innovation Management, Inventory Management, Manufacturing, Marketplace, Media Flow, Media Stream, Order Management, Process Automation, Procurement, Product Master Data Management, Project Financial Management, Project Management, SOA, Supply Chain Planning, Wellness-Healthcare |
| **Compute** | `components/compute.json` | 9 | Autoscaling, Bare Metal, Burstable VM, Flex VM, Functions, Instance Pools, VM GPU, VM Instance, Virtual Machine Application |
| **Database** | `components/database.json` | 48 | ADB Exadata Cloud at Customer, ADB-D Dedicated, ADW-D, ATP-D, Autonomous Database, Autonomous Database Warehouse, Autonomous Transaction Processing, DB System, Data Guard, Data Guard Recovery, Data Lake, Data Lakehouse, Data Safe, Database, Database Management, Database Migration Service, Database for Amazon Web Service AWS, Database for Azure Portal, Database for Google Cloud Platform GCP, Estate Explorer, Exadata, Exadata Cloud at Customer, Exadata Fleet Update, Flashback, GoldenGate, GoldenGate Application Adapter, GoldenGate Director, GoldenGate Free, GoldenGate HP Nonstop Guardian, GoldenGate Monitor, GoldenGate On-Premises, GoldenGate Plug-in, GoldenGate Stream Analytics, GoldenGate Studio, GoldenGate Veridata, Inter Region Latency, Migrate Autonomous Database, Migration Workbench, MySQL DB System, MySQL HeatWave, Network Path Analyzer, Network Visualizer, NoSQL Database, OpenSearch, PostgreSQL Cache, RAC, Technology - ADB-Exadata-Cloud-at-Customer-Technology, Technology - Exadata Cloud at Customer |
| **Developer Services（コンテナ含む）** | `components/developer.json` | 21 | APEX, API Gateway, API Service, Application Dependency Management, Container Instances, Container Service, Content Management, DevOps, Email Delivery, Integrations, Jet, Logic Flow, Multiple Containers, Notifications, OCIR, OKE, OKE Virtual Node, Private Endpoint IP, Resource Manager, Service Mesh, Visual Builder |
| **General** | `components/general.json` | 15 | Blockchain, Cloud Native Environment, Content Delivery Network Service, Cross Domain, Data Integrator, Internet Cloud, IoT, Other Cloud Services, Private Cloud, Remote Agent, Remote Peering, Transaction Manager, VM (Desktop), Virtual Machine Clear, Zero Data Loss Recovery Appliance |
| **Governance** | `components/governance.json` | 6 | Cloud Advisor, Cloud Migrations, License Manager, OCID, Organization, Tagging |
| **Hybrid / Multicloud** | `components/hybrid.json` | 5 | Dedicated Region, Roving Edge Device, Roving Edge Infrastructure, Roving Edge Service, Roving Edge Ultra |
| **Migration** | `components/migration.json` | 3 | Cloud Migration Advisor, Data Transfer, Database Migration |
| **Observability & Management** | `components/monitoring.json` | 14 | Alarms, Application Performance Monitoring, Auditing, Events, Full Stack Disaster Recovery, Health Check, Logging, Logging Analytics, Monitoring, Operations Insights, Queuing, Search, VCN Flow Logs, Workflow |
| **Networking** | `components/networking.json` | 22 | BYOIP, Backbone, CDN, CPE, DNS, DRG, Flexible Load Balancer, IP Pools, Internet Gateway, Load Balancer, Local Peering Gateway, NAT Gateway, Network Performance Inspector, Network Switch, On-Premises Data Center, Route Table, Route Table and Security List, Service Gateway, Services Network, VCN, VNIC, VTAP |
| **Identity & Security** | `components/security.json` | 27 | Active Directory, Bastion, Certificates, Cloud Guard, Compartments, DDoS Protection, Encryption, IAM, Identity, Key Management, Key Vault, Maximum Security Zone, NSG, Network Firewall, Policies, Security List, Threat Defense, Threat Intelligence, User, User Female, User Group, User Group Female, User Group Male, User Male, Vault, Vulnerability Scanning, WAF |
| **Storage** | `components/storage.json` | 18 | Backup/Restore, Block Storage Cloning, Block Storage Multiple, Block Volume, Buckets, Elastic Performance, File Storage, File Storage Clone, File Storage Cloning Process, File Storage Mount Target, File Storage Replica, File Storage Replication Process, File Storage Snapshot, Local Storage, Object Storage, Other - OCI File Storage Mount Target, Persistent Volume, Storage Gateway |

## 主な別名

`components/aliases.json` により、以下のような呼び方でも解決できる。

| 入力 | 解決先 |
|---|---|
| `VPC` | VCN |
| `IGW` | Internet Gateway |
| `NAT` | NAT Gateway |
| `SGW` | Service Gateway |
| `LB` | Load Balancer |
| `NLB` | Flexible Load Balancer |
| `ADB` | Autonomous Database |
| `ATP` | Autonomous Transaction Processing |
| `ADW` | Autonomous Database Warehouse |
| `OSS` | Object Storage |
| `FSS` | File Storage |
| `KMS` | Vault |
| `Kubernetes` | OKE |
| `Container Registry` | OCIR |
| `Virtual Machine` | VM Instance |
| `Site-to-Site VPN` | CPE |
| `Compartment` | Compartments |

