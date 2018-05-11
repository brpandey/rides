# Rides

Fetches data about car ride shares from a few made-up live data providers in parallel.  

Implements below assignment

Kizuna 絆 (http://www.bbc.com/news/world-asia-16321999)

## Noteworthy
* Uses a scheduler to help dispatch runs, and to help adminster cache to db persistence
* Uses a generic worker module template to implement standardized provider processes
* Allows for custom module implementations using behaviour interface
* Uses Task Supervisor to ensure works have their own process and are decoupled
* Uses ETS as a decoupling and caching layer for multiple provider workers, and parameter store
* Supports a config / yaml format for specifying provider metadata for easy addition of data providers
* Supports serialized lob db pattern for variable extra provider fields
* Stores data into PostgresSQL instance in a normalized way
* Supports request retries for temporarily unavailable services

Thanks! Bibek


```elixir
$ source sample.env
```


## Assignment

The assignment consists in fetching data about car ride shares from a few made-up data providers. The fetched data should be normalized into a unified format and persisted to a local database.
Data providers

We made up two different data providers: Kamakurashares and GinzaRides. These providers are accessible as an HTTP API specified below.

* https://絆.xyz/feed/v1/ginzarides
* https://絆.xyz/feed/v1/kamakurashares

### Kamakurashares

Kamakurashares is accessible at /feed/v1/kamakurashares. A request to this endpoint will return a JSON response containing a list of rides where each ride is an object with the following keys:

```elixir
 occupants: a string formatted with the name of the driver, a space, a hyphen (-), a space, and the name of the passenger.
 created_at: the time this ride was created at, as a timestamp.
```

The status code of the response can be 200 if the request is successful, or 503 if the service is temporarily unavailable. The response always contains all the rides available to Kamakurashares.

An example response could look like this:

```elixir
[
  {
    "occupants": "Kengo - Shingo",
    "created_at": 1522503067
  }
]
```
### GinzaRides

GinzaRides is accessible at /feed/v1/ginzarides. A request to this endpoint will return a JSON response containing a list of rides where each ride  is an object with the following keys:

```elixir
 driver: a string containing the name of the driver.
 passenger: a string containing the name of the passenger.
 created_at: the time this ride share was created at, as a timestamp.
```

The response can be customized through the optional last_checked_at query parameter. If this parameter is not present, then all rides available to GinzaRides are returned in the response. If this parameter is available, it should be a timestamp: the response will only contain the rides created after the given timestamp. This should be used to make the response size as small as possible (for example, through caching on the client).

The status code of the response can be 200 if the request is successful, 503 if the service is temporarily unavailable, or 400 if the query parameters are invalid.

An example response could look like this:

```elixir
[
  {
    "driver": "Kengo",
    "passenger": "Akita",
    "created_at": 1522503067
  }
]
```

### Fetching data

The application you will build is responsible for continuously fetching ride shares from all mentioned providers (possibly in parallel). Data should be fetched from each provider every 30 seconds (data doesn’t need to be fetched at the same time for all providers). Your application should persist the data fetched from providers in a PostgreSQL instance running locally. You’re free to choose the unified format of the data as long as it’s unified. You’re however required to persist the provider a ride share came from alongside that ride.

The application should be an Elixir project created with Mix. The final project should run when mix run --no-halt is invoked in the project’s root directory (if you use a non-standard PostgreSQL instance, such as one running on a port that is not the default one, include installation instructions).
What to keep in mind

* The code should be production grade, write code that you would be happy to deploy to production
* The code should be extendable, it should be easy to add new data providers using the unified format
* The application must be able to handle all errors that are expected to occur, the application is expected to be resilient and never crash in a non-recoverable way (excluding for Erlang VM bugs or crashes)
* Do not over-engineer the solution, think of the simplest way to solve the assignment without go too far with too much indirection or application architecture
* Clarify any assumptions you have made about the assignment or things you left out of your solution
