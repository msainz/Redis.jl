type ConnectionError <: Exception; end

type JuliaParser
  "Plain Julia parsing type"
end

type Connection
  "Manages TCP communication to and from a Redis server"
  pid::Int32
  host::ASCIIString
  port::Uint16
  db::Uint8
  password
  socket_timeout
  encoding::ASCIIString
  encoding_errors::ASCIIString
  decode_responses::Bool
  _sock::TcpSocket
  _parser::JuliaParser
  
  function Connection(host="localhost", port=6379, db=0, password=nothing,
                      socket_timeout=nothing, encoding="utf-8",
                      encoding_errors="strict", decode_responses=false,
                      parser_type=JuliaParser)
    new(
        getpid(),
        host,
        port,
        db,
        password,
        socket_timeout,
        encoding,
        encoding_errors,
        decode_responses,
        TcpSocket(),
        parser_type() )
  end

end

function connect(conn::Connection)
  "Connects to the Redis server if not already connected"
  conn._sock.open && return
end
