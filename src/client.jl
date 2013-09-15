
function string_keys_to_dict(keys::ASCIIString, callback::Function)
  keys_arr = convert(Array{ASCIIString}, split(keys)) # split returns Array{String}
  vals_arr = repeat([callback]; inner = [length(keys_arr)])
  Dict(keys_arr, vals_arr)
end

function parse_info(response::UTF8String)
  # Parse the result of Redis's INFO command into a julia dict
  info = Dict()
  function get_value(value)
    if !(',' in value) || !('=' in value)
      try
        if '.' in value
          return float(value)
        else
          return int(value)
        end
      catch ArgumentError
        return value
      end
    else # ',' or '=' in value
      sub_dict = Dict()
      for item in split(value, ',')
        k, v = rsplit(item, '=', 2)
        sub_dict[k] = get_value(v)
      end
      return sub_dict
    end
  end

  for line in split(response, "\r\n")
    if length(line) > 0 && !beginswith(line, '#')
      key, value = split(line, ':', 2)
      info[key] = get_value(value)
    end
  end
  return info
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
  ),
  string_keys_to_dict(
    "FLUSHALL FLUSHDB LSET LTRIM MSET RENAME " *
    "SAVE SELECT SHUTDOWN SLAVEOF WATCH UNWATCH",
    (r) -> ismatch(r"OK", r)
  ),
  {
    "BGREWRITEAOF" => (r) -> ismatch(r"rewriting started", r),
    "BGSAVE" => (r) -> ismatch(r"saving started", r),
    "INFO" => parse_info
  }
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

#### COMMAND EXECUTION AND PROTOCOL PARSING ####

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
  if in(command_name, keys(client.response_callbacks))
    return client.response_callbacks[command_name](response, options...)
  end
  response
end

#### SERVER INFORMATION COMMANDS ####
function bgrewriteaof(client::RedisClient)
  # Tell the Redis server to rewrite the AOF file from data in memory.
  execute_command(client, "BGREWRITEAOF")
end

function bgsave(client::RedisClient)
  # Tell the Redis server to save its data to disk.  Unlike save(),
  # this method is asynchronous and returns immediately.
  execute_command(client, "BGSAVE")
end

# function client_kill(client::RedisClient, address)
  # # Disconnects the client at ``address`` (ip:port)
  # execute_command('CLIENT', 'KILL', address, parse='KILL')
# end

# function client_list(client::RedisClient)
  # # Returns a list of currently connected clients
  # execute_command('CLIENT', 'LIST', parse='LIST')
# end

# function client_getname(client::RedisClient)
  # # Returns the current connection name
  # execute_command('CLIENT', 'GETNAME', parse='GETNAME')
# end

# function client_setname(client::RedisClient, name)
  # # Sets the current connection name
  # execute_command('CLIENT', 'SETNAME', name, parse='SETNAME')
# end

# function config_get(client::RedisClient, pattern="*")
  # # Return a dictionary of configuration based on the ``pattern``
  # execute_command('CONFIG', 'GET', pattern, parse='GET')
# end

# function config_set(client::RedisClient, name, value)
  # # Set config item ``name`` with ``value``
  # execute_command('CONFIG', 'SET', name, value, parse='SET')
# end

# function config_resetstat(client::RedisClient)
  # # Reset runtime statistics
  # execute_command('CONFIG', 'RESETSTAT', parse='RESETSTAT')
# end

function dbsize(client::RedisClient)
  # Returns the number of keys in the current database
  execute_command(client, "DBSIZE")
end

# function debug_object(client::RedisClient, key)
  # # Returns version specific metainformation about a given key
  # execute_command('DEBUG', 'OBJECT', key)
# end

function echo(client::RedisClient, value)
  # Echo the string back from the server
  execute_command(client, "ECHO", value)
end

function flushall(client::RedisClient)
  # Delete all keys in all databases on the current host
  execute_command(client, "FLUSHALL")
end

function flushdb(client::RedisClient)
  # Delete all keys in the current database
  execute_command(client, "FLUSHDB")
end

function info(client::RedisClient, section=nothing)
  # Returns a dictionary containing information about the Redis server.
  # The ``section`` option can be used to select a specific section
  # of information
  # The section option is not supported by older versions of Redis Server,
  # and will generate ResponseError
  section == nothing && return execute_command(client, "INFO")
  execute_command(client, "INFO", section)
end

# function lastsave(client::RedisClient)
  # # Return a Python datetime object representing the last time the
  # # Redis database was saved to disk
  # execute_command('LASTSAVE')
# end

# function object(client::RedisClient, infotype, key)
  # # Return the encoding, idletime, or refcount about the key
  # execute_command('OBJECT', infotype, key, infotype=infotype)
# end

# function ping(client::RedisClient)
  # # Ping the Redis server
  # execute_command('PING')
# end

# function save(client::RedisClient)
  # # Tell the Redis server to save its data to disk,
  # # blocking until the save is complete
  # execute_command('SAVE')
# end

# function sentinel(client::RedisClient, *args)
  # # Redis Sentinel's SENTINEL command
  # if args[0] in ['masters', 'slaves', 'sentinels']:
      # parse = 'SENTINEL_INFO'
  # else:
      # parse = 'SENTINEL'
  # execute_command('SENTINEL', *args, **{'parse': parse})
# end

# function shutdown(client::RedisClient)
  # # Shutdown the server
  # try:
      # self.execute_command('SHUTDOWN')
  # except ConnectionError:
      # # a ConnectionError here is expected
      # return
  # raise RedisError("SHUTDOWN seems to have failed.")
# end

# function slaveof(client::RedisClient, host=None, port=None)
  # # Set the server to be a replicated slave of the instance identified
  # # by the ``host`` and ``port``. If called without arguements, the
  # # instance is promoted to a master instead.
  # if host is None and port is None:
      # execute_command("SLAVEOF", "NO", "ONE")
  # execute_command("SLAVEOF", host, port)
# end

# function time(client::RedisClient)
  # # Returns the server time as a 2-item tuple of ints:
  # # (seconds since epoch, microseconds into this second).
  # execute_command('TIME')
# end

