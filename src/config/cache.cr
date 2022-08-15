require "redis"
require "armature/cache"

Armature.cache = Armature::Cache::RedisStore.new(REDIS)
