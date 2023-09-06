# Amfphp TypedObject for Feathers UI RPC Services

The Amfphp _TypedObject_ example ported to Haxe and running with [Feathers UI RPC Services](https://github.com/feathersui/feathersui-rpc-services).

Uses the `RemoteObject` service, which transfers data using binary AMF.

## Server

The backend for this sample is included with the Amfphp distribution.

- [Clone Amfphp from Github](https://github.com/silexlabs/amfphp-2.0)

- Start a local HTTP server supporting PHP on port **8080** where the server's document root directory is the root of the Amfphp repository.

> It's probably easiest to use PHP's built-in development web server.

```sh
git clone https://github.com/silexlabs/amfphp-2.0.git
cd amfphp-2.0
php -S localhost:8080
```

## Running the html5 target

Copy this sample project's root directory into _[amfphp root]/Examples/FeathersUI/TypedObjects/_.

Then, build the sample for the _html5_ target.

```sh
openfl build html5
```

Then, open the following URL in a web browser:

http://localhost:8080/Examples/FeathersUI/TypedObjects/bin/html5/bin/index.html

## Running other targets

To test all other targets, use the standard **openfl test** command.

```sh
openfl test windows
openfl test mac
openfl test linux
openfl test hl
openfl test neko
openfl test air
```