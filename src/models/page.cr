require "json"

struct Page
  include JSON::Serializable

  getter id : String
  getter title : String
  getter source : String
  getter body : String
  
  @[JSON::Field(converter: Time::EpochMillisConverter)]
  getter created_at : Time

  def initialize(@id, @title, @source, @body, @created_at = Time.utc)
  end
end
