# Fauxrem (Forem clone using Redis)

This is a project I created for the [2022 Redis Hackathon](https://dev.to/devteam/announcing-the-redis-hackathon-on-dev-3248). It's basically a [Forem](https://github.com/forem/forem) clone using Redis as the only datastore.

## Installation

Clone the repo

```
git clone https://github.com/jgaskins/fauxrem-redis.git
cd fauxrem-redis
```

### Pre-requisites

Install Redis Stack

```
brew tap redis-stack/redis-stack
brew install redis-stack-server
```

Install Crystal

```
brew install crystal
```

Build the server and related tools

```
shards build
```

## Usage

Make sure your Redis Stack server is running

```
redis-stack-server
```

Run the Fauxrem server:

```
bin/fauxrem_redis
```

## Development

TODO: Write development instructions here

## Contributing

1. Fork it (<https://github.com/jgaskins/forem_redis/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Jamie Gaskins](https://github.com/jgaskins) - creator and maintainer
