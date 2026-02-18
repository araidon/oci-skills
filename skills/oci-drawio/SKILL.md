---
name: oci-drawio
description: Generate and edit OCI architecture diagrams in draw.io (.drawio) format. Use this skill when asked to create, update, or modify OCI architecture diagrams.
---

# OCI draw.io Diagram Skill

Generate and edit Oracle Cloud Infrastructure (OCI) architecture diagrams in draw.io (.drawio) format.

## Prerequisites

Run `setup.sh` once before first use to download official OCI icons and generate the draw.io shape library:

```bash
cd <skill-directory>/skills/oci-drawio
bash setup.sh
```

This generates:
- `icons/oci-shapes.xml` — draw.io custom shape library (for GUI drag-and-drop)
- `components/oci_components.json` — component dictionary (for programmatic generation)

## How to Use This Skill

When asked to create or edit an OCI architecture diagram:

1. Read `components/oci_components.json` to look up available components and their `style` strings
2. Generate `.drawio` XML following the structure and rules below
3. Save the output as a `.drawio` file

When editing an existing `.drawio` file:

1. Read the existing file as XML
2. Parse the `<mxCell>` elements to understand the current diagram
3. Add, modify, or remove `<mxCell>` elements as needed
4. Write the modified XML back to the file

---

## draw.io XML Structure

Every `.drawio` file follows this structure:

```xml
<mxfile host="Electron" modified="2024-01-01T00:00:00.000Z" type="device">
  <diagram id="diagram-1" name="OCI Architecture">
    <mxGraphModel dx="1024" dy="768" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1600" pageHeight="900" math="0" shadow="0">
      <root>
        <mxCell id="0"/>
        <mxCell id="1" parent="0"/>
        <!-- All diagram elements go here -->
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
```

### mxCell Element Types

**Container (group/box):**
```xml
<mxCell id="region-1" value="Japan East (Tokyo)" style="..." vertex="1" parent="1">
  <mxGeometry x="20" y="20" width="1200" height="700" as="geometry"/>
</mxCell>
```

**Icon (service/resource):**
```xml
<mxCell id="vm-1" value="App Server" style="{{style from oci_components.json}}" vertex="1" parent="subnet-pub-1">
  <mxGeometry x="120" y="60" width="60" height="60" as="geometry"/>
</mxCell>
```

**Connection (line):**
```xml
<mxCell id="conn-1" style="endArrow=none;startArrow=none;" edge="1" source="igw-1" target="lb-1" parent="1">
  <mxGeometry relative="1" as="geometry"/>
</mxCell>
```

### ID Naming Convention

Use descriptive IDs: `region-1`, `vcn-1`, `subnet-pub-1`, `subnet-priv-1`, `igw-1`, `nat-1`, `drg-1`, `sgw-1`, `lb-1`, `vm-1`, `db-1`, `conn-1`, etc.

### Parent-Child Relationships

Elements inside a container must have `parent` set to the container's `id`:
- Icons inside a Subnet → `parent="subnet-pub-1"`
- Subnets inside a VCN → `parent="vcn-1"`
- VCN inside Region → `parent="region-1"`
- Gateways on VCN border → `parent="vcn-1"` (positioned on the edge)

Connections always use `parent="1"` (root).

---

## Container Styles

### Region
```
rounded=1;whiteSpace=wrap;html=1;arcSize=0;strokeColor=#D04A02;fillColor=#FFFFFF;dashed=0;verticalAlign=top;align=left;spacingLeft=10;fontStyle=1;fontSize=14;
```

### VCN
```
rounded=1;whiteSpace=wrap;html=1;arcSize=0;strokeColor=#878787;fillColor=#F5F5F5;dashed=0;verticalAlign=top;align=left;spacingLeft=10;fontStyle=1;fontSize=12;
```

### Public Subnet
```
rounded=1;whiteSpace=wrap;html=1;arcSize=0;strokeColor=#878787;fillColor=#FFFFFF;dashed=0;verticalAlign=top;align=left;spacingLeft=10;fontSize=11;
```

### Private Subnet
```
rounded=1;whiteSpace=wrap;html=1;arcSize=0;strokeColor=#878787;fillColor=#EFEFEF;dashed=0;verticalAlign=top;align=left;spacingLeft=10;fontSize=11;
```

---

## OCI Layout Rules

### Hierarchy (AD notation is not needed)

```
┌─ Region ──────────────────────────────────────────────────────┐
│  ┌─ VCN ──────────────────────────────────┐                   │
│  │                                         │                   │
│ [IGW]  ┌─ Public Subnet ─────────────┐   [SGW]  [Object Storage]│
│ [NAT]  │  [LB]  [Bastion]  ...       │    │     [Vault]        │
│ [DRG]  └─────────────────────────────┘    │     [OCIR]         │
│  │     ┌─ Private Subnet ────────────┐    │     [Streaming]    │
│  │     │  [App]  [DB]  ...           │    │     ...            │
│  │     └─────────────────────────────┘    │                   │
│  └─────────────────────────────────────────┘                   │
└───────────────────────────────────────────────────────────────┘
```

