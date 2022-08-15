require "json"
require "uuid/json"

struct Comment
  include JSON::Serializable

  getter id : UUID
  getter author : String
  getter body : String
  getter source : String
  @[JSON::Field(converter: Time::EpochMillisConverter)]
  getter created_at : Time

  def initialize(@id, @author, @body, @source, @created_at = Time.utc)
  end
end
