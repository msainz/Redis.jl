type JuliaParser
  "Plain Julia parsing type"
end

type Connection
  "Manages TCP communication to and from a Redis server"
  pid::Int32
  host::ASCIIString
  port::Integer
  db::Uint8
  password
  encoding::ASCIIString
  encoding_errors::ASCIIString
  decode_responses::Bool
  _sock::TcpSocket
  _parser::JuliaParser
  
  function Connection(; host="localhost", port=6379, db=0, password=nothing,
                        encoding="utf-8", encoding_errors="strict",
                        decode_responses=false, parser_type=JuliaParser)
    new(
        getpid(),
        host,
        port,
        db,
        password,
        encoding,
        encoding_errors,
        decode_responses,
        TcpSocket(),
        parser_type() )
  end

end

function connect(conn::Connection)
  "Connects to Redis server if not already connected"
  conn._sock.open && return
  try
    Base.connect(conn._sock, conn.host, conn.port)
  catch e
    println(e)
    throw(ConnectionError())
  end
  on_connect(conn)
end

function on_connect(conn::Connection)
  "Initialize connection, authenticate and select a database"
end
