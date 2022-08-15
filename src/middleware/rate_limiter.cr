require "http"

require "../config/redis"

class RateLimiter
  include HTTP::Handler

  def call(context)
    request = context.request
    response = context.response

    if address = request.headers["x-forwarded-for"]?
    elsif address = request.remote_address
      address = address.to_s
      # TODO: make this work for IPv6
      address = address[0...address.index(':')]
    end

    now = Time.utc
    request_key = "requests:#{address}:#{now.minute}"
    ban_key = "perma-banned-ip:#{address}"
    temp_ban_key = "temp-banned-ip:#{address}"

    request_count, _, is_banned, is_temp_banned = REDIS.pipeline do |pipe|
      pipe.incr request_key
      pipe.expire request_key, 1.minute
      pipe.get ban_key
      pipe.get temp_ban_key
    end

    if is_banned
      return response.status = :forbidden
    end

    # Allow a max of 100 RPM per IP
    if request_count.as(Int) > 100
      response.status = :too_many_requests
      response.headers["retry-after"] = Time::Format::HTTP_DATE.format(1.minute.from_now)
    end

    # Hitting over 1k RPM per IP is considered abusing the platform, so we ban
    # them for an hour
    if is_temp_banned
      response.status = :too_many_requests
      response.headers["retry-after"] = is_temp_banned.as(String)
    elsif request_count.as(Int) > 1000
      can_try_again_at = 1.hour.from_now
      is_temp_banned = Time::Format::HTTP_DATE.format(can_try_again_at)
      REDIS.set temp_ban_key, is_temp_banned, ex: can_try_again_at
      response.status = :too_many_requests
      response.headers["retry-after"] = is_temp_banned
    end

    call_next context unless response.status.too_many_requests?
  end
end
