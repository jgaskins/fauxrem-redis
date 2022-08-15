require "armature/redis_session"

require "./config/redis"
require "./config/cache"

require "./middleware/rate_limiter"
require "./middleware/increment_view_count"

require "./routes/admin"
require "./routes/fragments"
require "./routes/login"
require "./routes/moderation"
require "./routes/my_account"
require "./routes/notifications"
require "./routes/pages"
require "./routes/posts"
require "./routes/route"
require "./routes/search"
require "./routes/signup"
require "./routes/tags"
require "./routes/users"

require "./models/user"
require "./models/post"
require "./models/comment"

# Log.setup :debug

class Entrypoint
  include HTTP::Handler
  include Route

  def call(context)
    route context do |r, response, session|
      response.headers["Content-Type"] = "text/html"

      if current_user_id = session["user_id"]?.try(&.as_s?)
        if current_user = REDIS.json.get("user:#{current_user_id}", ".", as: User)
          notifications = REDIS
            .ft
            .search("search:notifications", "@recipient:#{current_user_id}", limit: {0, 0})
            .first
            .as(Int64)
        end
      end

      r.on "fragments" { return Fragments.new(current_user).call context }

      render "app/header"

      r.root { response.redirect "/posts" }

      r.on "posts" { Posts.new(current_user).call context }
      r.on "users" { Users.new(current_user).call context }
      r.on "tags" { Tags.new(current_user).call context }
      r.on "pages" { Pages.new.call context }
      r.on "search" { Search.new.call context }

      # Authenticated routes
      if current_user
        r.on "account" { MyAccount.new(current_user).call context }
        r.on "notifications" { Notifications.new(current_user).call context }

        # Moderator-only routes
        if current_user.moderator?
          r.on "mod" { Moderation.new(current_user).call context }
        end

        # Admin-only routes
        if current_user.admin?
          r.on "admin" { Admin.new(current_user).call context }
        end
      end

      r.on "signup" { Signup.new.call context }
      r.on "login" { Login.new.call context }

      # If we haven't matched an endpoint yet, render a 404 page and set status
      r.miss do
        response.status = :not_found
        render "app/not_found"
      end

      render "app/footer"

      # If this is a redirect, don't delete any flashes
      unless 300 <= response.status.value < 400
        session.delete "flash.notice"
        session.delete "flash.alert"
      end
    end
  end
end

http = HTTP::Server.new([
  HTTP::LogHandler.new,
  HTTP::CompressHandler.new,
  RateLimiter.new,
  IncrementViewCount.new,
  Armature::Session::RedisStore.new(
    key: "fr_session",
    redis: REDIS,
  ),
  Entrypoint.new,
])
port = ENV.fetch("PORT", "4040").to_i
puts "Listening on #{port}..."
http.listen port
