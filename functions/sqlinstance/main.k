import models.io.upbound.awsm.rds.v1beta1 as rdsv1beta1
import models.io.upbound.platform.aws.v1alpha1 as awsv1alpha1
import models.k8s.apimachinery.pkg.apis.meta.v1 as metav1

import base64

oxr = option("params").oxr # observed composite resource
_ocds = option("params").ocds # observed composed resources
_dxr = option("params").dxr # desired composite resource
dcds = option("params").dcds # desired composed resources

params = oxr.spec.parameters

# reclaimPolicy (PV vocabulary) -> Crossplane management policies; size intent
# -> instance class. The consumer contract speaks Kubernetes/capacity; only L3
# speaks Crossplane machinery / provider instance classes.
_reclaimPolicy = params?.reclaimPolicy or "Delete"
_managementPolicies = ["Create", "Observe", "Update", "LateInitialize"] if _reclaimPolicy == "Retain" else ["*"]
_providerConfigName = params?.overrides?.providerConfigName or "default"
_sizeToInstanceClass = {small = "db.t3.micro", medium = "db.t3.medium", large = "db.t3.large"}
_instanceClass = _sizeToInstanceClass[params?.size or "small"]

# Inter-domain wiring: resolve the referenced Network from its published status
# contract (Network.status) instead of reaching around it with provider-MR
# label selectors. SQLInstance is used standalone (no composing parent to
# inject placement), so per the layered design the L3 function fetches the
# Network XR via extra-resources, keyed by networkRef.id (== the Network name),
# and reads the AZ-structured zones[] + the default securityGroupId.
_extra = option("params").extraResources or {}
_networkXRs = _extra?["network"] or []
_networkXR = _networkXRs[0] if len(_networkXRs) > 0 else {}
_netStatus = _networkXR?.Resource?.status or _networkXR?.status or {}
_zones = _netStatus?.zones or []
_privateSubnetIds = [z.privateSubnetId for z in _zones if z?.privateSubnetId]
_securityGroupId = _netStatus?.securityGroupId or ""

_defaults = {
    managementPolicies = _managementPolicies
    providerConfigRef = {
        kind = "ProviderConfig"
        name = _providerConfigName
    }
    forProvider.region = params.region
}

_metadata = lambda name: str -> any {
    { annotations = { "krm.kcl.dev/composition-resource-name" = name }}
}

_items = [
    # Request the referenced Network XR so we can read its published status
    # (the inter-domain contract). Resolved by name == networkRef.id.
    {
        apiVersion: "meta.krm.kcl.dev/v1alpha1"
        kind: "ExtraResources"
        requirements: {
            "network": {
                apiVersion: "aws.platform.upbound.io/v1alpha1"
                kind: "Network"
                matchName: params.networkRef.id
            }
        }
    }
    rdsv1beta1.SubnetGroup{
        metadata: _metadata("compositeSQLInstanceDbSubnetGroup")
        spec = _defaults | {
            forProvider: {
                description = "An excellent formation of subnetworks."
                # Explicit private subnet IDs from Network.status.zones[]
                # (resolved via extra-resources); no MR-label coupling.
                subnetIds = _privateSubnetIds
            }
        }
    }
    rdsv1beta1.Instance{
        metadata: _metadata("RDSInstanceSmall")
        spec: _defaults | {
            forProvider: {
                dbName = "upbound"
                dbSubnetGroupNameSelector.matchControllerRef = True
                instanceClass = _instanceClass
                publiclyAccessible = False
                skipFinalSnapshot = True
                username = "masteruser"
                engine = params.engine
                engineVersion = params.engineVersion
                allocatedStorage = params.storageGB
                # Default security group from Network.status.securityGroupId.
                vpcSecurityGroupIds = [_securityGroupId] if _securityGroupId else []
                autoGeneratePassword = params.autoGeneratePassword
                passwordSecretRef = {
                    name = params.passwordSecretRef.name
                    key = params.passwordSecretRef.key

                }
            }
            writeConnectionSecretToRef = {
                name = "{}-sql".format(oxr.metadata.name)
            }
        }
    }

    {
        apiVersion: "meta.krm.kcl.dev/v1alpha1"
        kind: "CompositeConnectionDetails"
        if "RDSInstanceSmall" in _ocds:
            data: {
                endpoint = _ocds["RDSInstanceSmall"].Resource?.status?.atProvider?.endpoint
                host = _ocds["RDSInstanceSmall"].Resource?.status?.atProvider?.address
                username = base64.encode(_ocds["RDSInstanceSmall"].Resource?.spec?.forProvider?.username)
                password = _ocds["RDSInstanceSmall"].ConnectionDetails.password
            }
        else:
            data: {}
    }
]

# Structured status (non-sensitive; credentials go to the connection secret).
_dxr = _dxr | {
    status: {
        if _ocds?["RDSInstanceSmall"]?.Resource?.status?.atProvider?.endpoint:
            endpoint = _ocds["RDSInstanceSmall"].Resource.status.atProvider.endpoint
        if _ocds?["RDSInstanceSmall"]?.Resource?.status?.atProvider?.address:
            host = _ocds["RDSInstanceSmall"].Resource.status.atProvider.address
    }
}
_items += [_dxr]

items = _items
