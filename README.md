# RPC Services for Feathers UI

A port of the RPC service classes from [Apache Flex](https://flex.apache.org/) (formerly Adobe Flex) to [Feathers UI](https://feathersui.com/) for [Haxe](https://haxe.org/) and [OpenFL](https://openfl.org/).

## Overview

Please review the notes below for an overview of what currently works, doesn't work, or has changed from the original Flex implementation.

- `RemoteObject`: Load data with the same classes used by a remote application server, encoded with Action Message Format (AMF).
  - Instead of adding `[RemoteClass(alias="com.example.MyClass)]` metadata to your classes, you must call the `openfl.Lib.registerClassAlias()` function.
- `HTTPService`: Load data from a URL as XML, Text, URL variables, or JSON.
  - `resultFormat`
    - The new `RESULT_FORMAT_JSON` is supported on all targets and parses the server response as JSON, returning an [anonymous structure](https://haxe.org/manual/types-anonymous-structure.html).
    - The new `RESULT_FORMAT_HAXE_XML` is supported on all targets and returns an instance of Haxe's [`Xml`](https://api.haxe.org/Xml.html) class.
    - `RESULT_FORMAT_E4X` and `RESULT_FORMAT_XML` are available on **flash** and **air** targets only. On all other targets, a compile-time deprecation warning will be presented, and a runtime exception will be thrown. Use of the new `RESULT_FORMAT_HAXE_XML` is recommended for all targets.
- ~~`HTTPMultiService`~~: Represents a collection of HTTP operations.
  - Ported to Haxe, but not yet tested.
- ~~`WebService`~~: Provides access to SOAP-based web services on remote servers.
  - Not yet ported to Haxe.

## Requirements

- Haxe 4.2
- OpenFL 9.2
- Feathers UI 1.0.0-beta.6

## Installation

This library is not yet available on Haxelib, so you'll need to install it from Github.

```sh
haxelib git feathersui-rpc-services https://github.com/feathersui/feathersui-rpc-services.git
```

## Project Configuration

After installing the library above, add it to your OpenFL _project.xml_ file:

```xml
<haxelib name="feathersui-rpc-services" />
```
