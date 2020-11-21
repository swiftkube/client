<p align="center">
	<img src="./SwiftkubeClient.png">
</p>

<p align="center">
	<img src="https://img.shields.io/badge/Swift-5.2-orange.svg" />
	<a href="https://v1-18.docs.kubernetes.io/docs/reference/generated/kubernetes-api/v1.18/">
		<img src="https://img.shields.io/badge/Kubernetes-1.18.9-blue.svg" alt="Kubernetes 1.18.9"/>
	</a>
	<a href="https://swift.org/package-manager">
		<img src="https://img.shields.io/badge/swiftpm-compatible-brightgreen.svg?style=flat" alt="Swift Package Manager" />
	</a>
	<img src="https://img.shields.io/badge/platforms-mac+linux-brightgreen.svg?style=flat" alt="Mac + Linux" />
	<a href="https://github.com/swiftkube/client/actions">
		<img src="https://github.com/swiftkube/client/workflows/swiftkube-client-ci/badge.svg" alt="CI Status">
	</a>
</p>

## Table of contents

* [Overview](#overview)
* [Compatibility Matrix](#compatibility-matrix)
* [Examples](#examples)
* [Usage](#usage)
  * [Creating a client](#creating-a-client)
  * [Configuring a client](#configuring-the-client)
  * [Client authentication](#client-authentication)
  * [Client DSL](#client-dsl)
* [Advance usage](#advanced-usage)
* [Installation](#installation)
* [License](#license)

## Overview

Swift client for talking to a [Kubernetes](http://kubernetes.io/) cluster via a fluent DSL based on [SwiftNIO](https://github.com/apple/swift-nio) and the [AysncHTTPClient](https://github.com/swift-server/async-http-client).

- [x] Covers all Kubernetes API Groups in v1.18.9
- [x] Automatic configuration discovery
- [x] DSL style API
  - [x] Highest API version for the most common API Groups
  - [ ] Cover all API Groups/Versions
- [x] Generic client support
- [x] Swift-Logging support
- [x] Loading resources from external sources
  - [x] from files
  - [x] from URLs
- [ ] Read & List Options
- [ ] Delete Options
- [ ] PATCH API
- [ ] `/scale` API
- [ ] `/status` API
- [ ] Better resource watch support
- [ ] Better CRD support
- [ ] Controller/Informer support
- [ ] Swift Metrics
- [ ] Complete documentation
- [ ] End-to-end tests

## Compatibility Matrix

|                           | K8s <1.18.9| K8s 1.18.9 |
|---------------------------|------------|------------|
| SwiftkubeClient 0.1.0     | -          | ✓          |

- `✓` Exact match of API objects in both client and the Kubernetes version.
- `-` API objects mismatches either due to the removal of old API or the addition of new API. However, everything the client and Kubernetes have in common will work.

## Examples

Concrete examples for using the `Swiftkube` tooling reside in the [Swiftkube:Examples](https://github.com/swiftkube/examples) repository.

## Usage

### Creating a client

To create a client just import `SwiftkubeClient` and init an instance.

 ```swift
 import SwiftkubeClient
 
 let client = try KubernetesClient()
 ```

### Configuring the client

The client tries to resolve a `kube config` automatically from different sources in the following order:

- Kube config file in the user's `$HOME/.kube/config` directory 
- `ServiceAccount` token located at `/var/run/secrets/kubernetes.io/serviceaccount/token` and a mounted CA certificate, if it's running in Kubernetes.

Alternatively it can be configured manually, for example:

```swift
let caCert = try NIOSSLCertificate.fromPEMFile(caFile)
let authentication = KubernetesClientAuthentication.basicAuth(
    username: "admin", 
    password: "admin"
)

let config = KubernetesClientConfig(
    masterURL: "https://kubernetesmaster",
    namespace: "default",
    authentication: authentication,
    trustRoots: NIOSSLTrustRoots.certificates(caCert),
    insecureSkipTLSVerify: false
)

let client = KubernetesClient(config: config)
```

### Client authentication

The following authentication schemes are supported:

- Basic Auth: `.basicAuth(username: String, password: String)`
- Bearer Token: `.bearer(token: String)`
- Client certificate: `.x509(clientCertificate: NIOSSLCertificate, clientKey: NIOSSLPrivateKey)`

### Client DSL

`SwiftkubeClient` defines convenience API to work with Kubernetes resources. Using this DSL is the same for all resources.

> The examples use the blocking `wait()` for brevity. API calls return `EventLoopFutures` that can be composed and acted upon in an asynchronous way.

> Currently only a subset of all API groups are accessible via the DSL. See [Advanced usage](#advanced-usage) for mor details.
  
#### List resources 

```swift
let namespaces = try client.namespaces.list().wait()
let deployments = try client.appsV1.deployments.list(in: .allNamespaces).wait()
let roles = try client.rbacV1.roles.list(in: .namespace("ns")).wait()
```

You can filter the listed resources or limit the returned list size via the `ListOptions`:

```swift
let deployments = try client.appsV1.deployments.list(in: .allNamespaces, options: [
	.labelSelector(["app": "nginx"]),
	.fieldSelector(["status.phase": "Running"]),
	.resourceVersion("9001"),
	.limit(20),
	.timeoutSeconds(10)
]).wait()
```

#### Get a resource 

```swift
let namespace = try client.namespaces.get(name: "ns").wait()
let deployment = try client.appsV1.deployments.get(in: .namespace("ns"), name: "nginx").wait()
let roles = try client.rbacV1.roles.get(in: .namespace("ns"), name: "role").wait()
```

#### Delete a resource

```swift
try.client.namespaces.delete(name: "ns").wait()
try client.appsV1.deployments.delete(in: .namespace("ns"), name: "nginx").wait()
try client.rbacV1.roles.delete(in: .namespace("ns"), name: "role").wait()
```

#### Create and update a resource

Resources can be created/updated directly or via the convenience builders defined in [SwiftkubeModel](https://github.com/swiftkube/model)

```swift
// Create a resouce instance and post it
let configMap = core.v1.ConfigMap(
	metadata: meta.v1.Metadata(name: "test"),
	data: ["foo": "bar"]
}
try cm = try client.configMaps.create(inNamespace: .default, configMap).wait()


// Or inline via a builder
let pod = try client.pods.create(inNamespace: .default) {
        sk.pod {
            $0.metadata = sk.metadata(name: "nginx")
            $0.spec = sk.podSpec {
                $0.containers = [
                    sk.container(name: "nginx") {
                        $0.image = "nginx"
                    }
                ]
            }
        }
    }
    .wait()
```

#### Watch a resource

> :warning: Watching a resource opens a persistent connection until the client is closed.

```swift
try? client.appsV1.deployments.watch(in: .namespace("default")) { (event, deployment) in
    print("\(event): \(deployment)")
}
.wait()
```

#### Follow logs

> :warning: Following a pod logs opens a persistent connection until the client is closed.

```swift
try? client.pods.follow(in: .namespace("default"), name: "nginx") { (line) in
    print(line)
}
.wait()
```

## Advanced usage

### Loading from external sources

A resource can be loaded from a file or a URL:

```swift
// Load from URL, e.g. a file
let url = URL(fileURLWithPath: "/path/to/manifest.yaml")
let deployment = try apps.v1.Deployment.load(contentsOf: url)
```

### API groups

To access API groups not defined as a DSL, e.g. `rbac.v1beta1` a dedicated client can still be intantiated. A client can be either `namespace scoped` or `cluster scoped`:

```swift
try client.namespaceScoped(for: rbac.v1beta1.RoleBinding.self).list(in: .allNamespaces).wait()
try client.clusterScoped(for: rbac.v1beta1.ClusterRole.self).list().wait()
```

### Type-erased usage

Often when working with Kubernetes the concrete type of the resource is not known or not relevant, e.g. when creating resources from a YAML manifest file. Other times the type or kind of the resource must be derived at runtime given its string representation.

Leveraging `SwiftkubeModel`'s type-erased resource implementations `AnyKubernetesAPIResource` and its corresponding List-Type `AnyKubernetesAPIResourceList` it is possible to have a generic client instance, which must be initialized with a `GroupVersionKind` type:

```swift
guard let gvk = try? GroupVersionKind(for: "deployment") else {
   // handle this
}

// Get by name
let resource: AnyKubernetesAPIResource = try client.for(gvk: gvk)
    .get(in: .default , name: "nginx")
    .wait()

// List all
let resources: AnyKubernetesAPIResourceList = try client.for(gvk: gvk)
    .list(in: .allNamespaces)
    .wait()
```

#### GroupVersionKind

A `GroupVersionKind` can be initialized from:

- `KubernetesAPIResource` instance
- `KubernetesAPIResource` type
- Full API Group string
- Lowecassed singular resource kind
- Lowercased plural resource name
- lowecased short resource name

```swift
let deployment = ..
let gvk = GroupVersionKind(of: deployment)
let gvk = GroupVersionKind(of: apps.v1.Deployment.self)
let gvk = GroupVersionKind(rawValue: "apps/v1/Deployment")
let gvk = GroupVersionKind(for: "deployment")
let gvk = GroupVersionKind(for: "deployments")
let gvk = GroupVersionKind(for: "deploy")
```

## Installation

To use the `SwiftkubeModel` in a SwiftPM project, add the following line to the dependencies in your `Package.swift` file:

```swift
.package(name: "SwiftkubeClient", url: "https://github.com/swiftkube/client.git", from: "0.1.0"),
```

then include it as a dependency in your target:

```swift
import PackageDescription

let package = Package(
    // ...
    dependencies: [
        .package(name: "SwiftkubeClient", url: "https://github.com/swiftkube/client.git", from: "0.1.0")
    ],
    targets: [
        .target(name: "<your-target>", dependencies: [
            .product(name: "SwiftkubeClient", package: "SwiftkubeClient"),
        ])
    ]
)
```

Then run `swift build`.

## License

Swiftkube project is licensed under version 2.0 of the [Apache License](https://www.apache.org/licenses/LICENSE-2.0). See [LICENSE](./LICENSE) for more details.
