require "json"

struct User
  include JSON::Serializable

  getter id : String
  getter name : String

  @[JSON::Field(ignore_serialize: @roles.nil? || @roles.try(&.empty?))]
  getter roles : Array(Role) { [] of Role }

  def initialize(@id, @name)
  end

  def moderator?
    roles.any?(&.mod?)
  end

  def admin?
    roles.any?(&.admin?)
  end

  enum Role
    MOD
    ADMIN
  end
end
