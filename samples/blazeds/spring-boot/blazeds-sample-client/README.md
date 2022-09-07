# BlazeDS Client for Feathers UI RPC Services

A sample client for a BlazeDS Spring Boot server built with Haxe and running with Feathers UI RPC Services.

Uses the `RemoteObject` service, which transfers data using binary AMF.

## Server

The server for this sample is included in the parent directory.

Run the following commands to build and launch the server.

```sh
cd blazeds-sample-server
mvn clean install
java -jar target/blazeds-sample-server-1.0-SNAPSHOT-exec.war
```