### Gateway Placement

| Gateway           | Position                                |
|--------------------|-----------------------------------------|
| Internet Gateway   | VCN left border (straddle the border)   |
| NAT Gateway        | VCN left border (below IGW)             |
| DRG                | VCN left border (below NAT)             |
| Service Gateway    | VCN right border (straddle the border)  |

Gateway icons are placed so their center aligns with the VCN border line.

### Regional Services (outside VCN)

Services not inside VCN are placed inside the Region box, to the right of the VCN, stacked vertically starting next to the Service Gateway.

Examples: Object Storage, Vault, Autonomous Database (without private endpoint), OCIR, Streaming, Notifications, Queue, IAM, Logging, Monitoring.

### Connection Lines

- No arrowheads: `endArrow=none;startArrow=none;`
- IGW/NAT/DRG connect horizontally to services in subnets via the VCN left border
- SGW connects horizontally to regional services via the VCN right border
- Line style: `endArrow=none;startArrow=none;`

---

## Grid System & Coordinates

| Parameter                | Value  |
|--------------------------|--------|
| Container padding        | 20px   |
| Icon size                | 60×60px|
| Icon spacing (center-to-center) | 100px  |
| Label position           | Below icon |
| Grid snap                | 10px   |

### Typical Coordinates

For an 1200×700 Region:

```
Region:       x=20,  y=20,  w=1200, h=700
VCN:          x=20,  y=40,  w=860,  h=640   (inside Region, relative coords)
Public Sub:   x=120, y=40,  w=620,  h=260   (inside VCN, relative)
Private Sub:  x=120, y=340, w=620,  h=260   (inside VCN, relative)
IGW:          x=-10, y=80,  w=60,   h=60    (on VCN left border, x=-10 to straddle)
NAT:          x=-10, y=200, w=60,   h=60
DRG:          x=-10, y=320, w=60,   h=60
SGW:          x=820, y=80,  w=60,   h=60    (on VCN right border)
```

Regional services (inside Region, right of VCN):
```
Service 1:    x=920, y=80,  w=60,   h=60    (relative to Region)
Service 2:    x=920, y=180, w=60,   h=60
Service 3:    x=920, y=280, w=60,   h=60
```

---

## Using oci_components.json

Read `components/oci_components.json` to get the `style` for each component:

```python
import json

with open("components/oci_components.json") as f:
    components = json.load(f)

# Get style for a Load Balancer
lb_style = components["Load Balancer"]["style"]
```

Available component keys (non-exhaustive):

**Networking:** VCN, Subnet, Internet Gateway, NAT Gateway, Service Gateway, DRG, Load Balancer, Network Load Balancer, DNS, FastConnect, VPN

**Compute:** VM Instance, Bare Metal, Autoscaling, Instance Pools, Functions

**Database:** Autonomous Database, MySQL HeatWave, DB System, Exadata

**Storage:** Object Storage, Block Volume, File Storage, Buckets

**Security:** WAF, Network Firewall, Vault, Bastion, IAM

**Container:** OKE, Container Instances, OCIR

**Monitoring:** Streaming, Notifications, Logging, Monitoring

---

## Complete Example: Basic Web 3-Tier

