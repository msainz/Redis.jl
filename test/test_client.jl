client = redis()
@show execute_command(client, "GET", "foo")
