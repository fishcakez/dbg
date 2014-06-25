defmodule DbgTest do
  use ExUnit.Case

  setup_all do
    Dbg.reset()
    {:ok, _} = Node.start(:dbg_test, :shortnames)
    on_exit(&Node.stop/0)
    case Application.fetch_env(:dbg, :device) do
      {:ok, device} ->
        {:ok, [device: device]}
      :error ->
        :ok
    end
  end

  setup context do
    case Map.fetch(context, :device) do
      {:ok, device} ->
        on_exit(fn() ->
          Application.put_env(:dbg, :device, device)
          Dbg.reset()
        end)
      :error ->
        on_exit(fn() ->
          Application.delete_env(:dbg, :device)
          Dbg.reset()
        end)
    end
    {:ok, context}
  end

  def call(term), do: term

  def do_call(term) do
    __MODULE__.call(term)
    :ok
  end

  defp tail_call(term), do: __MODULE__.call(term)

  defp do_raise(type, opts) do
    raise(type, opts)
    :ok
  end

  test "Dbg.trace/1 :send to alive pid" do
    assert capture_dbg(fn() ->
        Dbg.trace(:send)
        send(self(), :hello)
      end) =~ ~r/#PID<\d+\.\d+\.\d+> sends to #PID<\d+\.\d+\.\d+>:\n    :hello/
  end

  test "Dbg.trace/1 :send to dead pid" do
    assert capture_dbg(fn() ->
        Dbg.trace(:send)
        {pid, ref} = spawn_monitor(fn() -> :ok end)
        receive do {:DOWN, ^ref, _, _, _} -> :ok end
        send(pid, :hello)
      end) =~ ~r/#PID<\d+\.\d+\.\d+> sends to \(non-existing\) #PID<\d+\.\d+\.\d+>:\n    :hello/
  end

  test "Dbg.trace/1 :s(end)" do
    assert capture_dbg(fn() ->
        Dbg.trace(:s)
        send(self(), :hello)
      end) =~ ~r/#PID<\d+\.\d+\.\d+> sends to #PID<\d+\.\d+\.\d+>:\n    :hello/
  end

  test "Dbg.trace/1 :receive" do
    assert capture_dbg(fn() ->
        Dbg.trace(:receive)
        send(self(), :hello)
      end) =~ ~r/#PID<\d+\.\d+\.\d+> receives:\n    :hello/
  end

  test "Dbg.trace/1 :r" do
    assert capture_dbg(fn() ->
        Dbg.trace(:r)
        send(self(), :hello)
      end) =~ ~r/#PID<\d+\.\d+\.\d+> receives:\n    :hello/
  end

  test "Dbg.trace/1 :messages (:send and :receive)" do
    io = capture_dbg(fn() ->
        Dbg.trace(:messages)
        send(self(), :hello)
      end)
    assert io =~ ~r/#PID<\d+\.\d+\.\d+> sends to #PID<\d+\.\d+\.\d+>:\n    :hello/
    assert io =~ ~r/#PID<\d+\.\d+\.\d+> receives:\n    :hello/
  end

  test "Dbg.trace/1 :m (:send and :receive)" do
    io = capture_dbg(fn() ->
        Dbg.trace(:m)
        send(self(), :hello)
      end)
    assert io =~ ~r/#PID<\d+\.\d+\.\d+> sends to #PID<\d+\.\d+\.\d+>:\n    :hello/
    assert io =~ ~r/#PID<\d+\.\d+\.\d+> receives:\n    :hello/
  end

  test "Dbg.trace/1 :procs spawn" do
    assert capture_dbg(fn() ->
        Dbg.trace(:procs)
        spawn(:erlang, :now, [])
      end)  =~ ~r"#PID<\d+\.\d+\.\d+> spawns #PID<\d+\.\d+\.\d+> with :erlang.now/0 with arguments:\n    \[\]"
  end

  test "Dbg.trace/1 :procs exit" do
    assert capture_dbg(fn() ->
        Dbg.trace(:procs)
        exit(:normal)
      end)  =~ ~r"#PID<\d+\.\d+\.\d+> exits: normal"
  end

  test "Dbg.trace/1 :procs register and unregister" do
    io = capture_dbg(fn() ->
        Dbg.trace(:procs)
        Process.register(self(), Dbg.Test.Register)
        Process.unregister(Dbg.Test.Register)
      end)
    assert io  =~ ~r"#PID<\d+\.\d+\.\d+> registers as Dbg.Test.Register"
    assert io  =~ ~r"#PID<\d+\.\d+\.\d+> unregisters as Dbg.Test.Register"
  end

  test "Dbg.trace/1 :procs link and unlink" do
    io = capture_dbg(fn() ->
        Dbg.trace(:procs)
        Process.link(Process.whereis(Dbg.Supervisor))
        Process.unlink(Process.whereis(Dbg.Supervisor))
      end)
    assert io  =~ ~r"#PID<\d+\.\d+\.\d+> links to #PID<\d+\.\d+\.\d+>"
    assert io  =~ ~r"#PID<\d+\.\d+\.\d+> unlinks from #PID<\d+\.\d+\.\d+>"
  end

  test "Dbg.trace/1 :procs gets link and gets unlink" do
    io = capture_dbg(fn() ->
        Dbg.trace(:procs)
        parent = self()
        {_pid, ref} = spawn_monitor(fn() ->
            Process.link(parent)
            Process.unlink(parent)
          end)
        receive do
          {:DOWN, ^ref, _, _, :normal} ->
            :ok
          {:DOWN, ^ref, _, _, reason} ->
            exit(reason)
        end
      end)
    assert io  =~ ~r"#PID<\d+\.\d+\.\d+> gets link to #PID<\d+\.\d+\.\d+>"
    assert io  =~ ~r"#PID<\d+\.\d+\.\d+> gets unlink from #PID<\d+\.\d+\.\d+>"
  end

  test "Dbg.trace/1 :p (:procs) spawn" do
    assert capture_dbg(fn() ->
        Dbg.trace(:p)
        spawn(:erlang, :now, [])
      end)  =~ ~r"#PID<\d+\.\d+\.\d+> spawns #PID<\d+\.\d+\.\d+> with :erlang.now/0 with arguments:\n    \[\]"
  end

  test "Dbg.trace/1 :running in and out" do
    io = capture_dbg(fn() ->
        Dbg.trace(:running)
        :timer.sleep(10)
     end)
    assert io  =~ ~r"#PID<\d+\.\d+\.\d+> schedules in with :timer.sleep/1"
    assert io  =~ ~r"#PID<\d+\.\d+\.\d+> schedules out with :timer.sleep/1"
  end

  test "Dbg.trace/1 :garbage_collection" do
    io = capture_dbg(fn() ->
        Dbg.trace(:garbage_collection)
        :erlang.garbage_collect()
     end)
    assert io  =~ ~r"#PID<\d+\.\d+\.\d+> starts garbage collecting:\n    \["
    assert io  =~ ~r"#PID<\d+\.\d+\.\d+> stops garbage collecting:\n    \["
  end

  test "Dbg.trace/1 :timestamp" do
    assert capture_dbg(fn() ->
        Dbg.trace([:timestamp, :send])
        send(self(), :hello)
      end) =~ ~r/#PID<\d+\.\d+\.\d+> \(at \d\d:\d\d:\d\d\) sends to #PID<\d+\.\d+\.\d+>:\n    :hello/
  end

  test "Dbg.trace/1 :set_on_spawn" do
    assert capture_dbg(fn() ->
        Dbg.trace([:set_on_spawn, :send])
        {_, ref} = spawn_monitor(Kernel, :send, [self(), :hello])
        receive do
          {:DOWN, ^ref, _, _, :normal} ->
            :ok
        end
      end) =~ ~r/#PID<\d+\.\d+\.\d+> sends to #PID<\d+\.\d+\.\d+>:\n    :hello/
  end

  test "Dbg.trace/1 :sos (:set_on_spawn)" do
    assert capture_dbg(fn() ->
        Dbg.trace([:sos, :send])
        {_, ref} = spawn_monitor(Kernel, :send, [self(), :hello])
        receive do
          {:DOWN, ^ref, _, _, :normal} ->
            :ok
        end
      end) =~ ~r/#PID<\d+\.\d+\.\d+> sends to #PID<\d+\.\d+\.\d+>:\n    :hello/
  end

  test "Dbg.trace/1 :set_on_first_spawn" do
    io = capture_dbg(fn() ->
        Dbg.trace([:set_on_first_spawn, :send])
        {_, ref} = spawn_monitor(Kernel, :send, [self(), :hello])
        receive do
          {:DOWN, ^ref, _, _, :normal} ->
            :ok
        end
        {_, ref} = spawn_monitor(Kernel, :send, [self(), :bad])
        receive do
          {:DOWN, ^ref, _, _, :normal} ->
            :ok
        end
      end)
     assert io =~ ~r/#PID<\d+\.\d+\.\d+> sends to #PID<\d+\.\d+\.\d+>:\n    :hello/
     refute io =~ ~r/#PID<\d+\.\d+\.\d+> sends to #PID<\d+\.\d+\.\d+>:\n    :bad/
  end

  test "Dbg.trace/1 :sofs (:set_on_first_spawn)" do
    io = capture_dbg(fn() ->
        Dbg.trace([:sofs, :send])
        {_, ref} = spawn_monitor(Kernel, :send, [self(), :hello])
        receive do
          {:DOWN, ^ref, _, _, :normal} ->
            :ok
        end
        {_, ref} = spawn_monitor(Kernel, :send, [self(), :bad])
        receive do
          {:DOWN, ^ref, _, _, :normal} ->
            :ok
        end
      end)
     assert io =~ ~r/#PID<\d+\.\d+\.\d+> sends to #PID<\d+\.\d+\.\d+>:\n    :hello/
     refute io =~ ~r/#PID<\d+\.\d+\.\d+> sends to #PID<\d+\.\d+\.\d+>:\n    :bad/
  end

  test "Dbg.trace/1 :set_on_link" do
    assert capture_dbg(fn() ->
        Dbg.trace([:set_on_link, :send])
        {_, ref} = Process.spawn(Kernel, :send, [self(), :hello], [:link, :monitor])
        receive do
          {:DOWN, ^ref, _, _, :normal} ->
            :ok
        end
      end) =~ ~r/#PID<\d+\.\d+\.\d+> sends to #PID<\d+\.\d+\.\d+>:\n    :hello/
  end

  test "Dbg.trace/1 :sol (:set_on_link)" do
    assert capture_dbg(fn() ->
        Dbg.trace([:sol, :send])
        {_, ref} = Process.spawn(Kernel, :send, [self(), :hello], [:link, :monitor])
        receive do
          {:DOWN, ^ref, _, _, :normal} ->
            :ok
        end
      end) =~ ~r/#PID<\d+\.\d+\.\d+> sends to #PID<\d+\.\d+\.\d+>:\n    :hello/
  end

  test "Dbg.trace/1 :set_on_first_link" do
    io = capture_dbg(fn() ->
        Dbg.trace([:set_on_first_link, :send])
        {_, ref} = Process.spawn(Kernel, :send, [self(), :hello], [:link, :monitor])
        receive do
          {:DOWN, ^ref, _, _, :normal} ->
            :ok
        end
        {_, ref} = Process.spawn(Kernel, :send, [self(), :bad], [:link, :monitor])
        receive do
          {:DOWN, ^ref, _, _, :normal} ->
            :ok
        end
      end)
     assert io =~ ~r/#PID<\d+\.\d+\.\d+> sends to #PID<\d+\.\d+\.\d+>:\n    :hello/
     refute io =~ ~r/#PID<\d+\.\d+\.\d+> sends to #PID<\d+\.\d+\.\d+>:\n    :bad/
  end

  test "Dbg.trace/1 :sofl (:set_on_first_link)" do
    io = capture_dbg(fn() ->
        Dbg.trace([:sofl, :send])
        {_, ref} = Process.spawn(Kernel, :send, [self(), :hello], [:link, :monitor])
        receive do
          {:DOWN, ^ref, _, _, :normal} ->
            :ok
        end
        {_, ref} = Process.spawn(Kernel, :send, [self(), :bad], [:link, :monitor])
        receive do
          {:DOWN, ^ref, _, _, :normal} ->
            :ok
        end
      end)
     assert io =~ ~r/#PID<\d+\.\d+\.\d+> sends to #PID<\d+\.\d+\.\d+>:\n    :hello/
     refute io =~ ~r/#PID<\d+\.\d+\.\d+> sends to #PID<\d+\.\d+\.\d+>:\n    :bad/
  end

  test "Dbg.clear/0" do
    refute capture_dbg(fn() ->
        Dbg.trace(:send)
        Dbg.clear()
        send(self(), :hello)
      end) =~ ~r/#PID<\d+\.\d+\.\d+> sends to #PID<\d+\.\d+\.\d+>:\n    :hello/
  end

  test "Dbg.clear/1" do
    refute capture_dbg(fn() ->
        Dbg.trace(:send)
        Dbg.clear(self())
        send(self(), :hello)
      end) =~ ~r/#PID<\d+\.\d+\.\d+> sends to #PID<\d+\.\d+\.\d+>:\n    :hello/
  end

  test "Dbg.call/1 with module" do
    assert capture_dbg(fn() ->
        Dbg.trace([:call])
        Dbg.call(DbgTest)
        __MODULE__.call(:hello)
      end) =~ ~r"#PID<\d+\.\d+\.\d+> calls DbgTest.call/1 with arguments:\n    \[:hello\]"
  end

  test "Dbg.call/1 with module and function" do
    assert capture_dbg(fn() ->
        Dbg.trace([:call])
        Dbg.call({DbgTest, :call})
        __MODULE__.call(:hello)
      end) =~ ~r"#PID<\d+\.\d+\.\d+> calls DbgTest.call/1 with arguments:\n    \[:hello\]"
  end

  test "Dbg.call/1 with module and any function" do
    assert capture_dbg(fn() ->
        Dbg.trace([:call])
        Dbg.call({DbgTest, :_})
        __MODULE__.call(:hello)
      end) =~ ~r"#PID<\d+\.\d+\.\d+> calls DbgTest.call/1 with arguments:\n    \[:hello\]"
  end

  test "Dbg.call/1 with module, function and arity" do
    assert capture_dbg(fn() ->
        Dbg.trace([:call])
        Dbg.call({DbgTest, :call, 1})
        __MODULE__.call(:hello)
      end) =~ ~r"#PID<\d+\.\d+\.\d+> calls DbgTest.call/1 with arguments:\n    \[:hello\]"
  end

  test "Dbg.call/1 with module, function and any arity" do
    assert capture_dbg(fn() ->
        Dbg.trace([:call])
        Dbg.call({DbgTest, :call, :_})
        __MODULE__.call(:hello)
      end) =~ ~r"#PID<\d+\.\d+\.\d+> calls DbgTest.call/1 with arguments:\n    \[:hello\]"
  end

  test "Dbg.call/1 with external fun" do
    assert capture_dbg(fn() ->
        Dbg.trace([:call])
        Dbg.call(&DbgTest.call/1)
        __MODULE__.call(:hello)
      end) =~ ~r"#PID<\d+\.\d+\.\d+> calls DbgTest.call/1 with arguments:\n    \[:hello\]"
  end

  test "Dbg.call/1 with local fun raises" do
    assert capture_dbg(fn() ->
        Dbg.trace([:call])
        fun = fn() -> :ok end
        assert_raise ArgumentError, inspect(fun) <> " is not an external fun",
          fn() -> Dbg.call(fun) end
        fun.()
      end) == ""
  end

  test "Dbg.call/2 with shell fun" do
    assert capture_dbg(fn() ->
        Dbg.trace([:call])
        {shell_fun, _} = Code.eval_quoted(quote do fn(_) -> [] end end)
        Dbg.call(&DbgTest.call/1, shell_fun)
        __MODULE__.call(:hello)
      end) =~ ~r"#PID<\d+\.\d+\.\d+> calls DbgTest.call/1 with arguments:\n    \[:hello\]"
  end

  test "Dbg.call/2 with empty list" do
    assert capture_dbg(fn() ->
        Dbg.trace([:call])
        Dbg.call(&DbgTest.call/1, [])
        __MODULE__.call(:hello)
      end) =~ ~r"#PID<\d+\.\d+\.\d+> calls DbgTest.call/1 with arguments:\n    \[:hello\]"
  end

  test "Dbg.call/2 with :return" do
    io = capture_dbg(fn() ->
        Dbg.trace([:call])
        Dbg.call(&DbgTest.call/1, :return)
        __MODULE__.call(:hello)
      end)
    assert io =~ ~r"#PID<\d+\.\d+\.\d+> calls DbgTest.call/1 with arguments:\n    \[:hello\]"
    assert io =~ ~r"#PID<\d+\.\d+\.\d+> DbgTest.call/1 returns:\n    :hello"
  end

  test "Dbg.call/2 with :exception and no raise" do
    io = capture_dbg(fn() ->
        Dbg.trace([:call])
        Dbg.call(&DbgTest.call/1, :exception)
        do_call(:hello)
      end)
    assert io =~ ~r"#PID<\d+\.\d+\.\d+> calls DbgTest.call/1 with arguments:\n    \[:hello\]"
    assert io =~ ~r"#PID<\d+\.\d+\.\d+> DbgTest.call/1 returns:\n    :hello"
  end

  test "Dbg.call/2 with :exception and throw" do
    io = capture_dbg(fn() ->
        Dbg.trace([:call])
        Dbg.call(&:erlang.throw/1, :exception)
        try do
          :erlang.throw(:hello)
        catch
          :hello ->
            :ok
        end
      end)
    assert io =~ ~r"#PID<\d+\.\d+\.\d+> calls :erlang.throw/1 with arguments:\n    \[:hello\]"
    assert io =~ ~r"#PID<\d+\.\d+\.\d+> :erlang.throw/1 raises:\n    \*\* \(throw\) :hello"
  end

  test "Dbg.call/2 with :exception and exit" do
    io = capture_dbg(fn() ->
        Dbg.trace([:call])
        Dbg.call(&:erlang.exit/1, :exception)
        try do
          :erlang.exit(:hello)
        catch
          :exit, :hello ->
            :ok
        end
      end)
    assert io =~ ~r"#PID<\d+\.\d+\.\d+> calls :erlang.exit/1 with arguments:\n    \[:hello\]"
    assert io =~ ~r"#PID<\d+\.\d+\.\d+> :erlang.exit/1 raises:\n    \*\* \(exit\) :hello"
  end

  test "Dbg.call/2 with :exception and normal exit" do
    io = capture_dbg(fn() ->
        Dbg.trace([:call])
        Dbg.call(&:erlang.exit/1, :exception)
        try do
          :erlang.exit(:normal)
        catch
          :exit, :normal ->
            :ok
        end
      end)
    assert io =~ ~r"#PID<\d+\.\d+\.\d+> calls :erlang.exit/1 with arguments:\n    \[:normal\]"
    assert io =~ ~r"#PID<\d+\.\d+\.\d+> :erlang.exit/1 raises:\n    \*\* \(exit\) normal"
  end

  test "Dbg.call/2 with :exception and error" do
    io = capture_dbg(fn() ->
        Dbg.trace([:call])
        Dbg.call(&:erlang.error/1, :exception)
        try do
          :erlang.error(:hello)
        catch
          :error, :hello ->
            :ok
        end
      end)
    assert io =~ ~r"#PID<\d+\.\d+\.\d+> calls :erlang.error/1 with arguments:\n    \[:hello\]"
    assert io =~ ~r"#PID<\d+\.\d+\.\d+> :erlang.error/1 raises:\n    \*\* \(ErlangError\) erlang error: :hello"
  end

  test "Dbg.call/2 with :exception and exception" do
    io = capture_dbg(fn() ->
        Dbg.trace([:call])
        Dbg.call(&:erlang.error/1, :exception)
        try do
          raise ArgumentError, [message: "hello"]
        rescue
          ArgumentError ->
            :ok
        end
      end)
    assert io =~ ~r"#PID<\d+\.\d+\.\d+> calls :erlang.error/1 with arguments:\n"
    assert io =~ ~r"#PID<\d+\.\d+\.\d+> :erlang.error/1 raises:\n    \*\* \(ArgumentError\) hello"
  end

  test "Dbg.call/2 with :x (:exception) and exception" do
    io = capture_dbg(fn() ->
        Dbg.trace([:call])
        Dbg.call(&:erlang.error/1, :x)
        try do
          raise ArgumentError, [message: "hello"]
        rescue
          ArgumentError ->
            :ok
        end
      end)
    assert io =~ ~r"#PID<\d+\.\d+\.\d+> calls :erlang.error/1 with arguments:\n"
    assert io =~ ~r"#PID<\d+\.\d+\.\d+> :erlang.error/1 raises:\n    \*\* \(ArgumentError\) hello"
  end

  test "Dbg.call/2 with :cx (:caller and :exception) and exception" do
    io = capture_dbg(fn() ->
        Dbg.trace([:call])
        Dbg.call(&:erlang.error/1, :cx)
        try do
          do_raise(ArgumentError, [message: "hello"])
        rescue
          ArgumentError ->
            :ok
        end
      end)
    assert io =~ ~r"#PID<\d+\.\d+\.\d+> calls :erlang.error/1 with arguments:\n    \[.*\]\n    DbgTest.do_raise/2"
    assert io =~ ~r"#PID<\d+\.\d+\.\d+> :erlang.error/1 raises:\n    \*\* \(ArgumentError\) hello"
  end

  test "Dbg.call/2 with :caller and no caller app" do
    assert capture_dbg(fn() ->
        Dbg.trace([:call])
        Dbg.call(&DbgTest.call/1, :caller)
        do_call(:hello)
      end) =~ ~r"#PID<\d+\.\d+\.\d+> calls DbgTest.call/1 with arguments:\n    \[:hello\]\n    DbgTest.do_call/1"
  end

  test "Dbg.call/2 with :c(aller) and no caller app" do
    assert capture_dbg(fn() ->
        Dbg.trace([:call])
        Dbg.call(&DbgTest.call/1, :c)
        do_call(:hello)
      end) =~ ~r"#PID<\d+\.\d+\.\d+> calls DbgTest.call/1 with arguments:\n    \[:hello\]\n    DbgTest.do_call/1"
  end

  test "Dbg.call/2 with :caller and caller app" do
    assert capture_dbg(fn() ->
        Dbg.trace([:call])
        Dbg.call(&:dbg.p/2, :caller)
        Dbg.trace([:call])
      end) =~ ~r"#PID<\d+\.\d+\.\d+> calls :dbg.p/2 with arguments:\n    \[#PID<\d+\.\d+\.\d+>, \[:call\]\]\n    \(dbg\) Dbg.trace/2"
  end

  test "Dbg.call/2 with :caller and tail call" do
    io = capture_dbg(fn() ->
        Dbg.trace([:call])
        Dbg.call(&DbgTest.call/1, :caller)
        tail_call(:hello)
      end)
    assert io =~ ~r"#PID<\d+\.\d+\.\d+> calls DbgTest.call/1 with arguments:\n    \[:hello\]"
    refute io =~ ~r"DbgTest.tail_call/1"
  end

  test "Dbg.call/2 with :stack" do
    io = capture_dbg(fn() ->
        Dbg.trace([:sofs, :call])
        Dbg.call(&DbgTest.call/1, :stack)
        Task.await(Task.async(__MODULE__, :do_call, [:hello]))
      end)
     assert io =~ ~r"#PID<\d+\.\d+\.\d+> calls DbgTest.call/1 with arguments:\n    \[:hello\]\n             DbgTest.do_call/1\n"
     assert io =~ ~r"\n    \(stdlib\) :proc_lib\.init_p_do_apply/3\n$"m
  end

  test "Dbg.call/2 with {:silent, true}" do
    assert capture_dbg(fn() ->
        Dbg.trace([:call])
        Dbg.call(&DbgTest.call/1, [silent: true])
        do_call(:bad)
      end) === ""
  end

  test "Dbg.call/2 with {:silent, false}" do
    assert capture_dbg(fn() ->
        Dbg.trace([:call, :silent])
        Dbg.call(&DbgTest.call/1, [silent: false])
        do_call(:hello)
      end) =~ ~r"#PID<\d+\.\d+\.\d+> calls DbgTest.call/1 with arguments:\n    \[:hello\]\n"
  end

  test "Dbg.call/2 with :trace" do
    assert capture_dbg(fn() ->
        Dbg.trace([:call])
        Dbg.call(&DbgTest.call/1, [{:trace, [:send]}])
        do_call(:hello)
        send(self(), :hello)
      end) =~ ~r"#PID<\d+\.\d+\.\d+> sends to #PID<\d+\.\d+\.\d+>:\n    :hello"
  end

  test "Dbg.call/2 with :trace and pid" do
    assert capture_dbg(fn() ->
        Dbg.trace([:call])
        Dbg.call(&DbgTest.call/1, [{:trace, self(), [:send]}])
        do_call(:hello)
        send(self(), :hello)
      end) =~ ~r"#PID<\d+\.\d+\.\d+> sends to #PID<\d+\.\d+\.\d+>:\n    :hello"
  end

  test "Dbg.call/2 with :trace and {:self}" do
    assert capture_dbg(fn() ->
        Dbg.trace([:call])
        Dbg.call(&DbgTest.call/1, [{:trace, {:self}, [:send]}])
        do_call(:hello)
        send(self(), :hello)
      end) =~ ~r"#PID<\d+\.\d+\.\d+> sends to #PID<\d+\.\d+\.\d+>:\n    :hello"
  end

  test "Dbg.call/2 with :clear" do
    refute capture_dbg(fn() ->
        Dbg.trace([:call, :send])
        Dbg.call(&DbgTest.call/1, [:clear])
        do_call(:hello)
        send(self(), :bad)
      end) =~ ~r"#PID<\d+\.\d+\.\d+> sends to #PID<\d+\.\d+\.\d+>:\n    :bad"
  end

  test "Dbg.call/2 with :clear and pid" do
    refute capture_dbg(fn() ->
        Dbg.trace([:call, :send])
        Dbg.call(&DbgTest.call/1, [{:clear, self()}])
        do_call(:hello)
        send(self(), :bad)
      end) =~ ~r"#PID<\d+\.\d+\.\d+> sends to #PID<\d+\.\d+\.\d+>:\n    :bad"
  end

  test "Dbg.call/2 with :clear and {:self}" do
    refute capture_dbg(fn() ->
        Dbg.trace([:call, :send])
        Dbg.call(&DbgTest.call/1, [{:clear, {:self}}])
        do_call(:hello)
        send(self(), :bad)
      end) =~ ~r"#PID<\d+\.\d+\.\d+> sends to #PID<\d+\.\d+\.\d+>:\n    :bad"
  end

  test "Dbg.call/2 with basic ms" do
    assert capture_dbg(fn() ->
        Dbg.trace([:call])
        Dbg.call(&DbgTest.call/1, [{:_, [], []}])
        do_call(:hello)
      end) =~ ~r"#PID<\d+\.\d+\.\d+> calls DbgTest.call/1 with arguments:\n    \[:hello\]"
  end

  test "Dbg.call/2 with complex ms" do
    io = capture_dbg(fn() ->
        Dbg.trace([:call])
        Dbg.call(&DbgTest.call/1, [{[:hello], [], [:return]}, {:_, [], []}])
        do_call(:hello)
        do_call(:bad)
      end)
     assert io =~ ~r"#PID<\d+\.\d+\.\d+> calls DbgTest.call/1 with arguments:\n    \[:hello\]"
     assert io =~ ~r"#PID<\d+\.\d+\.\d+> calls DbgTest.call/1 with arguments:\n    \[:bad\]"
     assert io =~ ~r"#PID<\d+\.\d+\.\d+> DbgTest.call/1 returns:\n    :hello"
     refute io =~ ~r"#PID<\d+\.\d+\.\d+> DbgTest.call/1 returns:\n    :bad"
  end

  test "Dbg.call/2 with saved" do
    io = capture_dbg(fn() ->
        Dbg.trace([:sofs, :call])
        %{saved: saved} = Dbg.call(&DbgTest.call/1, [:stack])
        Dbg.cancel(&DbgTest.call/1)
        Dbg.call(&DbgTest.call/1, saved)
        Task.await(Task.async(__MODULE__, :do_call, [:hello]))
      end)
     assert io =~ ~r"#PID<\d+\.\d+\.\d+> calls DbgTest.call/1 with arguments:\n    \[:hello\]\n             DbgTest.do_call/1\n"
     assert io =~ ~r"\n    \(stdlib\) :proc_lib\.init_p_do_apply/3\n$"m
  end

  test "Dbg.call/2 with Dbg.trace([:call, :arity])" do
    io = capture_dbg(fn() ->
        Dbg.trace([:call, :arity])
        Dbg.call(&DbgTest.call/1, [])
        do_call(:hello)
      end)
     assert io =~ ~r"#PID<\d+\.\d+\.\d+> calls DbgTest.call/1\n"
     refute io =~ ~r":hello"
  end

  test "Dbg.call/2 return values" do
    result = Dbg.call(&DbgTest.call/1, [:caller])
    assert Map.get(result, :errors) == %{}
    assert Map.get(result[:counts], node()) == 1
    assert Map.get(result, :saved) == :c

    result = Dbg.call(DbgTest, [:exception])
    assert Map.get(result, :errors) == %{}
    assert Map.get(result[:counts], node()) > 1
    assert Map.get(result, :saved) == :x

    result = Dbg.call({DbgTest, "not_an_atom", 1}, [:exception])
    assert Map.get(result, :counts) == %{}
    assert Map.has_key?(result[:errors], node())
  end

  test "Dbg.call/2 with bad option" do
    assert_raise ArgumentError, "invalid option: :bad_option",
      fn() -> Dbg.call(&DbgTest.call/1, [:bad_option]) end
  end

  test "Dbg.call/2 with bad option in ms" do
    assert_raise ArgumentError, "invalid option: :bad_option",
      fn() -> Dbg.call(&DbgTest.call/1, [{:_, [], [:bad_option]}]) end
  end



  test "Dbg.local_call/1 with module" do
    assert capture_dbg(fn() ->
        Dbg.trace([:call])
        Dbg.local_call(DbgTest)
        call(:hello)
      end) =~ ~r"#PID<\d+\.\d+\.\d+> calls DbgTest.call/1 with arguments:\n    \[:hello\]"
  end

  test "Dbg.local_call/1 with Dbg.trace([:call, :return_to])" do
    assert capture_dbg(fn() ->
        Dbg.trace([:call, :return_to])
        Dbg.local_call(&DbgTest.call/1)
        do_call(:hello)
      end) =~ ~r"#PID<\d+\.\d+\.\d+> returns to DbgTest.do_call/1"
  end

  test "Dbg.local_call/1 with Dbg.trace([:call, :return_to]) and tail call" do
    assert capture_dbg(fn() ->
        Dbg.trace([:call, :return_to])
        Dbg.local_call(&DbgTest.call/1)
        call(:hello)
      end) =~ ~r"#PID<\d+\.\d+\.\d+> returns to calling function"
  end

  test "Dbg.local_call/2 return values" do
    result = Dbg.local_call(&DbgTest.call/1, [:caller])
    assert Map.get(result, :errors) == %{}
    assert Map.get(result[:counts], node()) == 1
    assert Map.get(result, :saved) == :c

    result = Dbg.local_call(DbgTest, [:exception])
    assert Map.get(result, :errors) == %{}
    assert Map.get(result[:counts], node()) > 1
    assert Map.get(result, :saved) == :x
  end

  test "Dbg.local_call/2 with bad option" do
    assert_raise ArgumentError, "invalid option: :bad_option",
      fn() -> Dbg.local_call(&DbgTest.call/1, [:bad_option]) end
  end

  test "Dbg.local_call/2 with bad option in ms" do
    assert_raise ArgumentError, "invalid option: :bad_option",
      fn() -> Dbg.local_call(&DbgTest.call/1, [{:_, [], [:bad_option]}]) end
  end

  test "Dbg.trace/2 with :all" do
    io = capture_dbg(fn() ->
        Dbg.trace(:all, [:call])
        Dbg.call(&DbgTest.call/1)
        do_call(:existing)
        {_, ref} = spawn_monitor(fn() -> do_call(:new) end)
        receive do
          {:DOWN, ^ref, _, _, _} ->
            :ok
        end
      end)
    assert io =~ ~r"#PID<\d+\.\d+\.\d+> calls DbgTest.call/1 with arguments:\n    \[:existing\]"
    assert io =~ ~r"#PID<\d+\.\d+\.\d+> calls DbgTest.call/1 with arguments:\n    \[:new\]"
  end

  test "Dbg.trace/2 with :existing" do
    io = capture_dbg(fn() ->
        Dbg.trace(:existing, [:call])
        Dbg.call(&DbgTest.call/1)
        do_call(:existing)
        {_, ref} = spawn_monitor(fn() -> do_call(:new) end)
        receive do
          {:DOWN, ^ref, _, _, _} ->
            :ok
        end
      end)
    assert io =~ ~r"#PID<\d+\.\d+\.\d+> calls DbgTest.call/1 with arguments:\n    \[:existing\]"
    refute io =~ ~r"#PID<\d+\.\d+\.\d+> calls DbgTest.call/1 with arguments:\n    \[:new\]"
  end

  test "Dbg.trace/2 with :new" do
    io = capture_dbg(fn() ->
        Dbg.trace(:new, [:call])
        Dbg.call(&DbgTest.call/1)
        do_call(:existing)
        {_, ref} = spawn_monitor(fn() -> do_call(:new) end)
        receive do
          {:DOWN, ^ref, _, _, _} ->
            :ok
        end
      end)
    refute io =~ ~r"#PID<\d+\.\d+\.\d+> calls DbgTest.call/1 with arguments:\n    \[:existing\]"
    assert io =~ ~r"#PID<\d+\.\d+\.\d+> calls DbgTest.call/1 with arguments:\n    \[:new\]"
  end

  test "Dbg.trace/2 with pid" do
    assert capture_dbg(fn() ->
        Dbg.trace(self(), [:call])
        Dbg.call(&DbgTest.call/1)
        do_call(:hello)
      end) =~ ~r"#PID<\d+\.\d+\.\d+> calls DbgTest.call/1 with arguments:\n    \[:hello\]"
  end

  test "Dbg.trace/2 with local name" do
    assert capture_dbg(fn() ->
        Process.register(self(), __MODULE__)
        Dbg.trace(__MODULE__, [:call])
        Dbg.call(&DbgTest.call/1)
        do_call(:hello)
        Process.unregister(__MODULE__)
      end) =~ ~r"#PID<\d+\.\d+\.\d+> calls DbgTest.call/1 with arguments:\n    \[:hello\]"
  end

  test "Dbg.trace/2 with bad local name" do
    assert catch_exit(Dbg.trace(__MODULE__, [:call])) ==
        {:noproc, {Dbg, :trace, [__MODULE__, [:call]]}}
  end

  test "Dbg.trace/2 with foreign local name" do
    assert capture_dbg(fn() ->
        Process.register(self(), __MODULE__)
        Dbg.trace({__MODULE__, node()}, [:call])
        Dbg.call(&DbgTest.call/1)
        do_call(:hello)
        Process.unregister(__MODULE__)
      end) =~ ~r"#PID<\d+\.\d+\.\d+> calls DbgTest.call/1 with arguments:\n    \[:hello\]"
  end

  test "Dbg.trace/2 with bad foreign local name" do
    assert catch_exit(Dbg.trace({__MODULE__, node()}, [:call])) ==
        {:noproc, {Dbg, :trace, [{__MODULE__,  node}, [:call]]}}
  end

  test "Dbg.trace/2 with global name" do
    assert capture_dbg(fn() ->
        :global.register_name(__MODULE__, self())
        Dbg.trace({:global, __MODULE__}, [:call])
        Dbg.call(&DbgTest.call/1)
        do_call(:hello)
        :global.unregister_name(__MODULE__)
      end) =~ ~r"#PID<\d+\.\d+\.\d+> calls DbgTest.call/1 with arguments:\n    \[:hello\]"
  end

  test "Dbg.trace/2 with bad global name" do
    assert catch_exit(Dbg.trace({:global, __MODULE__}, [:call])) ==
        {:noproc, {Dbg, :trace, [{:global, __MODULE__}, [:call]]}}
  end

  test "Dbg.trace/2 with via name" do
    assert capture_dbg(fn() ->
        :global.register_name(__MODULE__, self())
        Dbg.trace({:via, :global, __MODULE__}, [:call])
        Dbg.call(&DbgTest.call/1)
        do_call(:hello)
        :global.unregister_name(__MODULE__)
      end) =~ ~r"#PID<\d+\.\d+\.\d+> calls DbgTest.call/1 with arguments:\n    \[:hello\]"
  end

  test "Dbg.trace/2 with bad via name" do
    assert catch_exit(Dbg.trace({:via, :global, __MODULE__}, [:call])) ==
        {:noproc, {Dbg, :trace, [{:via, :global, __MODULE__}, [:call]]}}
  end

  test "Dbg.trace/2 return values" do
    result = Dbg.trace(self(), :call)
    assert Map.get(result, :errors) == %{}
    assert Map.get(result[:counts], node()) == 1

    result = Dbg.trace(:all, :call)
    assert Map.get(result, :errors) == %{}
    assert Map.get(result[:counts], node()) > 1

    result = Dbg.trace(:existing, :call)
    assert Map.get(result, :errors) == %{}
    assert Map.get(result[:counts], node()) > 1

    result = Dbg.trace(:new, :call)
    assert Map.get(result, :errors) == %{}
    assert Map.get(result[:counts], node()) == 0
  end

  test "Dbg.trace/2 with bad flag" do
    assert_raise ArgumentError,"invalid flag: :bad_flag",
      fn() -> Dbg.trace(self(), [:bad_flag]) end
  end

  test "Dbg.trace/2 with pid on untraced node" do
    {:ok, slave} = :slave.start_link(:net_adm.localhost(), :"dbg_test_slave")
    # :rex is the :rpc process
    assert catch_exit(Dbg.trace({:rex, slave}, [:call])) ==
        {{:no_tracer_on_node, slave}, {Dbg, :trace, [{:rex, slave}, [:call]]}}
  end

  test "Dbg.node/1" do
    {:ok, slave} = :slave.start_link(:net_adm.localhost(), :"dbg_test_slave")
    assert capture_dbg(fn() ->
        assert Dbg.node(slave) == :ok
        assert Enum.member?(Dbg.nodes(), node())
        assert Enum.member?(Dbg.nodes(), slave)
        Dbg.trace({:rex, slave}, :send)
        :hello = :rpc.block_call(slave, :erlang, :send, [self(), :hello])
        Dbg.flush()
        Dbg.clear_node(slave)
        refute Enum.member?(Dbg.nodes(), slave)
        :ok = :slave.stop(slave)
    end) =~ ~r/#PID<\d+\.\d+\.\d+> \(on dbg_test_slave@.*\) sends to #PID<\d+\.\d+\.\d+>:\n    :hello/
  end

  test "Dbg.inspect_file/2" do
    file = Path.join(System.tmp_dir!(), "DbgTest.log")
    Application.put_env(:dbg, :device, {:file, file})
    Dbg.reset()
    Dbg.trace(:send)
    send(self(), :hello)
    Application.delete_env(:dbg, :device)
    Dbg.reset()
    io = ExUnit.CaptureIO.capture_io(fn() ->
        Dbg.inspect_file(file)
      end)
     assert io =~ ~r/#PID<\d+\.\d+\.\d+> sends to #PID<\d+\.\d+\.\d+>:\n    :hello/
     assert io =~ ~r/end of trace/
  end


  test "Dbg.cancel/1 with module" do
    assert capture_dbg(fn() ->
        Dbg.trace([:call])
        Dbg.call(&DbgTest.call/1)
        Dbg.cancel(DbgTest)
        __MODULE__.call(:hello)
      end) == ""
  end

  test "Dbg.cancel/1 with module and function" do
    assert capture_dbg(fn() ->
        Dbg.trace([:call])
        Dbg.call(&DbgTest.call/1)
        Dbg.cancel({DbgTest, :call})
        __MODULE__.call(:hello)
      end) == ""
  end

  test "Dbg.cancel/1 with module and any function" do
    assert capture_dbg(fn() ->
        Dbg.trace([:call])
        Dbg.call(&DbgTest.call/1)
        Dbg.cancel({DbgTest, :_})
        __MODULE__.call(:hello)
      end) == ""
  end

  test "Dbg.cancel/1 with module, function and arity" do
    assert capture_dbg(fn() ->
        Dbg.trace([:call])
        Dbg.call(&DbgTest.call/1)
        Dbg.cancel({DbgTest, :call, 1})
        __MODULE__.call(:hello)
      end) == ""
  end

  test "Dbg.cancel/1 with module, function and any arity" do
    assert capture_dbg(fn() ->
        Dbg.trace([:call])
        Dbg.call(&DbgTest.call/1)
        Dbg.cancel({DbgTest, :call, :_})
        __MODULE__.call(:hello)
      end) == ""
  end

  test "Dbg.cancel/1 with external fun" do
    assert capture_dbg(fn() ->
        Dbg.trace([:call])
        Dbg.call(&DbgTest.call/1)
        Dbg.cancel(&DbgTest.call/1)
        __MODULE__.call(:hello)
      end) == ""
  end

  test "Dbg.cancel/1 with local fun raises" do
    assert capture_dbg(fn() ->
        Dbg.trace([:call])
        fun = fn() -> :ok end
        assert_raise ArgumentError, inspect(fun) <> " is not an external fun",
          fn() -> Dbg.cancel(fun) end
        fun.()
      end) == ""
  end

  test "Dbg.cancel/1 return values" do
    result = Dbg.cancel(&DbgTest.call/1)
    assert Map.get(result, :errors) == %{}
    assert Map.get(result[:counts], node()) == 1

    result = Dbg.cancel(DbgTest)
    assert Map.get(result, :errors) == %{}
    assert Map.get(result[:counts], node()) > 1
  end

  test "Dbg.pattern/0 defaults" do
    assert Enum.member?(Dbg.patterns(), {:c, [{:_, [], [:caller]}]})
    assert Enum.member?(Dbg.patterns(), {:x, [{:_, [], [:exception]}]})
    assert Enum.member?(Dbg.patterns(), {:cx, [{:_, [], [:exception, :caller]}]})
  end

  test "Dbg.pattern/0 with  :return" do
    result = Dbg.call(&DbgTest.call/1, [:return])
    assert Map.has_key?(result, :saved)
    saved = Map.fetch!(result, :saved)
    assert Map.get(Dbg.patterns(), saved) == [{:_, [], [:return]}]
  end

  test "Dbg.pattern/0 with :stack" do
    result = Dbg.call(&DbgTest.call/1, [:stack])
    assert Map.has_key?(result, :saved)
    saved = Map.fetch!(result, :saved)
    assert Map.get(Dbg.patterns(), saved) == [{:_, [], [:stack]}]
  end

  test "Dbg.pattern/0 with {:silent, true}" do
    result = Dbg.call(&DbgTest.call/1, [silent: true])
    assert Map.has_key?(result, :saved)
    saved = Map.fetch!(result, :saved)
    assert Map.get(Dbg.patterns(), saved) == [{:_, [], [silent: true]}]
  end

  test "Dbg.pattern/0 with {:silent, false}" do
    result = Dbg.call(&DbgTest.call/1, [silent: false])
    assert Map.has_key?(result, :saved)
    saved = Map.fetch!(result, :saved)
    assert Map.get(Dbg.patterns(), saved) == [{:_, [], [silent: false]}]
  end

  test "Dbg.pattern/0 with :trace" do
    result = Dbg.call(&DbgTest.call/1, [{:trace, [:silent]}])
    assert Map.has_key?(result, :saved)
    saved = Map.fetch!(result, :saved)
    assert Map.get(Dbg.patterns(), saved) == [{:_, [], [{:trace, [:silent]}]}]
  end

  test "Dbg.pattern/0 with :trace and pid" do
    result = Dbg.call(&DbgTest.call/1, [{:trace, self(), [:silent]}])
    assert Map.has_key?(result, :saved)
    saved = Map.fetch!(result, :saved)
    assert Map.get(Dbg.patterns(), saved) ==
      [{:_, [], [{:trace, self(), [:silent]}]}]
  end

  test "Dbg.pattern/0 with :trace and {:self}" do
    result = Dbg.call(&DbgTest.call/1, [{:trace, {:self}, [:silent]}])
    assert Map.has_key?(result, :saved)
    saved = Map.fetch!(result, :saved)
    assert Map.get(Dbg.patterns(), saved) ==
      [{:_, [], [{:trace, {:self}, [:silent]}]}]
  end

  test "Dbg.pattern/0 with :clear" do
    result = Dbg.call(&DbgTest.call/1, [:clear])
    assert Map.has_key?(result, :saved)
    saved = Map.fetch!(result, :saved)
    assert Map.get(Dbg.patterns(), saved) == [{:_, [], [:clear]}]
  end

  test "Dbg.pattern/0 with :clear and pid" do
    result = Dbg.call(&DbgTest.call/1, [{:clear, self()}])
    assert Map.has_key?(result, :saved)
    saved = Map.fetch!(result, :saved)
    assert Map.get(Dbg.patterns(), saved) ==
      [{:_, [], [{:clear, self()}]}]
  end

  test "Dbg.pattern/0 with :clear and {:self}" do
    result = Dbg.call(&DbgTest.call/1, [{:clear, {:self}}])
    assert Map.has_key?(result, :saved)
    saved = Map.fetch!(result, :saved)
    assert Map.get(Dbg.patterns(), saved) ==
      [{:_, [], [{:clear, {:self}}]}]
  end

  test "Dbg.pattern/0 with basic ms" do
    result = Dbg.call(&DbgTest.call/1, [{:_, [], []}])
    assert Map.has_key?(result, :saved)
    saved = Map.fetch!(result, :saved)
    assert Map.get(Dbg.patterns(), saved) == [{:_, [], []}]
  end

  test "Dbg.pattern/0 with complex ms" do
    result = Dbg.call(&DbgTest.call/1,
        [{[:hello], [], [:return]}, {:_, [], []}])
    assert Map.has_key?(result, :saved)
    saved = Map.fetch!(result, :saved)
    assert Map.get(Dbg.patterns(), saved) ==
      [{[:hello], [], [:return]}, {:_, [], []}]
  end

  test "Dbg.pattern/0 with incompatible erlang ms" do
    {:ok, result} = :dbg.tp(DbgTest, :call, 1,
        [{:_, [], [:return, {:message,:foo}]}])
    {:saved, saved} = List.keyfind(result, :saved, 0)
    refute Map.has_key?(Dbg.patterns(), saved)
  end

  defp capture_dbg(fun) do
    ExUnit.CaptureIO.capture_io(
      fn() ->
        :ok = prepare_dbg()
        :ok = eval_fun(fun)
        # reset ensures capture_io gets all traces written to it.
        :ok = Dbg.reset()
      end)
  end

  defp prepare_dbg() do
    Application.put_env(:dbg, :device, Process.group_leader())
    Dbg.reset()
  end

  defp eval_fun(fun) do
    {_, ref} = spawn_monitor(fun)
    receive do
      {:DOWN, ^ref, _, _, :normal} ->
        :ok
      {:DOWN, ^ref, _, _, reason} ->
        exit(reason)
    after
      5000 ->
        exit(:timeout)
    end
  end

end