```xml
<mxfile host="Electron" modified="2024-01-01T00:00:00.000Z" type="device">
  <diagram id="d1" name="OCI 3-Tier Web Architecture">
    <mxGraphModel dx="1024" dy="768" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1600" pageHeight="900" math="0" shadow="0">
      <root>
        <mxCell id="0"/>
        <mxCell id="1" parent="0"/>

        <!-- Region -->
        <mxCell id="region-1" value="Japan East (Tokyo)" style="rounded=1;whiteSpace=wrap;html=1;arcSize=0;strokeColor=#D04A02;fillColor=#FFFFFF;dashed=0;verticalAlign=top;align=left;spacingLeft=10;fontStyle=1;fontSize=14;" vertex="1" parent="1">
          <mxGeometry x="20" y="20" width="1200" height="700" as="geometry"/>
        </mxCell>

        <!-- VCN -->
        <mxCell id="vcn-1" value="VCN (10.0.0.0/16)" style="rounded=1;whiteSpace=wrap;html=1;arcSize=0;strokeColor=#878787;fillColor=#F5F5F5;dashed=0;verticalAlign=top;align=left;spacingLeft=10;fontStyle=1;fontSize=12;" vertex="1" parent="region-1">
          <mxGeometry x="20" y="40" width="860" height="640" as="geometry"/>
        </mxCell>

        <!-- Public Subnet -->
        <mxCell id="subnet-pub-1" value="Public Subnet (10.0.1.0/24)" style="rounded=1;whiteSpace=wrap;html=1;arcSize=0;strokeColor=#878787;fillColor=#FFFFFF;dashed=0;verticalAlign=top;align=left;spacingLeft=10;fontSize=11;" vertex="1" parent="vcn-1">
          <mxGeometry x="120" y="40" width="620" height="260" as="geometry"/>
        </mxCell>

        <!-- Private Subnet -->
        <mxCell id="subnet-priv-1" value="Private Subnet (10.0.2.0/24)" style="rounded=1;whiteSpace=wrap;html=1;arcSize=0;strokeColor=#878787;fillColor=#EFEFEF;dashed=0;verticalAlign=top;align=left;spacingLeft=10;fontSize=11;" vertex="1" parent="vcn-1">
          <mxGeometry x="120" y="340" width="620" height="260" as="geometry"/>
        </mxCell>

        <!-- Gateways (use styles from oci_components.json) -->
        <!-- IGW on VCN left border -->
        <mxCell id="igw-1" value="Internet Gateway" style="{{Internet Gateway style}}" vertex="1" parent="vcn-1">
          <mxGeometry x="-10" y="80" width="60" height="60" as="geometry"/>
        </mxCell>

        <!-- NAT on VCN left border -->
        <mxCell id="nat-1" value="NAT Gateway" style="{{NAT Gateway style}}" vertex="1" parent="vcn-1">
          <mxGeometry x="-10" y="200" width="60" height="60" as="geometry"/>
        </mxCell>

        <!-- SGW on VCN right border -->
        <mxCell id="sgw-1" value="Service Gateway" style="{{Service Gateway style}}" vertex="1" parent="vcn-1">
          <mxGeometry x="820" y="80" width="60" height="60" as="geometry"/>
        </mxCell>

        <!-- Load Balancer in Public Subnet -->
        <mxCell id="lb-1" value="Load Balancer" style="{{Load Balancer style}}" vertex="1" parent="subnet-pub-1">
          <mxGeometry x="60" y="100" width="60" height="60" as="geometry"/>
        </mxCell>

        <!-- Web Servers in Public Subnet -->
        <mxCell id="web-1" value="Web Server 1" style="{{VM Instance style}}" vertex="1" parent="subnet-pub-1">
          <mxGeometry x="220" y="100" width="60" height="60" as="geometry"/>
        </mxCell>
        <mxCell id="web-2" value="Web Server 2" style="{{VM Instance style}}" vertex="1" parent="subnet-pub-1">
          <mxGeometry x="340" y="100" width="60" height="60" as="geometry"/>
        </mxCell>

        <!-- App Servers in Private Subnet -->
        <mxCell id="app-1" value="App Server 1" style="{{VM Instance style}}" vertex="1" parent="subnet-priv-1">
          <mxGeometry x="60" y="100" width="60" height="60" as="geometry"/>
        </mxCell>
        <mxCell id="app-2" value="App Server 2" style="{{VM Instance style}}" vertex="1" parent="subnet-priv-1">
          <mxGeometry x="180" y="100" width="60" height="60" as="geometry"/>
        </mxCell>

        <!-- Database in Private Subnet -->
        <mxCell id="db-1" value="Oracle DB" style="{{Autonomous Database style}}" vertex="1" parent="subnet-priv-1">
          <mxGeometry x="400" y="100" width="60" height="60" as="geometry"/>
        </mxCell>

        <!-- Regional Service: Object Storage -->
        <mxCell id="objst-1" value="Object Storage" style="{{Object Storage style}}" vertex="1" parent="region-1">
          <mxGeometry x="920" y="80" width="60" height="60" as="geometry"/>
        </mxCell>

        <!-- Connections (no arrows) -->
        <mxCell id="conn-1" style="endArrow=none;startArrow=none;" edge="1" source="igw-1" target="lb-1" parent="1">
          <mxGeometry relative="1" as="geometry"/>
        </mxCell>
        <mxCell id="conn-2" style="endArrow=none;startArrow=none;" edge="1" source="lb-1" target="web-1" parent="1">
          <mxGeometry relative="1" as="geometry"/>
        </mxCell>
        <mxCell id="conn-3" style="endArrow=none;startArrow=none;" edge="1" source="lb-1" target="web-2" parent="1">
          <mxGeometry relative="1" as="geometry"/>
        </mxCell>
        <mxCell id="conn-4" style="endArrow=none;startArrow=none;" edge="1" source="web-1" target="app-1" parent="1">
          <mxGeometry relative="1" as="geometry"/>
        </mxCell>
        <mxCell id="conn-5" style="endArrow=none;startArrow=none;" edge="1" source="web-2" target="app-2" parent="1">
          <mxGeometry relative="1" as="geometry"/>
        </mxCell>
        <mxCell id="conn-6" style="endArrow=none;startArrow=none;" edge="1" source="app-1" target="db-1" parent="1">
          <mxGeometry relative="1" as="geometry"/>
        </mxCell>
        <mxCell id="conn-7" style="endArrow=none;startArrow=none;" edge="1" source="app-2" target="db-1" parent="1">
          <mxGeometry relative="1" as="geometry"/>
        </mxCell>
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
```

> **Note:** Replace `{{Component style}}` with actual `style` values from `oci_components.json`.

---

## Output

- Save files with `.drawio` extension
- The file can be opened directly in [draw.io desktop](https://github.com/jgraph/drawio-desktop) or [draw.io web](https://app.diagrams.net/)
- Default save location: current working directory, or as specified by the user
