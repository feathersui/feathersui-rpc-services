# RPC Services for Feathers UI

A port of the RPC service classes from [Apache Flex](https://flex.apache.org/) (formerly Adobe Flex) to [Feathers UI](https://feathersui.com/) for [Haxe](https://haxe.org/) and [OpenFL](https://openfl.org/).

Contains the following service classes:

- `HTTPService`: Load data from a URL as XML, simple string text, URL variables, or JSON.
- `RemoteObject`: Load typed objects using binary AMF.

## Compatibility Notes

### `RemoteObject`

Instead of adding `[RemoteClass(alias="com.example.MyClass")]` metadata to a class, call the `openfl.Lib.registerClassAlias()` function to register each type when the application initializes.

```hx
Lib.registerClassAlias("com.example.MyClass", MyClass);
```

### `HTTPService`

The `resultFormat` property includes two new formats:

- `RESULT_FORMAT_JSON`: Parses the server response as JSON, returning an [anonymous structure](https://haxe.org/manual/types-anonymous-structure.html). Supported on all targets.
- `RESULT_FORMAT_HAXE_XML`: Returns an instance of Haxe's [`Xml`](https://api.haxe.org/Xml.html) class. Supported on all targets.

The `RESULT_FORMAT_E4X` and `RESULT_FORMAT_XML` values will throw an exception on most targets. These formats are supported on the **flash** and **air** targets only. Using the new `RESULT_FORMAT_HAXE_XML` instead is recommended.

### Unsupported Service Types

The following services have not yet been ported to Haxe and Feathers UI.

- ~~`WebService`~~: Provides access to SOAP-based web services on remote servers.
- ~~`HTTPMultiService`~~: Represents a collection of HTTP operations.

If you need either of these service types, please create a [feature request](https://github.com/feathersui/feathersui-rpc-services/issues).

## Minimum Requirements

- Haxe 4.1
- OpenFL 9.2
- Feathers UI 1.0

## Installation

Run the following command in a terminal to install [feathersui-rpc-services](https://lib.haxe.org/p/feathersui-rpc-services) from Haxelib.

```sh
haxelib install feathersui-rpc-services
```

## Project Configuration

After installing the library above, add it to your OpenFL _project.xml_ file:

```xml
<haxelib name="feathersui-rpc-services" />
```

## Documentation

- [feathersui-rpc-services API Reference](https://api.feathersui.com/rpc-services/)
