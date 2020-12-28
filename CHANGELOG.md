# Changelog

## 0.3.2

- Change personal copyright to Swiftkube Project
- Make `KubernetesClientConfig` initializer public #3

## 0.3.1

- Update to Kubernetes model v1.18.13
  - No model changes between 1.18.9 and 1.18.13. This release is to track the update explicitly via a version bump.

## 0.3.0

### New

- Add support for `DeleteOptions`

### Bug Fixes

- Can not create resources because of "Resource `metadata.name` must be set" error #2 

## 0.2.0

### New

- Add support for `ListOptions`
- Add `core.v1.Pod` status read and update API

### Bug Fixes

- KubernetesClient can't create x509 authentication from local kubeconfig's certificate data and key #1

### API Changes

- Initializers of `GenericKubernetesClients` are no longer public
- Function signature change:
  - from `watch(in:watch:) throws -> EventLoopFuture<Void>`
  - to `watch(in:using:) throws -> HTTPClient.Task<Void>`
- Function signature change:
  -  from`follow(in:name:container:watch:) throws -> HTTPClient.Task<Void>`
  -  to `follow(in:name:container:using:) throws -> HTTPClient.Task<Void>`

## 0.1.0

Initial release
