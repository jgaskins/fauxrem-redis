# Fauxrem (Forem clone using Redis)

This is a project I created for the [2022 Redis Hackathon](https://dev.to/devteam/announcing-the-redis-hackathon-on-dev-3248). It's a [Forem](https://github.com/forem/forem) clone using Redis exclusively as the datastore.

<img width="1097" alt="Screenshot of the app, showing the title of the app, followed by a navigation element containing links for posts, users, tags, account, notifications, moderation, and admin. Below the navigation is a search form. That concludes the header. Below the header is the main site content showing the post feed, with one entry in it. The post is titled Hello World, written by jgaskins, with the tag welcome, followed by the timestamp of the post. That concludes the main body content. Below the main body content is a footer containing a copyright notice." src="https://user-images.githubusercontent.com/108205/184562996-33fde5a8-def5-47f2-b769-82cdec7ba46e.png">

## Overview video (Optional)

Here's a short video that explains the project and how it uses Redis:

[Insert your own video here, and remove the one below]

## How it works


### How the data is stored:

Data for entities such as users, posts, comments, and a few others are stored as JSON objects using [RedisJSON](https://redis.io/docs/stack/json/). Most are stored in a key of the format `#{entity_type}:#{entity_id}`, so for example a user with the id `jamie` would be stored in the key `user:jamie`.

- Users
  - id : String
    - Equivalent to the `username` field in Forem — we have no need for the numeric id
  - name : String
- Posts
  - id : String
    - stored as `#{author_id}-#{parameterized_title}-#{random_noise}`
    - example: `jamie-hello-world-ad142c`
  - author : String
    - The `id` of the user that wrote the article
  - title : String
  - source : String
    - markdown)
  - body : String
    - raw HTML
    - I considered not storing this and compiling it on the fly, but Forem stores raw HTML so I just went with that
  - tags : String
    - Stored as comma-separated tag names
  - popularity : Int64
  - created_at : Int64 | Nil
  - published_at : Int64 | Nil
  - comments : Array(Comment)
    - Stored as nested JSON
      - id : String
      - author : String
      - source : String
      - body : String
      - created_at : Int64 | Nil
- Reports — used to report spammy or abusive posts/comments
  - id : String
  - reporter : String
    - The id of the user that made this report
  - reportee : String
    - The id of the author of the bad post/comment
  - post_id : String
    - The id of the post where the problem occurred
  - note : String
    - The information from the reporter about the problem
  - status : String
    - An enum showing the report is pending action, ignored, or resolved
  - created_at : Int64
    - When the report was created, used for sorting
- Pages — static pages linkable from other areas, useful for nav links, maybe a ToS/privacy policy, etc.
  - title : String
  - source : String
    - markdown
  - body : String
  - published_at : Int64
- Notifications — lets users know when someone else likes or comments on one of their posts
  - id : UUID
  - recipient : String
    - User id for the person seeing this notification
  - title : String
  - body : String
  - path : String
    - For linking to the entity being referenced

There are also other non-RedisJSON data structures used for various purposes:

- `following:#{user_id}`
  — Redis sets used to determine who a given user is following
  - Used for populating the feed
- `following-tags:#{user_id}`
  — Redis sets used to determine which tags a given user is following
  - Used for populating the feed
- `blocked-words:#{user_id}`
  — Redis sets used to determine which tags a given user does *not* want in their feed
- `likes:post:#{post_id}`
  - Redis sets used to determine which users have liked the given post
  - Liking a post `SADD`s your user id to this list and unliking it `SREM`s it
  - I considered a HyperLogLog but I wanted to support unliking
- `fr_session-#{session_id}`
  - A JSON object representing the session data
  - This is built into the `armature` framework and does not require RedisJSON
- 

### How the data is accessed:

Refer to [this example](https://github.com/redis-developer/basic-analytics-dashboard-redis-bitmaps-nodejs#how-the-data-is-accessed) for a more detailed example of what you need for this section.

Querying the feed:

- Logged-in
  - `FT.SEARCH search:posts '@author("followed_user_1"|"followed_user_2") @tags:{followed_tag_1|followed_tag_2} -("blocked word 1"|"blocked word 2")' FILTER published_at #{earliest_feed_date} +inf SORTBY published_at DESC LIMIT 0 50`
- Anonymous
  - `FT.SEARCH search:posts * FILTER published_at #{earliest_feed_date} +inf SORTBY popularity DESC LIMIT 0 20`

## How to run it locally?

### Prerequisites

- Redis Stack
- Crystal compiler

If you're using [Homebrew](https://brew.sh), you can install Redis Stack and the Crystal compiler by pasting these lines in your terminal:

```
brew tap redis-stack/redis-stack # if you don't already have it tapped
brew install redis-stack-server
brew install crystal
```

If your Redis Stack server isn't already running:

```
redis-stack-server
```

### Local installation

Clone the repo

```
git clone https://github.com/jgaskins/fauxrem-redis.git
cd fauxrem-redis
```

Build the app server and related tools with `shards build` and run the app. You will need to set the `REDIS_URL` environment variable if it is not running on `localhost:6379`, such as if you're using it with a Redis Cloud instance — the URL format is `redis://username:password@host:port`.

```
shards build
bin/fauxrem_redis
```

The RediSearch indexes will be provisioned automatically when the app boots.

## Deployment

To make deploys work, you need to create free account on [Redis Cloud](https://redis.info/try-free-dev-to)

### Heroku

[Insert Deploy on Heroku button](https://devcenter.heroku.com/articles/heroku-button)

### Netlify

[Insert Deploy on Netlify button](https://www.netlify.com/blog/2016/11/29/introducing-the-deploy-to-netlify-button/)

### Vercel

[Insert Deploy on Vercel button](https://vercel.com/docs/deploy-button)

## More Information about Redis Stack

Here some resources to help you quickly get started using Redis Stack. If you still have questions, feel free to ask them in the [Redis Discord](https://discord.gg/redis) or on [Twitter](https://twitter.com/redisinc).

### Getting Started

1. Sign up for a [free Redis Cloud account using this link](https://redis.info/try-free-dev-to) and use the [Redis Stack database in the cloud](https://developer.redis.com/create/rediscloud).
1. Based on the language/framework you want to use, you will find the following client libraries:
    - [Redis OM .NET (C#)](https://github.com/redis/redis-om-dotnet)
        - Watch this [getting started video](https://www.youtube.com/watch?v=ZHPXKrJCYNA)
        - Follow this [getting started guide](https://redis.io/docs/stack/get-started/tutorials/stack-dotnet/)
    - [Redis OM Node (JS)](https://github.com/redis/redis-om-node)
        - Watch this [getting started video](https://www.youtube.com/watch?v=KUfufrwpBkM)
        - Follow this [getting started guide](https://redis.io/docs/stack/get-started/tutorials/stack-node/)
    - [Redis OM Python](https://github.com/redis/redis-om-python)
        - Watch this [getting started video](https://www.youtube.com/watch?v=PPT1FElAS84)
        - Follow this [getting started guide](https://redis.io/docs/stack/get-started/tutorials/stack-python/)
    - [Redis OM Spring (Java)](https://github.com/redis/redis-om-spring)
        - Watch this [getting started video](https://www.youtube.com/watch?v=YhQX8pHy3hk)
        - Follow this [getting started guide](https://redis.io/docs/stack/get-started/tutorials/stack-spring/)

The above videos and guides should be enough to get you started in your desired language/framework. From there you can expand and develop your app. Use the resources below to help guide you further:

1. [Developer Hub](https://redis.info/devhub) - The main developer page for Redis, where you can find information on building using Redis with sample projects, guides, and tutorials.
1. [Redis Stack getting started page](https://redis.io/docs/stack/) - Lists all the Redis Stack features. From there you can find relevant docs and tutorials for all the capabilities of Redis Stack.
1. [Redis Rediscover](https://redis.com/rediscover/) - Provides use-cases for Redis as well as real-world examples and educational material
1. [RedisInsight - Desktop GUI tool](https://redis.info/redisinsight) - Use this to connect to Redis to visually see the data. It also has a CLI inside it that lets you send Redis CLI commands. It also has a profiler so you can see commands that are run on your Redis instance in real-time
1. Youtube Videos
    - [Official Redis Youtube channel](https://redis.info/youtube)
    - [Redis Stack videos](https://www.youtube.com/watch?v=LaiQFZ5bXaM&list=PL83Wfqi-zYZFIQyTMUU6X7rPW2kVV-Ppb) - Help you get started modeling data, using Redis OM, and exploring Redis Stack
    - [Redis Stack Real-Time Stock App](https://www.youtube.com/watch?v=mUNFvyrsl8Q) from Ahmad Bazzi
    - [Build a Fullstack Next.js app](https://www.youtube.com/watch?v=DOIWQddRD5M) with Fireship.io
    - [Microservices with Redis Course](https://www.youtube.com/watch?v=Cy9fAvsXGZA) by Scalable Scripts on freeCodeCamp
