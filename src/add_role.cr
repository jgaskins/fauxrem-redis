require "option_parser"
require "./config/redis"
require "./models/user"

OptionParser.parse ARGV do |parser|
  parser.banner = "Usage: bin/add_role {admin|mod} {user_id}"
  %w[admin mod].each do |role|
    parser.on role, "Add #{role} role to the given user" do
      if user_id = ARGV[1]?
        user_key = "user:#{user_id}"
        REDIS.pipeline do |pipe|
          pipe.json.set user_key, ".roles", %w[], nx: true
          pipe.json.arrappend user_key, ".roles", role
        end
        puts "Added #{role} role to #{user_id}"
        pp REDIS.json.get user_key, ".", as: User
      else
        puts parser
        exit 1
      end
    end
  end
end
