# Sample Chat Server for BlazeDS and Java EE (Feathers UI RPC Services)

This is a sample server created with Java EE and BlazeDS that is meant to be deployed to a server, such as Tomcat or Jetty.

The frontend is provided by the sample **blazeds-chat-client** project.

## Build

To build the server, run the following command in this directory:

```sh
mvn clean package
```

Copy _target/blazeds-chat-server.war_ to the appropriate location to be used your Java EE server.