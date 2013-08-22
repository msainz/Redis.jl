
function string_keys_to_dict(keys::ASCIIString, callback::Function)
  keys_arr = convert(Array{ASCIIString}, split(keys)) # split returns Array{String}
  vals_arr = repeat([callback]; inner = [length(keys_arr)])
  Dict(keys_arr, vals_arr)
end

const RESPONSE_CALLBACKS = merge(
  string_keys_to_dict(
    "AUTH EXISTS EXPIRE EXPIREAT HEXISTS HMSET MOVE MSETNX PERSIST " *
    "PSETEX RENAMENX SISMEMBER SMOVE SETEX SETNX",
    bool
  ),
  string_keys_to_dict(
    "BITCOUNT DECRBY DEL GETBIT HDEL HLEN INCRBY LINSERT LLEN LPUSHX " *
    "RPUSHX SADD SCARD SDIFFSTORE SETBIT SETRANGE SINTERSTORE SREM " *
    "STRLEN SUNIONSTORE ZADD ZCARD ZREM ZREMRANGEBYRANK " *
    "ZREMRANGEBYSCORE",
    int
  )
)

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
  response_callbacks::Dict{ASCIIString, Function}
end # type RedisClient

function redis(; host="localhost", port=6379, db=0, password=nothing,
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
  RedisClient(connection_pool, RESPONSE_CALLBACKS) # TODO: (deep)copy RESP_CALLBKS?
end

## Command execution and protocol parsing ##

function execute_command(client::RedisClient, args...; options...)
  # Execute a command and return a parsed response
  pool = client.connection_pool
  command_name = args[1]
  connection = get_connection(pool)
  try
    send_command(connection, args...)
    return parse_response(client, connection, command_name; options...)
  catch err
    @show err
    if isa(err, ConnectionError)
      disconnect(connection)
      send_command(connection, command_name; options...)
      return parse_response(client, connection, command_name; options...)
    end
  finally
    release(pool, connection)
  end
end

function parse_response(client::RedisClient, conn::Connection,
                        command_name::ASCIIString; options...)
  # Parses a response from the Redis server
  response = read_response(conn)
  if contains(keys(client.response_callbacks), command_name)
    return client.response_callbacks[command_name](response, options...)
  end
  response
end
