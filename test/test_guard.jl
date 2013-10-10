if !haskey(ENV, "REDISJL_ENV") || ENV["REDISJL_ENV"] != "test"
  println("WARNING: Running this test will attempt to call flushall on localhost::6379 Redis")
  println("If you wish to proceed, use:")
  println("\tREDISJL_ENV=test julia test/test_<module_name>.jl")
  exit(1)
end
