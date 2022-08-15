require "../config/redis"
require "../config/cache"

module FetchTagNames
  def fetch_tags(current_user, r, response, session)
    tags = fetch_cached_tag_names

    if filter = r.params["query"]?
      tags.select!(&.starts_with?(filter))
    end

    tags = tags.first(20)

    if current_user
      following_tags = REDIS.smembers("following-tags:#{current_user.id}")
    end

    render "tags/list"
  end

  def fetch_cached_tag_names
    Armature.cache.fetch("cache:all-tags-list", expires_in: 10.minutes) do
      REDIS.ft.tagvals("search:posts", "tags")
        .as(Array)
        .map(&.as(String))
        .sort!
    end
  end
end
