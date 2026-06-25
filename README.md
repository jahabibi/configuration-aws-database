# AWS Database Configuration

This repository contains an Upbound project, tailored for users establishing their initial control plane with [Upbound](https://cloud.upbound.io). This configuration deploys fully managed AWS database instances through a provider-agnostic `DataStore` API.

## Overview

The core components of a custom API in [Upbound Project](https://docs.upbound.io/learn/control-plane-project/) include:

- **CompositeResourceDefinition (XRD):** Defines the API's structure.
- **Composition(s):** Configures the Functions Pipeline
- **Embedded Function(s):** Encapsulates the Composition logic and implementation within a self-contained, reusable unit

In this specific configuration, the API contains:

- **a [DataStore](/apis/sqlinstances/definition.yaml) custom resource type.**
- **Composition:** Configured in [/apis/sqlinstances/composition.yaml](/apis/sqlinstances/composition.yaml)
- **Embedded Function:** The Composition logic is encapsulated within the [embedded function](/functions/sqlinstance/main.k)

## The DataStore API

`DataStore` provisions a managed relational database while keeping
provider/Crossplane machinery out of the consumer-facing API surface — it
expresses *intent* ("CreateDatabase"), not implementation ("CreateRDSInstance").
The mapping to RDS resources and instance classes is an L3 concern owned by the
composition.

Key fields:

| Field | Description |
| --- | --- |
| `region` | Cloud region, e.g. `us-west-2`. |
| `engine` | Database engine (`postgres`, `mariadb`). Adding an engine is an additive enum value, not a new API. |
| `engineVersion` | Database engine version. |
| `size` | Capacity intent (`small`, `medium`, `large`, default `small`). The composition maps this to the current right instance class; consumers never name a provider instance class. |
| `storageGB` | Allocated storage in GiB. |
| `reclaimPolicy` | Outcome intent using Kubernetes PersistentVolume vocabulary (`Delete`, `Retain`, default `Delete`). `Retain` leaves the database in place when the composite is deleted; the composition maps this to Crossplane management policies. |
| `networkRef.id` | Reference, by platform id, to the `Network` this database is placed in. Resolved in L3 from the Network's published status — private subnets + security group. |
| `passwordSecretRef` | Reference to the Secret holding the database password. |
| `autoGeneratePassword` | Whether to auto-generate the database password. |
| `overrides.providerConfigName` | Bounded escape hatch for account/credential selection (defaults to `default`). |

The composite publishes a structured `status` (`endpoint`, `host`) for
consumers and observability; credentials are delivered via the connection
secret.

### What changed in this rework

This configuration was reworked to remove leaky APIs:

- **Renamed `SQLInstance` → `DataStore`** (plural `datastores`) to name the
  intent rather than the implementation.
- **Removed Crossplane machinery from the API:** `managementPolicies` is gone,
  replaced by the intent-based `reclaimPolicy` (`Delete`/`Retain`). The raw
  `providerConfigName` moved under a bounded `overrides` block.
- **Added `size` capacity intent** that the composition maps to an instance
  class, instead of exposing provider instance classes directly.
- **Network wiring via published status, not MR labels:** the function resolves
  the referenced `Network` through extra-resources and reads its `status`
  (`zones[].privateSubnetId`, `securityGroupId`) to place explicit subnet IDs
  and security groups, rather than coupling to provider-MR label selectors.
- **Bumped `configuration-aws-network`** to `v3.0.0-dev.11` (the version that
  publishes the Network status contract this configuration consumes).

## Testing

The configuration can be tested using:

- `up composition render --xrd=apis/sqlinstances/definition.yaml apis/sqlinstances/composition.yaml examples/sqlinstance/mariadb-xr.yaml` to render the MariaDB composition
- `up composition render --xrd=apis/sqlinstances/definition.yaml apis/sqlinstances/composition.yaml examples/sqlinstance/postgres-xr.yaml` to render the PostgreSQL composition
- `up test run tests/*` to run composition tests
- `up test run tests/* --e2e` to run end-to-end tests

## Deployment

- Execute `up project run`
- Alternatively, install the Configuration from the [Upbound Marketplace](https://marketplace.upbound.io/configurations/upbound/configuration-aws-database)
- Check [examples](/examples/) for example XR(Composite Resource)

## Next steps

This repository serves as a foundational step. To enhance the configuration, consider:

1. create new API definitions in this same repo
2. editing the existing API definition to your needs

To learn more about how to build APIs for your managed control planes in Upbound, read the guide on [Upbound's docs](https://docs.upbound.io/).
