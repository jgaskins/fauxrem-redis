require "./route"
require "../config/redis"
require "../models/user"

struct MyAccount
  include Route

  def initialize(@current_user : User)
  end

  def call(context)
    route context do |r, response, session|
      r.root do
        r.get do
          render "account/show"
        end
      end

      r.on "following_users" do
        r.root do
          r.get do
            user_follows = REDIS
              .smembers("following:#{@current_user.id}")
              .map(&.as(String))
              .sort!
            if user_follows.any?
              user_keys = user_follows.map { |id| "user:#{id}" }
              users = REDIS.json.mget(user_keys, ".", as: User)
                .compact
                .sort_by(&.name)
                .map { |user| {"", user} }

              response << "<table><tbody>"
              render "users/list"
              response << "</tbody></table>"
            else
              render "account/not_following_any_users"
            end
          end
        end
      end

      r.on "following_tags" do
        r.root do
          r.get do
            following_tags = REDIS
              .smembers("following-tags:#{@current_user.id}")
              .map(&.as(String))
              .sort!
            tags = following_tags

            response << "<table><tbody>"
            render "tags/list"
            response << "</tbody></table>"
          end
        end
      end

      r.on "blocked_words" do
        r.root do
          r.get do
            blocked_words = REDIS
              .smembers("blocked-words:#{@current_user.id}")
              .map(&.as(String))
              .sort!

            render "account/blocked_words"
          end

          r.post do
            key = "blocked-words:#{@current_user.id}"
            word = r.form_params["word"]
            if REDIS.sismember(key, word) == 0
              REDIS.sadd key, word
            else
              REDIS.srem key, word
            end
            response.redirect "/account/blocked_words"
          end
        end
      end
    end
  end
end
