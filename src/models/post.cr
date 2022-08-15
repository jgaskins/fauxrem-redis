require "json"

struct Post
  include JSON::Serializable

  getter id : String
  getter author : String
  getter title : String
  getter body : String
  getter source : String
  getter popularity : Float64
  @[JSON::Field(converter: Post::TagListConverter, ignore_serialize: @tags.nil? || @tags.try(&.empty?))]
  getter tags : Array(String) { [] of String }
  @[JSON::Field(ignore_serialize: @comments.nil? || @comments.try(&.empty?))]
  getter comments : Array(Comment) { [] of Comment }
  @[JSON::Field(converter: Time::EpochMillisConverter)]
  getter created_at : Time
  @[JSON::Field(converter: Time::EpochMillisConverter)]
  getter published_at : Time?

  def initialize(@id, @author, @title, @body, @source, @created_at = Time.utc, @published_at = nil, @popularity = 0, @comments = nil, @tags = nil)
  end

  def published?
    !published_at.nil?
  end

  module TagListConverter
    def self.from_json(json : JSON::PullParser)
      json.read_string.split(',')
    end

    def self.to_json(tags : Array(String), json : JSON::Builder)
      json.string tags.join(',')
    end
  end
end
