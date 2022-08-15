require "./route"
require "../config/redis"
require "../models/page"

struct Pages
  include Route

  def call(context)
    route context do |r, response, session|
      r.get :id do |id|
        if page = REDIS.json.get("page:#{id}", ".", as: Page)
          render "pages/show"
        else
          response.status = :not_found
          render "app/not_found"
        end
      end
    end
  end
end
