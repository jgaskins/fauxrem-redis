struct Notifications
  include Route

  def initialize(@current_user : User)
  end

  def call(context)
    route context do |r, response, session|
      r.root do
        r.get do
          notifications = Redis::FullText::JSONSearchResults(Notification).new(
            REDIS.ft.search "search:notifications", "@recipient:#{@current_user.id}",
            sortby: Redis::FullText::SortBy.new("created_at", :asc),
          )
          render "notifications/index"
        end
      end

      r.on :id do |id|
        r.post "dismiss" do
          REDIS.unlink "notification:#{id}"
          session["flash.notice"] = "Notification dismissed"
          response.redirect "/notifications"
        end
      end
    end
  end
end

struct Notification
  include JSON::Serializable

  getter id : UUID
  getter recipient : String
  getter title : String
  getter body : String?
  getter path : String

  @[JSON::Field(converter: Time::EpochMillisConverter)]
  getter created_at : Time

  def initialize(@recipient, @title, @body, @path, @id = UUID.random, @created_at = Time.utc)
  end
end
