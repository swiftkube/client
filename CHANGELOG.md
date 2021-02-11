# Changelog

## 0.6.1

### Bug Fixes

- Fix SwiftkubeClientTask cancelling
 
## 0.6.0

### New

- Implement asynchronous shutdown
- Implement reconnect handling for `watch` and `follow` API requests
- Introduce `ResourceWatcherDelegate` and `LogWatcherDelegate` protocols

### API Changes

- Changed signature of `watch` and `follow` APIs.
- Replace `ResourceWatch` and `LogWatch` with new protocols 
- The `follow` and `watch` functions return a cancellable `SwiftkubeClientTask` instance insteaf of `HTTPClient.Task<Void>`.


## 0.5.0

### New

- Add metrics support for gathering request latencies and counts
- Support `ListOptions` in watch call
- Add `watch` and `follow` API that accept a `RecourceWatch` or `LogWatch` instance
- Add an `errorHandler` closure to `ResourceWatch` and `LogWatch`
- Make Selectors (`NamespaceSelector`, `LabelSelector` etc.) Hashable

### API Changes

- Replace implicit client shutdown on deinit with explicit `syncShutdow`
- Expose `ResourceWatch` and `LogWatch` classes for extension

## 0.4.0

### New

- Add SwiftFormat config and format code base accordingly
- Add support for `ReadOptions`

### Bug Fixes

- Fix massive memory leak by breaking retain cycle between the `JSONDecoder` and `DateFormatters` #4 by @t089

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
