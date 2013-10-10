abstract RedisParser
import Base.connect
import Base.TcpSocket
import Base.StatusInit,
       Base.StatusConnecting, # todo: use me!
       Base.StatusOpen,
       Base.StatusActive,
       Base.StatusClosing,    # todo: use me!
       Base.StatusClosed

const STR_STAR = "*"
const STR_DOLLAR = "\$"
const STR_CRLF = "\r\n"
const STR_LF = "\n"

type SimpleParser <: RedisParser
  # Simple redis parser implementation
  sock::TcpSocket
  MAX_READ_LENGTH::Integer
  SimpleParser(sock) = new(sock, 1048576) # 1MB
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

#
# TODO: wait for timeout seconds when trasitioning (StatusConnecting or StatusClosing)
#

function open_or_active(sock::TcpSocket)
  sock.status == StatusOpen || sock.status == StatusActive
end

## Connect methods ##

function connect(conn::Connection)
  # Connects to Redis server if not already connected
  open_or_active(conn.sock) && return conn
  try
    connect(conn.sock, conn.host, conn.port)
  catch err
    msg = "Error connecting to Redis [ host:$(conn.host), port:$(conn.port) ]"
    throw(ConnectionError("$msg, $err"))
  end
  on_connect(conn)
end

function on_connect(conn::Connection)
  # Initialize connection, authenticate and select a database

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

## Disconnect methods ##

function disconnect(conn::Connection)
  # Disconnects from Redis server
  on_disconnect(conn.parser)
  (conn.sock.status == StatusClosed) && return conn
  try
    close(conn.sock)
    sleep(.1) # TODO: necessary? better way?
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
  if conn.sock.status == StatusInit
    connect(conn)
  end
  @assert open_or_active(conn.sock)
  try
    write(conn.sock, cmd)
    return
  catch err
    disconnect(conn)
    rethrow(err)
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
  catch err
    disconnect(conn)
    rethrow(err)
  end
end

function read_response(parser::RedisParser)
  bytes::Vector{Uint8} = read(parser)
  byte::Uint8 = bytes[1]
  response::UTF8String = UTF8String(bytes[2:])
  in(char(byte), "- + : \$ *") || throw(InvalidResponse("Protocol error"))
  if byte == '-'
    # Error reply:
    # the first word after the "-" up to the first space or newline
    # represents the kind of error returned
    @show response
    error("TODO: implement me!")
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
    return UTF8String( read(parser, len) )
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

function read(parser::RedisParser, len::Integer)
  # Read `len` bytes from the socket, and strip trailing CRLF
  try
    bytes_left = len + 2  # read the CRLF
    if len > parser.MAX_READ_LENGTH
        # apparently reading more than 1MB or so from a windows
        # socket can cause MemoryErrors. See:
        # https://github.com/andymccurdy/redis-py/issues/205
        # read smaller chunks at a time to work around this
        try
          buf = IOBuffer()
          while bytes_left > 0
            read_len::Int = min(bytes_left, parser.MAX_READ_LENGTH)
            write(buf, Base.read(parser.sock, Uint8, read_len))
            bytes_left -= read_len
          end
          seek(buf,0)
          return read(buf, Uint8, len)
        finally
          close(buf)
        end
    else
      return Base.read(parser.sock, Uint8, bytes_left)[1:(end-2)]
    end
  catch err
    throw(ConnectionError("Error while reading from socket: $err)"))
  end
end
