require "./route"
require "../config/redis"
require "../models/user"
require "../bcrypt"

struct Signup
  include Route

  def call(context)
    route context do |r, response, session|
      r.root do
        r.get { render "signup/form" }
        r.post do
          params = r.form_params
          username = params["username"]?
          name = params["name"]?
          password = params["password"]?

          if username && valid_username?(username) && name && password && valid_authenticity_token?(params, session)
            user = User.new(
              id: username,
              name: name,
            )
            if REDIS.json.set "user:#{username}", ".", user, nx: true
              REDIS.set "password:#{username}", BCrypt::Password.create(password).to_s
              session["user_id"] = username
              response.redirect "/"
            else
              response.status = :unprocessable_entity
              response << "User with that username already exists, click the back button and choose another username"
            end
          else
            response.status = :unprocessable_entity
            response << "Signup request must have a username, a display name, a password, and a valid authenticity token. Usernames can only contain alphanumeric characters."
          end
        end
      end
    end
  end

  def valid_username?(username : String)
    username =~ /\A\w+\z/
  end
end
