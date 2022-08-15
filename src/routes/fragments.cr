require "./route"
require "./fetch_tag_names"
require "../config/redis"
require "../models/user"

struct Fragments
  include Route
  include FetchTagNames

  def initialize(@current_user : User?)
  end

  def call(context)
    route context do |r, response, session|
      r.get "search/users" do
        if query = r.params["query"]?
          result = REDIS.ft.search "search:users", "#{query}*",
            limit: {0, 20}
          users = Redis::FullText::JSONSearchResults(User).new(result)
          user_follows = if current_user = @current_user
                           REDIS.smembers("following:#{current_user.id}")
                         else
                           [] of String
                         end.to_set
          render "users/list"
        else
          response.status = :bad_request
        end
      end

      r.get "search/tags" do
        fetch_tags @current_user, r, response, session
      end
    end
  end
end
