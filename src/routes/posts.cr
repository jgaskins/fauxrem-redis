require "./route"

require "../user_supplied_content"
require "../config/redis"
require "../models/user"
require "../models/post"
require "../models/comment"

struct Posts
  include Route

  def initialize(@current_user : User?)
  end

  def call(context)
    route context do |r, response, session|
      r.root do
        r.get do
          filter = [
            Redis::FullText::Filter.new("published_at", 30.days.ago.at_beginning_of_day.to_unix_ms.."+inf"),
          ]
          page = r.params.fetch("page", 1).to_i64

          if current_user = @current_user
            following = REDIS.smembers("following:#{current_user.id}")
            following << current_user.id

            following_tags = REDIS.smembers("following-tags:#{current_user.id}")
            blocked_words = REDIS.smembers("blocked-words:#{current_user.id}")

            query = String.build do |str|
              str << "@author:("
              following.each_with_index 1 do |user, index|
                user.inspect str
                str << "|" if index < following.size
              end
              str << ")"

              if following_tags.any?
                str << " | @tags:{"
                following_tags.each_with_index 1 do |tag, index|
                  str << tag.as(String).gsub(/\W/) { |ch| "\\#{ch}" }
                  str << "|" if index < following_tags.size
                end
                str << "}"
              end

              if blocked_words.any?
                str << " -("
                blocked_words.each_with_index 1 do |word, index|
                  word.inspect str
                  str << "|" if index < blocked_words.size
                end
                str << ")"
              end
            end
            per_page = 50
            # puts query # for debugging
            raw = REDIS.ft.search "search:posts", query,
              filter: filter,
              return: %w[$.id $.title $.author $.published_at $.tags],
              sortby: Redis::FullText::SortBy.new("published_at", :desc),
              limit: {(page - 1) * per_page, per_page}
          else
            per_page = 20
            raw = REDIS.ft.search "search:posts", "*",
              filter: filter,
              return: %w[$.id $.title $.author $.published_at $.tags],
              sortby: Redis::FullText::SortBy.new("popularity", :desc),
              limit: {(page - 1) * per_page, per_page}
          end
          posts = Redis::FullText::PropertySearchResults({String, String, String, String, String?}).new(raw)

          render "posts/list"
        end

        # Authenticated-only subroute
        if current_user = @current_user
          r.post do
            params = r.form_params
            title = params["title"]?.presence
            body = params["body"]?.presence
            tags = params["tags"]?

            if title && body && tags && valid_authenticity_token?(params, session)
              post = Post.new(
                id: "#{title.strip.downcase}-#{Random::Secure.hex(3)}".gsub(/\W+/, '-'),
                author: current_user.id,
                title: title.strip,
                source: body,
                body: UserSuppliedContent.new(body).to_html,
                tags: tags.split(/\s*,\s*/)
              )

              REDIS.json.set("post:#{post.id}", ".", post, nx: true)

              session["flash.notice"] = "Post submitted"
              response.redirect "/posts/#{post.id}"
            else
              response.status = :unprocessable_entity
              errors = String.build do |str|
                render "posts/errors", to: str
              end
              render "posts/form"
            end
          end
        end
      end

      if current_user = @current_user
        r.get "new" do
          title = nil
          tags = nil
          body = nil
          errors = nil
          render "posts/form"
        end
      end

      r.on :id do |id|
        post_key = "post:#{id}"
        if post = REDIS.json.get(post_key, ".", as: Post)
          r.root do
            r.get do
              like_count = REDIS.scard("likes:#{post_key}")

              render "posts/show"
            end
          end

          r.post "viewed" do
            REDIS.json.numincrby post_key, ".popularity", 1
          end

          if current_user = @current_user
            r.post "likes" do
              if current_user.id != post.author
                like_key = "likes:post:#{post.id}"
                if REDIS.sadd(like_key, current_user.id) == 0
                  # Already liked, so we remove the like and any notifications that were generated from it
                  REDIS.srem like_key, current_user.id
                  REDIS.json.numincrby post_key, ".popularity", -5
                  session["flash.notice"] = "Like removed"
                  # Delete the notification that was sent when liking this post
                  result = Redis::FullText::JSONSearchResults(Notification).new(
                    REDIS.ft.search "search:notifications", <<-QUERY.tap { |q| puts q }, limit: {0, 1}
                    @recipient:#{post.author}
                    @title:"#{current_user.id} liked your post"
                    @title:#{post.title.inspect}
                  QUERY
                  )
                  result.each do |(key, notification)|
                    REDIS.unlink key
                  end
                else # Like was created, so we create a notification for the author
                  REDIS.pipeline do |pipe|
                    pipe.json.numincrby post_key, ".popularity", 5
                    notification = Notification.new(
                      title: "#{current_user.id} liked your post 👍 — #{post.title}",
                      recipient: post.author,
                      body: nil,
                      path: "/posts/#{post.id}",
                    )
                    notification_key = "notification:#{notification.id}"
                    pipe.json.set notification_key, ".", notification
                    pipe.expire notification_key, 1.week
                    session["flash.notice"] = "Liked!"
                  end
                end

                response.redirect "/posts/#{post.id}"
              else
                session["flash.alert"] = "Cannot like your own posts"
                response.redirect "/posts/#{post.id}"
              end
            end
          end

          if (current_user = @current_user) && (post.author == current_user.id || current_user.admin?)
            unless referer = r.headers["referer"]?
              response.status = :bad_request
              response << "<h2>Must use a publish/unpublish button</h2>"
              return
            end

            r.post "publish" do
              REDIS.json.set "post:#{id}", ".published_at", Time.utc.to_unix_ms
              session["flash.notice"] = "Post published"
              response.redirect referer
            end

            r.post "unpublish" do
              REDIS.json.del "post:#{id}", ".published_at"
              session["flash.notice"] = "Post unpublished"
              response.redirect referer
            end
          end

          if current_user = @current_user
            r.on "comments" { Comments.new(current_user, post).call context }
            r.on "reports" { Reports.new(current_user, post).call context }
          end
        end
      end
    end
  end

  def post_list_type
    "Your feed"
  end

  struct Comments
    include Route

    def initialize(@current_user : User, @post : Post)
    end

    def call(context)
      route context do |r, response, session|
        r.root do
          r.post do
            body = r.form_params["body"]?

            if body && valid_authenticity_token?(r.form_params, session)
              key = "post:#{@post.id}"
              REDIS.pipeline do |pipe|
                pipe.json.set key, ".comments", Tuple.new, nx: true
                pipe.json.arrappend key, ".comments", Comment.new(
                  id: UUID.random,
                  author: @current_user.id,
                  body: UserSuppliedContent.new(body).to_html,
                  source: body,
                )
                pipe.json.numincrby key, ".popularity", 10

                notification = Notification.new(
                  title: "#{@current_user.id} left a comment on your post",
                  recipient: @post.author,
                  body: body,
                  path: "/posts/#{@post.id}",
                )
                notification_key = "notification:#{notification.id}"
                pipe.json.set notification_key, ".", notification
                pipe.expire notification_key, 1.week
              end
              response.redirect "/posts/#{@post.id}"
            else
              response.status = :bad_request
            end
          end
        end
      end
    end
  end

  struct Reports
    include Route

    def initialize(@current_user : User, @post : Post)
    end

    def call(context)
      route context do |r, response, session|
        r.root do
          r.post do
            params = r.form_params
            if (note = params["note"]?) && valid_authenticity_token?(params, session)
              report = Report.new(
                reporter: @current_user.id,
                reportee: @post.author,
                post_id: @post.id,
                note: note,
              )

              REDIS.json.set "report:#{report.id}", ".", report
              session["flash.notice"] = "Report sent successfully"
              response.redirect "/posts/#{@post.id}"
            end
          end
        end
      end
    end
  end
end

struct URI::Params
  def without(key : String)
    new = dup
    new.delete_all key
    new
  end
end
