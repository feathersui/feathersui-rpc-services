# feathersui-rpc-services Change Log

## 1.0.3 (2023-02-01)

- Fixed registering of aliases for `feathers.messaging.Producer` and `feathers.messaging.Consumer`.
- Fixed failure to catch thrown `String` because try/catch blocks were targeting `haxe.Exception` only.
- Fixed a couple of public getter and setter functions that should have been private.
- The `headers` property of the `IMessage` interface is typed as `Dynamic` instead of `Any` to be closer to the original AS3 version.

## 1.0.2 (2022-10-17)

- Fixed failure to catch thrown `haxe.Exception` because try/catch blocks were targeting `openfl.errors.Error` instead.

## 1.0.1 (2022-10-11)

- AsyncToken: Fixed responder not reporting result or fault if added after receiving event.

## 1.0.0 (2022-09-08)

- Initial release
