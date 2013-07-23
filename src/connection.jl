abstract RedisParser

const STR_STAR = "*"
const STR_DOLLAR = "\$"
const STR_CRLF = "\r\n"
const STR_LF = "\n"

type SimpleParser <: RedisParser
  # Simple redis parser implementation
  server::Base.TcpServer
  SimpleParser() = new( Base.TcpServer() )
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
    conn = new(
        getpid(),
        host,
        port,
        db,
        password,
        TcpSocket(),
        parser_type() )

    finalizer(conn, disconnect)
    conn
  end

end # type Connection

## Connect methods ##

function connect(conn::Connection)
  # Connects to Redis server if not already connected
  conn.sock.open && return
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
  if !conn.sock.open; connect(conn) end
  try
    write(conn.sock, cmd)
  catch e
    println(e)
    throw(ConnectionError("Error while writing to socket"))
  finally
    disconnect(conn) # todo: not if success!
  end
  true
end

encode(value::Vector{Uint8}) = value
encode(value) = string(value)

function pack_command(args...)
  # Pack a sequence of args into a value Redis command
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
  "OK"
end
