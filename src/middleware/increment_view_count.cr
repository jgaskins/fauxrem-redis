require "http"

require "../config/redis"

class IncrementViewCount
  include HTTP::Handler

  @posts_viewed = {} of String => Int64

  def initialize
    spawn do
      loop do
        sleep 1.second
        @posts_viewed.each do |(id, count)|
          REDIS.json.numincrby "post:#{id}", ".popularity", count
          @posts_viewed.delete id
        end
        @posts_viewed = {} of String => Int64
      rescue ex
      end
    end
  end

  def call(context)
    if context.request.path =~ %r{/posts/([\w-]+)/viewed}
      @posts_viewed[$1] ||= 0i64
      @posts_viewed[$1] += 1i64
    else
      call_next context
    end
  end
end
