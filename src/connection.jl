abstract RedisParser

const STR_STAR = "*"
const STR_DOLLAR = "\$"
const STR_CRLF = "\r\n"
const STR_LF = "\n"

type SimpleParser <: RedisParser
  # Simple redis parser implementation
  sock::TcpSocket
end

type Connection
  # Manages TCP communication to and from a Redis server
  pid::Int32
  host::ASCIIString
  port::Integer
  db::Integer
  password::Union(Nothing,ASCIIString)
  sock::TcpSocket
  parser::RedisParser
  
  function Connection(; host="localhost", port=6379, db=0, password=nothing,
                        parser_type=SimpleParser)
    sock = TcpSocket()
    conn = new(
        getpid(),
        host,
        port,
        db,
        password,
        sock,
        parser_type(sock) )

    finalizer(conn, disconnect)
    conn
  end

end # type Connection

## Connect methods ##

function connect(conn::Connection)
  # Connects to Redis server if not already connected
  conn.sock.open && return conn
  try
    Base.connect(conn.sock, conn.host, conn.port)
  catch e
    println(e)
    msg = "Error connecting to Redis [ host:$(conn.host), port:$(conn.port) ]"
    throw(ConnectionError(msg))
  end
  on_connect(conn)
end

function on_connect(conn::Connection)
  # Initialize connection, authenticate and select a database
  on_connect(conn.parser, conn)

  # if password given, authenticate
  if conn.password != nothing
    send_command(conn, "AUTH", conn.password)
    read_response(conn) == "OK" || throw(AuthenticationError("Invalid password"))
  end

  # switch to given database
  send_command(conn, "SELECT", conn.db)
  read_response(conn) == "OK" || throw(ConnectionError("Invalid database"))

  conn
end

function on_connect(parser::RedisParser, conn::Connection)
  # Called when the socket connects
end

## Disconnect methods ##

function disconnect(conn::Connection)
  # Disconnects from Redis server
  on_disconnect(conn.parser)
  conn.sock.open || return conn
  try
    close(conn.sock)
  catch
  end
  conn
end

function on_disconnect(parser::RedisParser)
  # Called when then socket disconnects
end

## Send methods ##

function send_command(conn::Connection, args...)
  # Pack and send a command to Redis
  send_packed_command(conn, pack_command(args...))
end

function send_packed_command(conn::Connection, cmd::Vector{Uint8})
  # Send a packed command to Redis
  if !conn.sock.open
    connect(conn)
  end
  try
    write(conn.sock, cmd)
    return
  catch e
    disconnect(conn)
    rethrow(e)
  end
end

encode(value::Vector{Uint8}) = value
encode(value) = string(value)

function pack_command(args...)
  # Pack a sequence of args into a Redis command
  o = IOBuffer()
  write(o, STR_STAR)
  write(o, string(length(args)) )
  write(o, STR_CRLF)
  for enc_val in map(encode, args)
    write(o, STR_DOLLAR)
    write(o, string(length(enc_val)) )
    write(o, STR_CRLF)
    write(o, enc_val )
    write(o, STR_CRLF)
  end
  o.data
end

## Read methods ##

function read_response(conn::Connection)
  # Read the response from a previously sent command
  response = nothing
  try
    response = read_response(conn.parser)
    isa(response, ResponseError) && throw(response)
    return response
  catch e
    disconnect(conn)
    rethrow(e)
  end
end

function read_response(parser::RedisParser)
  bytes::Vector{Uint8} = read(parser)
  byte::Uint8, response::UTF8String = bytes[1], UTF8String(bytes[2:])
  contains( ('-', '+', ':', '$', '*'), byte) || throw(InvalidResponse("Protocol error"))
  if byte == '-'
    # Error reply:
    # the first word after the "-" up to the first space or newline
    # represents the kind of error returned
    error("todo: implement me!")
  elseif byte == '+'
    # Status reply:
    # not binary safe and can't include newlines
    return response
  elseif byte == ':'
    # Integer reply:
    # guaranteed to be in the range of a signed 64-bit integer
    return int(response)
  elseif byte == '$'
    # Bulk reply:
    # returns a single binary safe string up to 512 MB in length.
    # The server sends as the first line a "$" byte followed by the number of
    # bytes of the actual reply, followed by CRLF, then the actual data bytes
    # are sent, followed by additional two bytes for the final CRLF
    len = int(response)
    # If the requested value does not exist the bulk reply will use the special
    # value -1 as data length. This is called a NULL Bulk Reply
    len == -1 && return nothing
    return read(parser, len)
  elseif byte == '*'
    # Multi Bulk reply:
    # used to return an array of other replies. Every element of a Multi Bulk
    # reply can be of any kind, including a nested Multi Bulk reply
    len = int(response)
    # Null Multi Bulk Reply exists
    len == -1 && return nothing
    return { read_response(parser) for i in 1:len }
  end
end

function read(parser::RedisParser)
  # Read and strip a line from the socket
  readuntil(parser.sock, STR_CRLF)[1:(end-2)]
end

function read(parser::RedisParser, len::Int)
  # Read `len` bytes from the socket, and strip trailing CRLF
  # todo: implement efficiently
  buf = readuntil(parser.sock, STR_CRLF)[1:(end-2)]
  buf[1:len]
end
