pool = ConnectionPool(max_connections=2, db=1)
@show pool

conn = get_connection(pool)
@show pool
