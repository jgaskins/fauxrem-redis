require "./route"
require "../config/redis"
require "../components/breadcrumbs"

require "../models/page"

struct Admin
  include Route

  def initialize(@current_user : User)
  end

  def call(context)
    route context do |r, response, session|
      r.root { r.get { render "admin/index" } }

      r.on "users" { Users.new.call context }
      r.on "pages" { Pages.new.call context }
    end
  end

  struct Users
    include Route

    def call(context)
      route context do |r, response, session|
        r.root { r.get { render "admin/users/index" } }
      end
    end
  end

  struct Pages
    include Route

    def call(context)
      route context do |r, response, session|
        r.root do
          r.get do
            pages = Redis::FullText::JSONSearchResults(Page).new(
              REDIS.ft.search "search:pages", "*",
                sortby: Redis::FullText::SortBy.new("title", :asc),
            )

            render "admin/pages/index"
          end

          r.post do
            params = r.form_params

            title = params["title"]?.presence
            body = params["body"]?.presence

            if title && body
              page = Page.new(
                id: title.downcase.gsub(/\A\W+|\W+\z/, "").gsub(/\W+/, '-'),
                title: title,
                source: body,
                body: UserSuppliedContent.new(body).to_html,
              )
              if REDIS.json.set "page:#{page.id}", ".", page, nx: true
                session["flash.notice"] = "Page created!"
                response.redirect "/admin/pages"
              else
                response.status = :unprocessable_entity
                response << "<h2>Could not save page</h2>"
                response << "<p>A page with this id already exists. Page ids are generated from the title, and must be distinct. Hit the back button and try a new title.</p>"
              end
            end
          end
        end

        r.get "new" { render "admin/pages/new" }
      end
    end
  end
end
