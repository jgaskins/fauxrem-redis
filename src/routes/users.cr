require "./route"
require "../config/redis"
require "../models/user"

struct Users
  include Route

  def initialize(@current_user : User?)
  end

  def call(context)
    route context do |r, response, session|
      r.root do
        r.get do # GET /users
          search = r.params.fetch("search", "*")
          users = Redis::FullText::JSONSearchResults(User).new(
            REDIS.ft.search "search:users", search,
              sortby: Redis::FullText::SortBy.new("username", :asc),
              limit: {0, 20},
          )
          user_follows = if current_user = @current_user
                           REDIS.smembers("following:#{current_user.id}")
                         else
                           [] of String
                         end.to_set

          render "users/index"
        end
      end

      r.on :id do |id|
        if user = REDIS.json.get("user:#{id}", ".", as: User)
          r.root do
            r.get do # GET /users/:id
              page = r.params.fetch("page", "1").to_i64? || 1i64
              per_page = 20

              unless (current_user = @current_user) && (id == current_user.id || current_user.moderator? || current_user.admin?)
                filter = [
                  Redis::FullText::Filter.new("published_at", "-inf".."+inf"),
                ]
              end

              posts = Redis::FullText::JSONSearchResults(Post).new(
                REDIS.ft.search "search:posts", "@author:#{user.id.inspect}",
                  filter: filter,
                  sortby: Redis::FullText::SortBy.new(@current_user ? "created_at" : "published_at", :desc),
                  limit: {(page - 1) * per_page, per_page}
              )

              render "users/show"
            end
          end
        end

        if current_user = @current_user
          r.post "follow" do # POST /users/:id/follow
            unless referer = r.headers["Referer"]?
              response.status = :bad_request
              response << "Bad request"
              return
            end

            set = "following:#{current_user.id}"
            following = REDIS.sismember(set, id).as(Int64) > 0
            if following
              REDIS.srem set, id
            else
              REDIS.sadd set, id
            end

            response.redirect referer
          end
        end
      end
    end
  end
end
