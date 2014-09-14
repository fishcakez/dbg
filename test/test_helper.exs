if Node.alive?() do
  ExUnit.start([exclude: [distributed: true]])
else
  ExUnit.start()
end
