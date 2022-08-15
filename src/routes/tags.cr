require "./route"
require "./fetch_tag_names"
require "../config/redis"
require "../models/user"

struct Tags
  include Route
  include FetchTagNames

  def initialize(@current_user : User?)
  end

  def call(context)
    route context do |r, response, session|
      r.root do
        r.get do
          render "tags/index"
        end
      end

      r.on :name do |name|
        r.root do
          r.get do
            query = "@tags:{#{name.gsub(/\W/) { |ch| "\\#{ch}" }}}"
            page = r.params.fetch("page", 1).to_i64
            per_page = 20
            raw_posts = REDIS.ft.search "search:posts", query,
              filter: [
                Redis::FullText::Filter.new("published_at", "-inf".."+inf"),
              ],
              return: %w[$.id $.title $.author $.published_at $.tags],
              sortby: Redis::FullText::SortBy.new("published_at", :desc),
              limit: {(page - 1) * per_page, per_page}
            posts = Redis::FullText::PropertySearchResults({String, String, String, String, String?}).new(raw_posts)

            render "posts/list"
          end
        end

        if current_user = @current_user
          r.post "follow" do
            unless referer = r.headers["Referer"]?
              response.status = :bad_request
              response << "Must use the tag follow button"
              return
            end

            key = "following-tags:#{current_user.id}"
            if REDIS.sismember(key, name) == 0
              REDIS.sadd key, name
            else
              REDIS.srem key, name
            end

            response.redirect referer
          end
        end
      end
    end
  end

  def post_list_type
    "This tag"
  end
end
