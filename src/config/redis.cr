require "redis"
require "redis/json"
require "redis/search"

REDIS = Redis::Client.new(URI.parse(ENV.fetch("REDIS_URL", "redis:///")))

spawn do
  # Recreate the index to make it easier to work with in development
  # REDIS.ft.drop "search:posts" rescue nil
  # REDIS.ft.drop "search:users" rescue nil
  # REDIS.ft.drop "search:reports" rescue nil
  # REDIS.ft.drop "search:pages" rescue nil
  # REDIS.ft.drop "search:notifications" rescue nil

  index_names = REDIS.run({"ft._list"}).as(Array)

  unless index_names.includes? "search:posts"
    REDIS.ft.create <<-INDEX
      search:posts ON JSON
        PREFIX 1 post:
      SCHEMA
        $.author AS author TEXT NOSTEM WEIGHT 2
        $.title AS title TEXT WEIGHT 3
        $.body AS body TEXT
        $.tags AS tags TAG SEPARATOR , CASESENSITIVE
        $.popularity AS popularity NUMERIC SORTABLE
        $.published_at AS published_at NUMERIC SORTABLE
        $.created_at AS created_at NUMERIC SORTABLE
    INDEX
  end

  unless index_names.includes? "search:users"
    REDIS.ft.create <<-INDEX
      search:users ON JSON
        PREFIX 1 user:
      SCHEMA
        $.id AS username TEXT NOSTEM WEIGHT 2
        $.name AS name TEXT PHONETIC dm:en
    INDEX
  end

  unless index_names.includes? "search:reports"
    REDIS.ft.create <<-INDEX
      search:reports ON JSON
        PREFIX 1 report:
      SCHEMA
        $.reporter AS reporter TEXT NOSTEM
        $.reportee AS reportee TEXT NOSTEM
        $.post_id AS post_id TEXT NOSTEM
        $.note AS note TEXT
        $.status AS status TEXT NOSTEM
        $.created_at AS created_at NUMERIC SORTABLE
    INDEX
  end

  unless index_names.includes? "search:pages"
    REDIS.ft.create <<-INDEX
      search:pages ON JSON
        PREFIX 1 page:
      SCHEMA
        $.title AS title TEXT SORTABLE
        $.body AS body TEXT
        $.published_at AS published_at NUMERIC SORTABLE
    INDEX
  end

  unless index_names.includes? "search:notifications"
    REDIS.ft.create <<-INDEX
      search:notifications ON JSON
        PREFIX 1 notification:
      SCHEMA
        $.recipient AS recipient TEXT NOSTEM
        $.title AS title TEXT
        $.path AS path TEXT NOSTEM
        $.created_at AS created_at NUMERIC SORTABLE
    INDEX
  end
end

struct Redis::FullText::JSONSearchResults(T)
  include Enumerable({String, T})

  getter total_result_count : Int64

  def self.new(results : String | Int | Nil)
    raise ArgumentError.new("Cannot get Redis::FullText::JSONSearchResults from #{results.inspect}")
  end

  def initialize(results : Array)
    @total_result_count = results.first.as(Int64)
    results = Slice(Redis::Value).new(results.to_unsafe + 1, results.size - 1)
    @results = Hash(String, T).new(initial_capacity: results.size // 2)
    results.each_slice(2) do |(key, result)|
      @results[key.as(String)] = T.from_json(result.as(Array)[-1].as(String))
    end
  end

  def each
    @results.each { |kv| yield kv }
  end
end

struct Redis::FullText::PropertySearchResults(T)
  include Enumerable(T)
  getter total_result_count : Int64

  def self.new(results : String | Int | Nil)
    raise ArgumentError.new("Cannot get Redis::FullText::JSONSearchResults from #{results.inspect}")
  end

  def initialize(results : Array)
    @total_result_count = results.first.as(Int64)
    results = Slice(Redis::Value).new(results.to_unsafe + 1, results.size - 1)
    @results = Hash(String, T).new(initial_capacity: results.size)
    results.each_slice(2) do |(key, result)|
      result = result.as Array
      @results[key.as(String)] =
        {% if T < Tuple %}
          {
            {% for type, index in T %}
              result[{{index * 2 + 1}}]?.as({{type}}),
            {% end %}
          }
        {% else %}
          result[1].as(T)
        {% end %}
    end
  end

  def each
    @results.each_value { |v| yield v }
  end
end
