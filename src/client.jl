type RedisClient
  # Implementation of the Redis protocol
  # http://redis.io/topics/protocol
  #
  # This type abstracts a julia interface to all Redis commands
  # and an implementation of the Redis protocol.
  #
  # Connection and Pipeline implement how the commands are sent
  # and received to and from the Redis server
  connection_pool::ConnectionPool
  response_callbacks::Dict
end # type RedisClient

function redis(; host="localhost", port=6739, db=0, password=nothing,
                 connection_pool=nothing, charset="utf-8")
  if connection_pool==nothing
    kvargs = [
      :host => host,
      :port => port,
      :db => db,
      :password => password
      # TODO: :encoding => charset
    ]
    connection_pool = ConnectionPool(; kvargs...)
  end
  # self.response_callbacks = self.__class__.RESPONSE_CALLBACKS.copy()
  RedisClient(connection_pool, Dict())
end

## Command execution and protocol parsing ##

function execute_command(client::RedisClient, args...; options...)
  # Execute a command and return a parsed response  
  pool = client.connection_pool
  command_name = args[1]
  @show repeat("=",50)
  @show connection = get_connection(pool)
  @show args
  try
    send_command(connection, args...)
    return parse_response(client, connection; options...)
  catch err
    @show err
    if isa(err, ConnectionError)
      disconnect(connection)
      send_command(connection, command_name; options...)
      return parse_response(client, connection; options...)
    end
  finally
    release(pool, connection)
  end
end

function parse_response(client::RedisClient, conn::Connection,
                        command_name::ASCIIString; options...)
  # Parses a response from the Redis server
  response = read_response(connection)
  # if command_name in self.response_callbacks:
      # return self.response_callbacks[command_name](response, **options)
  # return response
end
