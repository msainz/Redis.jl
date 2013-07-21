using Redis
using Base.Test

conn = Connection()
println(conn)

connect(conn)
println(conn)

