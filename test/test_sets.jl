using Redis
using Base.Test
include("test_guard.jl")

client = redis()

@test flushall(client) == true
@test keys(client) == {}

