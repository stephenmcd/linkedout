require "datamapper"

class ApiKey
  include DataMapper::Resource

  property :id, Serial
  property :token, String
  property :secret, String
end

DataMapper.setup(:default, ENV["DATABASE_URL"] || "sqlite3://#{Dir.pwd}/linkedout.db")
DataMapper.finalize
DataMapper.auto_upgrade!
