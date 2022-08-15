require "./route"

struct Moderation
  include Route

  def initialize(@current_user : User)
  end

  def call(context)
    route context do |r, response, session|
      r.root { r.get { render "mod/index" } }

      r.on "reports" { Reports.new.call context }
    end
  end
end

struct Moderation::Reports
  include Route

  def call(context)
    route context do |r, response, session|
      r.root do
        r.get do
          results = REDIS.ft.search "search:reports", "-@status:(RESOLVED|IGNORED)",
            sortby: Redis::FullText::SortBy.new("created_at", :asc)
          reports = Redis::FullText::JSONSearchResults(Report).new(results)

          render "mod/reports"
        end
      end

      r.on :id do |id|
        if report = REDIS.json.get("report:#{id}", ".", as: Report)
          r.post "ignore" do
            REDIS.json.set "report:#{id}", ".status", "IGNORED"
            session["flash.notice"] = "Report ignored"
            response.redirect "/mod/reports"
          end

          r.post "unpublish" do
            REDIS.multi do |txn|
              txn.json.del "post:#{report.post_id}", ".published_at"
              txn.json.set "report:#{id}", ".status", "RESOLVED"
            end
            session["flash.notice"] = "Post unpublished"
            response.redirect "/mod/reports"
          end
        end
      end
    end
  end
end

struct Report
  include JSON::Serializable

  getter id = UUID.random
  getter reporter : String
  getter reportee : String
  getter post_id : String
  getter note : String
  getter status : Status = :created
  @[JSON::Field(converter: Time::EpochMillisConverter)]
  getter created_at : Time
  getter resolved_at : Time?
  getter resolved_by : String?

  def initialize(@reporter, @reportee, @post_id, @note, @created_at = Time.utc)
  end

  enum Status
    CREATED
    IGNORED
    RESOLVED
  end
end
