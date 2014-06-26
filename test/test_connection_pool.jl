using Redis
using Base.Test

pool = ConnectionPool(max_connections=2, db=1)
@test pool.created_connections == 0
@test isempty(pool.available_connections)
@test isempty(pool.in_use_connections)

c1 = get_connection(pool)
@test pool.created_connections == 1
@test isempty(pool.available_connections)
@test pool.in_use_connections == Set({c1})

c2 = get_connection(pool)
@test pool.created_connections == 2
@test isempty(pool.available_connections)
@test pool.in_use_connections == Set({c1,c2})

c3 =
try
  get_connection(pool)
catch e
  @test isa(e, ConnectionError)
  @test e.message == "Too many connections"
end
@test c3 == nothing
@test pool.created_connections == 2
@test isempty(pool.available_connections)
@test length(pool.in_use_connections) == 2

@test release(pool, c1) == nothing
@test pool.available_connections == [c1]
@test pool.in_use_connections == Set({c2})

@test release(pool, c1) == nothing
@test pool.available_connections == [c1]
@test pool.in_use_connections == Set({c2})

@test release(pool, c2) == nothing
@test pool.available_connections == [c1,c2]
@test pool.in_use_connections == Set()

c2 = get_connection(pool)
@test pool.available_connections == [c1]
#@test pool.in_use_connections == Set(c2)
