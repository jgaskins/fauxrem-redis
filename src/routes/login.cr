require "./route"
require "../config/redis"
require "../models/user"
require "../bcrypt"

struct Login
  include Route

  def call(context)
    route context do |r, response, session|
      r.root do
        r.get { render "login/form" }
        r.post do
          params = r.form_params
          username = params["username"]?
          password = params["password"]?

          if username && password && valid_authenticity_token?(params, session)
            if (user = REDIS.json.get "user:#{username}", ".", as: User) && (hashed_password_str = REDIS.get("password:#{username}")) && (hashed_password = BCrypt::Password.new(hashed_password_str)) && hashed_password.verify(password)
              session["user_id"] = username
              response.redirect "/"
            else
              response.status = :unprocessable_entity
              response << "Invalid credentials, click the back button to try again"
            end
          else
            response.status = :unprocessable_entity
            response << "Login request must have a username, a password, and a valid authenticity token"
          end
        end
      end
    end
  end
end
