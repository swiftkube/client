# Changelog

## 0.X.X

### New Features

- Add support for `ListOptions`

### API Changes

- Function signature change:
  - from `watch(in:watch:) throws -> EventLoopFuture<Void>`
  - to `watch(in:using:) throws -> HTTPClient.Task<Void>`
- Function signature change:
  -  from`follow(in:name:container:watch:) throws -> HTTPClient.Task<Void>`
  -  to `follow(in:name:container:using:) throws -> HTTPClient.Task<Void>`

## 0.1.0

Initial release
