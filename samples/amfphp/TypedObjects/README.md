# Amfphp TypedObject for Feathers UI RPC Services

The Amfphp _TypedObject_ example ported to Haxe and running with Feathers UI RPC Services.

Uses the `RemoteObject` service, which is currently supported on the **air** and **flash** targets only.

## Server

The backend for this sample is included with the Amfphp distribution.

- [Download Amfphp](https://github.com/silexlabs/amfphp-2.0)

- Extract the contents of the _.zip_ file.

- Start a local HTTP server supporting PHP on port **8080**. The root document directory should be _Examples/Php_ from the Amfphp distribution.

It's probably easiest to use PHP's built-in web server:

```sh
cd Examples/Php
php -S localhost:8080
```
