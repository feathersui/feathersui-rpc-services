# Amfphp TypedObject for Feathers UI RPC Services

The Amfphp _TypedObject_ example ported to Haxe and running with Feathers UI RPC Services.

Uses the `RemoteObject` service, which transfers data using binary AMF.

## Server

The backend for this sample is included with the Amfphp distribution.

- [Clone Amfphp from Github](https://github.com/silexlabs/amfphp-2.0)

- Start a local HTTP server supporting PHP on port **8080**. The root document directory should be _Examples/Php_ from the Amfphp repository.

It's probably easiest to use PHP's built-in web server:

```sh
cd Examples/Php
php -S localhost:8080
```
