require "./route"
require "../config/redis"

struct Search
  include Route

  def call(context)
    route context do |r, response, session|
      r.get "posts" do
        if query = r.params["query"]?
          query = query.gsub(/[^@\s]?\w+:"?\(?{?\w+}?\)?"?/) { |match| "@#{match}" }
          puts query
          page = r.params.fetch("page", 1).to_i64
          per_page = 20

          begin
            result = REDIS.ft.search "search:posts", query,
              filter: [
              Redis::FullText::Filter.new("published_at", 0.."+inf"),
              ],
              return: %w[$.id $.title $.author $.published_at $.tags],
              limit: {(page - 1) * per_page, per_page}
          rescue ex
            pp ex
            response.status = :bad_request
            response << "<h2>Malformed search</h2>"
            return render "search/help"
          end

          posts = Redis::FullText::PropertySearchResults({String, String, String, String, String?}).new(result)
          render "posts/list"
        else
          response.status = :bad_request
          response << "<h2>Missing search query</h2>"
        end
      end
    end
  end

  def post_list_type
    "Your search"
  end
end
