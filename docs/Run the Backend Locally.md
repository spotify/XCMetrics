# Running the backend locally

It's useful to run the backend locally to test that you can ingest data to it before deploying your changes. This guide will walk you through the necessary steps.

The Backend is built using the [Vapor 4.0 framework](https://vapor.codes). We advise to read the [official documentation](https://docs.vapor.codes/4.0/) if you plan to contribute to it. Another good resource for learning it, is [this tutorial](https://www.raywenderlich.com/11555468-getting-started-with-server-side-swift-with-vapor-4)

## 1. Docker

The Backend needs Redis and Postgresql to run. This repo contains a `docker-compose.yml` file that you can use to start them. From the command line run
`docker-compose up -d`

**Note:** Remember to stop the docker instances when you're done using the Backend locally with `docker-compose stop`


## 2. Run the migrations

The migrations will create the table in the Database. You only need to run them the first time you're going to start the backend or if a table changed since the last time you ran it. That information can be found in the Changelog.

From the command line

```
swift run XCMetricsBackend migrate
```

Or from Xcode, select the **XCMetricsBackend** schema and setup `migrate` as an Argument:

![Xcode Schema argument](img/backend-migrate.png)


**Note:** You will get a prompt to confirm the migrations. Just press `y`.

## 3. Start the backend

From the command line:

```
swift run XCMetricsBackend
```

Or from Xcode: remove the `migrate` argument and run the **XCMetricsBackend** schema

## 4. Verify that is running

The backend will start at port 8080. 

Run 

`curl -I http://localhost:8080/hello`

## 5. Change the client's URL

Open the file `MetricsServicePublisherHTTP.swift` and change the default url to point to localhost.

## 6. Insert some data

Run `XCMetrics` and check that the build data was inserted in the database. You can use any Postgres client like [Postico](https://eggerapps.at/postico/). The Postgres instance is running in localhost, port 5432. Check the `docker-compose.yml` file for the database name and the default user and password. The main table is called `builds`. You will see the build data in that table.

>Note: make sure to change the authentication values when deploying your service to production not to use the default values.

## Common pitfalls

### Address already in use

`[ ERROR ] bind(descriptor:ptr:bytes:): Address already in use (errno: 48)`

Sometimes, Xcode fails to stop the Backend properly. And the next time you try to run it you get that error. You will need to kill it manually:

Run `ps -ax | grep -i XCMetricsBackend`, look for a process that is run from DerivedData, like this:


`86981 ??         0:02.85 /Users/user/Library/Developer/Xcode/DerivedData/XCMetrics-aqdxosbxjtygdlhkquzojjjgxwce/Build/Products/Debug/XCMetricsBackend`

Kill the process using its PID: `kill -9 86981`


### Connection reset error

When you start the backend you get errors like `[ ERROR ] Job run failed: connection reset (error set): Connection refused (errno: 61)` that means that docker compose did not start correctly.

To check the reason:

1. Stop the instances with `docker-compose stop`.
2. Run `docker-compose up` (No `- d`) to check the output of the command.

Things to verify: Redis will try to start in Port `6379` and Postgres in `5432`. If you are already using those ports in other processes, change them in the `docker-compose.yml`. In this example we're changing the Redis port to **6500**. In docker compose, the left port is the port that will be used in your host, the right port is the port of the docker instance that will be bound to the left port.

```
    ports:
       - "6500:6379"
```


