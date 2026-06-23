import models.io.upbound.awsm.rds.v1beta1 as rdsv1beta1
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.io.upbound.platform.aws.v1alpha1 as platformawsv1alpha1

# Stand-in for the referenced Network's published status contract, supplied as
# an extra resource so the composition resolves placement from Network.status
# (zones[] + securityGroupId) — exercising the same extra-resources path the
# function uses in-cluster. Untyped dict on purpose: it carries v3 status fields
# the (old) resolved Network model does not yet declare.
_networkExtra = {
    apiVersion = "aws.platform.upbound.io/v1alpha1"
    kind = "Network"
    metadata = {
        name = "configuration-aws-database"
        namespace = "default"
    }
    status = {
        networkId = "vpc-0test"
        securityGroupId = "sg-0test"
        zones = [
            {
                name = "us-west-2a"
                publicSubnetId = "subnet-pub-a"
                privateSubnetId = "subnet-priv-a"
            }
            {
                name = "us-west-2b"
                publicSubnetId = "subnet-pub-b"
                privateSubnetId = "subnet-priv-b"
            }
        ]
    }
}

_items = [
    metav1alpha1.CompositionTest{
        metadata.name: "TestMariaDB"
        spec = {
            assertResources: [
                platformawsv1alpha1.DataStore{
                    metadata = {
                        name = "configuration-aws-database-mariadb"
                        namespace = "default"
                    }
                    spec = {
                        parameters = {
                            autoGeneratePassword = True
                            engine = "mariadb"
                            engineVersion = "11.8.3"
                            networkRef = {
                                id = "configuration-aws-database"
                            }
                            passwordSecretRef = {
                                key = "password"
                                name = "mariadbsecret"
                            }
                            region = "us-west-2"
                            storageGB = 5
                        }
                    }
                }
                rdsv1beta1.Instance{
                    metadata = {
                        annotations = {
                            "crossplane.io/composition-resource-name" = "RDSInstanceSmall"
                        }
                        generateName = "configuration-aws-database-mariadb-"
                        labels = {
                            "crossplane.io/composite" = "configuration-aws-database-mariadb"
                        }
                        ownerReferences = [
                            {
                                apiVersion = "aws.platform.upbound.io/v1alpha1"
                                blockOwnerDeletion = True
                                controller = True
                                kind = "DataStore"
                                name = "configuration-aws-database-mariadb"
                                uid = ""
                            }
                        ]
                    }
                    spec = {
                        forProvider = {
                            allocatedStorage = 5
                            autoGeneratePassword = True
                            dbName = "upbound"
                            dbSubnetGroupNameSelector = {
                                matchControllerRef = True
                            }
                            engine = "mariadb"
                            engineVersion = "11.8.3"
                            instanceClass = "db.t3.micro"
                            passwordSecretRef = {
                                key = "password"
                                name = "mariadbsecret"
                            }
                            publiclyAccessible = False
                            region = "us-west-2"
                            skipFinalSnapshot = True
                            username = "masteruser"
                            vpcSecurityGroupIds = [
                                "sg-0test"
                            ]
                        }
                        writeConnectionSecretToRef = {
                            name = "configuration-aws-database-mariadb-sql"
                        }
                    }
                }
                rdsv1beta1.SubnetGroup{
                    metadata = {
                        annotations = {
                            "crossplane.io/composition-resource-name" = "compositeSQLInstanceDbSubnetGroup"
                        }
                        generateName = "configuration-aws-database-mariadb-"
                        labels = {
                            "crossplane.io/composite" = "configuration-aws-database-mariadb"
                        }
                        ownerReferences = [
                            {
                                apiVersion = "aws.platform.upbound.io/v1alpha1"
                                blockOwnerDeletion = True
                                controller = True
                                kind = "DataStore"
                                name = "configuration-aws-database-mariadb"
                                uid = ""
                            }
                        ]
                    }
                    spec = {
                        forProvider = {
                            description = "An excellent formation of subnetworks."
                            region = "us-west-2"
                            subnetIds = [
                                "subnet-priv-a"
                                "subnet-priv-b"
                            ]
                        }
                    }
                }
            ]
            extraResources: [_networkExtra]
            compositionPath: "apis/sqlinstances/composition.yaml"
            xrdPath: "apis/sqlinstances/definition.yaml"
            xrPath: "examples/sqlinstance/mariadb-xr.yaml"
            timeoutSeconds: 60
            validate: False
        }
    }
    metav1alpha1.CompositionTest{
        metadata.name: "TestPostgres"
        spec = {
            assertResources: [
                platformawsv1alpha1.DataStore{
                    metadata = {
                        name = "configuration-aws-database-postgres"
                        namespace = "default"
                    }
                    spec = {
                        parameters = {
                            engine = "postgres"
                            engineVersion = "13.18"
                            networkRef = {
                                id = "configuration-aws-database"
                            }
                            passwordSecretRef = {
                                key = "password"
                                name = "psqlsecret"
                            }
                            region = "us-west-2"
                            storageGB = 5
                        }
                    }
                }
                rdsv1beta1.Instance{
                    metadata = {
                        annotations = {
                            "crossplane.io/composition-resource-name" = "RDSInstanceSmall"
                        }
                        generateName = "configuration-aws-database-postgres-"
                        labels = {
                            "crossplane.io/composite" = "configuration-aws-database-postgres"
                        }
                        ownerReferences = [
                            {
                                apiVersion = "aws.platform.upbound.io/v1alpha1"
                                blockOwnerDeletion = True
                                controller = True
                                kind = "DataStore"
                                name = "configuration-aws-database-postgres"
                                uid = ""
                            }
                        ]
                    }
                    spec = {
                        forProvider = {
                            allocatedStorage = 5
                            dbName = "upbound"
                            dbSubnetGroupNameSelector = {
                                matchControllerRef = True
                            }
                            engine = "postgres"
                            engineVersion = "13.18"
                            instanceClass = "db.t3.micro"
                            passwordSecretRef = {
                                key = "password"
                                name = "psqlsecret"
                            }
                            publiclyAccessible = False
                            region = "us-west-2"
                            skipFinalSnapshot = True
                            username = "masteruser"
                            vpcSecurityGroupIds = [
                                "sg-0test"
                            ]
                        }
                        writeConnectionSecretToRef = {
                            name = "configuration-aws-database-postgres-sql"
                        }
                    }
                }
                rdsv1beta1.SubnetGroup{
                    metadata = {
                        annotations = {
                            "crossplane.io/composition-resource-name" = "compositeSQLInstanceDbSubnetGroup"
                        }
                        generateName = "configuration-aws-database-postgres-"
                        labels = {
                            "crossplane.io/composite" = "configuration-aws-database-postgres"
                        }
                        ownerReferences = [
                            {
                                apiVersion = "aws.platform.upbound.io/v1alpha1"
                                blockOwnerDeletion = True
                                controller = True
                                kind = "DataStore"
                                name = "configuration-aws-database-postgres"
                                uid = ""
                            }
                        ]
                    }
                    spec = {
                        forProvider = {
                            description = "An excellent formation of subnetworks."
                            region = "us-west-2"
                            subnetIds = [
                                "subnet-priv-a"
                                "subnet-priv-b"
                            ]
                        }
                    }
                }
            ]
            extraResources: [_networkExtra]
            compositionPath: "apis/sqlinstances/composition.yaml"
            xrdPath: "apis/sqlinstances/definition.yaml"
            xrPath: "examples/sqlinstance/postgres-xr.yaml"
            timeoutSeconds: 60
            validate: False
        }
    }
]
items= _items
