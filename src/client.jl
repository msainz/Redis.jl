
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
        "SAVE SELECT SHUTDOWN SLAVEOF WATCH UNWATCH RESTORE",
        (r) -> ismatch(r"OK", r)
    ),
    {
        "BGREWRITEAOF" => (r) -> ismatch(r"rewriting started", r),
        "BGSAVE" => (r) -> ismatch(r"saving started", r),
        "INFO" => parse_info,
        "PING" => (r) -> ismatch(r"PONG", r),
        "SET" => (r) -> (nothing != r) && ismatch(r"OK", r),
        "DUMP" => (r) -> (nothing == r) ? nothing : convert(Vector{Uint8}, r),
        "TIME" => (r) -> ( int(r[1]), int(r[2]) )
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

function execute_set_command(client::RedisClient, command::String, name::String, value, unpack)
    # temporary might need to change
    if unpack == true
        execute_command(client, command, name, value...)
    else
        execute_command(client, command, name, value)
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
    # Tell the Redis server to save its data to disk.    Unlike save(),
    # this method is asynchronous and returns immediately.
    execute_command(client, "BGSAVE")
end

function dbsize(client::RedisClient)
    # Returns the number of keys in the current database
    execute_command(client, "DBSIZE")
end

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

function ping(client::RedisClient)
    # Ping the Redis server
    execute_command(client, "PING")
end

function save(client::RedisClient)
    # Tell the Redis server to save its data to disk,
    # blocking until the save is complete
    execute_command(client, "SAVE")
end

function time(client::RedisClient)
    # Returns the server time as a 2-item tuple of ints:
    # (seconds since epoch, microseconds into this second).
    execute_command(client, "TIME")
end

#### BASIC KEY COMMANDS ####
function append(client::RedisClient, key::String, value)
    # Appends the string ``value`` to the value at ``key``. If ``key``
    # doesn't already exist, create it with a value of ``value``.
    # Returns the new length of the value at ``key``.
    execute_command(client, "APPEND", key, value)
end

import Base.keys
function keys(client::RedisClient, pattern="*")
    # Returns a list of keys matching ``pattern``
    execute_command(client, "KEYS", pattern)
end

function incr(client::RedisClient, name::String, amount::Int=1)
    # Increments the value of ``key`` by ``amount``.    If no key exists,
    # the value will be initialized as ``amount``
    execute_command(client, "INCRBY", name, amount)
end

function decr(client::RedisClient, name::String, amount::Int=1)
    # Decrements the value of ``key`` by ``amount``.    If no key exists,
    # the value will be initialized as 0 - ``amount``
    execute_command(client, "DECRBY", name, amount)
end

function del(client::RedisClient, names...)
    # Delete one or more keys specified by ``names``
    execute_command(client, "DEL", names...)
end

restore(client::RedisClient, name::String, value::Vector{Uint8}) = restore(client, name, 0, value)
function restore(client::RedisClient, name::String, ttl::Int, value::Vector{Uint8})
    # Create a key using the provided serialized value, previously obtained using DUMP.
    # If ``ttl`` is 0, the key is created without any expire, otherwise the specified expire
    # time (in milliseconds) is set.
    execute_command(client, "RESTORE", name, ttl, value)
end

function dump(client::RedisClient, name::String)
    # Return a serialized version of the value stored at the specified key.
    # If key does not exist a ``nothing`` bulk reply is returned.
    execute_command(client, "DUMP", name)
end

function exists(client::RedisClient, name::String)
    # Returns a boolean indicating whether key ``name`` exists
    execute_command(client, "EXISTS", name)
end

function get(client::RedisClient, name::String)
    # Return the value at key ``name``, or ``nothing`` if the key doesn't exist
    execute_command(client, "GET", name)
end

function set(client::RedisClient, name::String, value; ex=nothing, px=nothing, nx::Bool=false, xx::Bool=false)
    # Set the value at key ``name`` to ``value``
    # ``ex`` sets an expire flag on key ``name`` for ``ex`` seconds.
    # ``px`` sets an expire flag on key ``name`` for ``px`` milliseconds.
    # ``nx`` if set to True, set value at key ``name`` to ``value`` if not already exists.
    # ``xx`` if set to True, set value at key ``name`` to ``value`` if already exists.
    pieces = [name, value]
    if nothing != ex
        push!(pieces, "EX")
        push!(pieces, ex)
    end
    if nothing != px
        push!(pieces, "PX")
        push!(pieces, px)
    end
    nx && push!(pieces, "NX")
    xx && push!(pieces, "XX")
    execute_command(client, "SET", pieces...)
end

#### LISTS ####

function lindex(client::RedisClient, name::String, index::Int64)
    # LINDEX key index
    # Get an element from a list by its index
    execute_command(client, "LINDEX", name, index)
end

function linsert(client::RedisClient, name::String, postition::String, pivot, value)
    # LINSERT key BEFORE|AFTER pivot value
    # Insert an element before or after another element in a list
    execute_command(client, "LINSERT", name, postition, pivot, value)
end

function llen(client::RedisClient, name::String)
    # LLEN key
    #Get the length of a list
    execute_command(client, "LLEN", name)
end

function lpop(client::RedisClient, name::String)
    # LPOP key
    # Remove and get the first element in a list
    execute_command(client, "LPOP", name)
end

function lpush(client::RedisClient, name::String, value; unpack::Bool=false)
    # LPUSH key value [value ...]
    # Prepend one or multiple values to a list
    execute_set_command(client, "LPUSH", name, value, unpack)
end

function lpushx(client::RedisClient, name::String, value)
    # LPUSH key value [value ...]
    # Prepend one or multiple values to a list
    execute_command(client, "LPUSHX", name, value)
end

function lrange(client::RedisClient, name::String, start::Int64, stop::Int64)
    # LRANGE key start stop
    # Get a range of elements from a list
    execute_command(client, "LRANGE", name, start, stop)
end

function lrem(client::RedisClient, name::String, count::Int64, value)
    # LREM key count value
    # Remove elements from a list
    execute_command(client, "LREM", name, count, value)
end

function lset(client::RedisClient, name::String, index::Int64, value)
    # LSET key index value
    # Set the value of an element in a list by its index
    execute_command(client, "LSET", name, index, value)
end

function ltrim(client::RedisClient, name::String, start::Int64, stop::Int64)
    # LTRIM key start stop
    # Trim a list to the specified range
    execute_command(client, "LTRIM", name, start, stop)
end

#### SETS ####

function sadd(client::RedisClient, name::String)
    # SADD key member [member ...]
    # Add one or more members to a set 
    execute_command(client, "SADD", name)
end

function smove(client::RedisClient, name::String)
    # SMOVE source destination member
    # Move a member from one set to another
    execute_command(client, "SMOVE", name)
end

function scard(client::RedisClient, name::String)
    # SCARD key
    # Get the number of members in a set 
    execute_command(client, "SCARD", name)
end

function spop(client::RedisClient, name::String)
    # SPOP key
    # Remove and return a random member from a set 
    execute_command(client, "SPOP", name)
end

function sdiff(client::RedisClient, name::String)
   #SDIFF key [key ...] 
   #Subtract multiple sets 
    execute_command(client, "SDIFF", name)
end

function srandmember(client::RedisClient, name::String)
    # SRANDMEMBER key [count]
    # Get one or multiple random members from a set 
    execute_command(client, "SRANDMEMBER", name)
end

function sdiffstore(client::RedisClient, name::String)
   # SDIFFSTORE destination key [key ...]
   # Subtract multiple sets and store the resulting set in a key 
    execute_command(client, "SDIFFSTORE", name)
end

function srem(client::RedisClient, name::String)
    # SREM key member [member ...]
    # Remove one or more members from a set 
    execute_command(client, "SREM", name)
end

function sinter(client::RedisClient, name::String)
    # SINTER key [key ...]
    # Intersect multiple sets 
    execute_command(client, "SINTER", name)
end

function sunion(client::RedisClient, name::String)
    # SUNION key [key ...]
    # Add multiple sets 
    execute_command(client, "SUNION", name)
end

function sinterstore(client::RedisClient, name::String)
    # SINTERSTORE destination key [key ...]
    # Intersect multiple sets and store the resulting set in a key 
    execute_command(client, "SINTERSTORE", name)
end

function sunionstore(client::RedisClient, name::String)
    # SUNIONSTORE destination key [key ...]
    # Add multiple sets and store the resulting set in a key 
    execute_command(client, "SUNIONSTORE", name)
end

function sismember(client::RedisClient, name::String)
    # SISMEMBER key member
    # Determine if a given value is a member of a set 
    execute_command(client, "SISMEMBER", name)
end

function sscan(client::RedisClient, name::String)
    # SSCAN key cursor [MATCH pattern] [COUNT count]
    # Incrementally iterate Set elements 
    execute_command(client, "SSCAN", name)
end

function smembers(client::RedisClient, name::String)
    # SMEMBERS key
    # Get all the members in a set 
    execute_command(client, "LTRIM", name)
end
