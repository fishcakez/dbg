defmodule Dbg.Handler do

  def start(devices, opts) do
    case :dbg.start() do
      { :ok, _ } ->
        :dbg.tracer(:process, { &__MODULE__.handle_trace/2, { devices, opts } })
      { :error, _reason } = error ->
        error
    end
  end

  def handle_trace(event, { devices, opts }) do
    formatted = try do
      inspect_event(event)
    rescue
      _exception ->
        ["** (Dbg) unknown event: " |
          inspect(event, records: false, structs: false)]
    end
    case Enum.filter(devices, &( write(&1, formatted, opts) )) do
      [] ->
        exit(:no_devices)
      devices ->
        { devices, opts }
    end
  end

  ## internal

  defp inspect_event({ :trace, pid, tag, arg }) do
    ["** (Dbg) ", inspect(pid), " " | inspect_trace(tag, arg)]
  end

  defp inspect_event({ :trace, pid, tag, arg1, arg2 }) do
    ["** (Dbg) ", inspect(pid), " " | inspect_trace(tag, arg1, arg2)]
  end

  defp inspect_event({ :trace_ts, pid, tag, arg, ts }) do
    ["** (Dbg) ", inspect(pid), " (at ", inspect_ts(ts), ") " |
      inspect_trace(tag, arg)]
  end

  defp inspect_event({ :trace_ts, pid, tag, arg1, arg2, ts }) do
    ["** (Dbg) ", inspect(pid), " (at ", inspect_ts(ts), ") " |
      inspect_trace(tag, arg1, arg2)]
  end

  defp inspect_event({ :seq_trace, label, info}) do
    ["** (Dbg) (Seq: ", inspect(label), ") " | inspect_seq_trace(info)]
  end

  defp inspect_event({ :seq_trace, label, info, ts }) do
    ["** (Dbg) (Seq: ", inspect(label), ") (at ", inspect_ts(ts), ") " |
      inspect_seq_trace(info)]
  end

  defp inspect_event(other) do
    ["** (Dbg) unknown event: ", safe_inspect(other)]
  end

  defp inspect_trace(:receive, msg) do
    ["receives: " | safe_inspect(msg)]
  end

  defp inspect_trace(:call, { mod, fun, args }) do
    ["calls: " | Exception.format_mfa(mod, fun, args)]
  end

  defp inspect_trace(:return_to, { mod, fun, arity }) do
    ["returns to: " | Exception.format_mfa(mod, fun, arity)]
  end

  defp inspect_trace(:exit, reason) do
    ["exits with reason: ", safe_inspect(reason)]
  end

  defp inspect_trace(:link, pid) do
    ["links to: ", inspect(pid)]
  end

  defp inspect_trace(:unlink, pid) do
    ["unlinks from: ", inspect(pid)]
  end

  defp inspect_trace(:getting_link, pid) do
    ["gets linked to: " | inspect(pid)]
  end

  defp inspect_trace(:getting_unlink, pid) do
    ["gets unlinked from: " | inspect(pid)]
  end

  defp inspect_trace(:register, name) do
    ["registers as: " | inspect(name)]
  end

  defp inspect_trace(:unregister, name) do
    ["unregisters as: " | inspect(name)]
  end

  defp inspect_trace(:in, { mod, fun, arity }) do
    ["schedules in with: " | Exception.format_mfa(mod, fun, arity)]
  end

  defp inspect_trace(:in, 0) do
    "schedules in"
  end

  defp inspect_trace(:out, { mod, fun, arity }) do
    ["schedules out with: " | Exception.format_mfa(mod, fun, arity)]
  end

  defp inspect_trace(:out, 0) do
    "schedules out"
  end

  defp inspect_trace(:gc_start, info) do
    ["starts garbage collecting: " | inspect(info)]
  end

  defp inspect_trace(:gc_end, info) do
    ["stops garbage collecting: " | inspect(info)]
  end

  defp inspect_trace(tag, arg) do
    ["unknown trace event with tag:", inspect(tag), " and info: " |
      inspect([arg])]
  end

  defp inspect_trace(:send, msg, to) do
    ["sends (to ", inspect(to), "): " | inspect(msg)]
  end

  defp inspect_trace(:send_to_non_existing_pid, msg, to) do
    ["sends (to non-existing ", inspect(to), "): " | safe_inspect(msg)]
  end

  defp inspect_trace(:return_from, { mod, fun, arity }, res) do
    [Exception.format_mfa(mod, fun, arity), " returns: " | safe_inspect(res)]
  end

  defp inspect_trace(:exception_from, { mod, fun, arity },
      { :error, exception }) when is_exception(exception) do
    [Exception.format_mfa(mod, fun, arity), " raises: (",
      inspect(elem(exception, 0)), ") " |  exception.message]
  end

  defp inspect_trace(:exception_from, { mod, fun, arity }, { :error, error }) do
    exception = Exception.normalize(:error, error)
    [Exception.format_mfa(mod, fun, arity), " raises: (",
      inspect(elem(exception, 0)), ") " |  exception.message]
  end

  defp inspect_trace(:exception_from, { mod, fun, arity }, { :exit, reason }) do
    [Exception.format_mfa(mod, fun, arity), " exits with reason: " |
      safe_inspect(reason)]
  end

  defp inspect_trace(:exception_from, { mod, fun, arity },
      { :throw, reason }) do
    [Exception.format_mfa(mod, fun, arity), " throws: " | safe_inspect(reason)]
  end

  defp inspect_trace(:spawn, pid, { mod, fun, args }) do
    formatted_mfa = Exception.format_mfa(mod, fun, args)
    ["spawns ", inspect(pid), " with: " | formatted_mfa]
  end

  defp inspect_trace(:call, { mod, fun, args },
      <<"=proc:", _rest :: binary >> = dump) do
    ["calls: ", Exception.format_mfa(mod, fun, args) | inspect_dump(dump)]
  end

  defp inspect_trace(tag, arg1, arg2) do
    ["unknown trace event with tag:", inspect(tag), " and info: " |
      safe_inspect([arg1, arg2])]
  end

  defp inspect_seq_trace({ :send, serial, pid, to, msg }) do
    [inspect(serial), ": ", inspect(pid), " sends (to ", inspect(to), "): " |
      safe_inspect(msg)]
  end

  defp inspect_seq_trace({ :receive, serial, from, pid, msg }) do
    [inspect(serial), ": ", inspect(pid), " receives (from ", inspect(from),
      "): " | safe_inspect(msg)]
  end

  defp inspect_seq_trace({ :print, serial, pid, _, info}) do
    [inspect(serial), ": ", inspect(pid), ": " | safe_inspect(info)]
  end

  defp inspect_seq_trace(other) do
    ["unknown seq_trace event: " | safe_inspect(other)]
  end

  defp inspect_ts(now) do
    { _, { hour, min, sec} } = :calendar.now_to_local_time(now)
    :io_lib.format('~2..0b:~2..0b:~2..0b', [hour, min, sec])
  end

  defp write(device, iodata, [:colors | opts]) do
    write(device, [IO.ANSI.blue(), iodata, IO.ANSI.reset()], opts)
  end

  defp write(device, iodata, []) do
    try do
      IO.puts(device, [?\n | iodata])
    else
      :ok ->
        true
    catch
      _, _ ->
        false
    end
  end

  defp safe_inspect(term) do
    try do
      inspect(term)
    catch
      _, _ ->
        inspect(term, records: false, structs: false)
    end
  end

  defp inspect_dump(dump) do
    case parse_dump(dump) do
      [] ->
        []
      stack ->
        [?\n | format_stacktrace(stack)]
    end
  end

  defp parse_dump(dump) do
    Regex.scan(~r/^0x[0-9a-f]{8,16} Return addr 0x[0-9a-f]{8,16} \((?|([[:lower:]][[:alnum:]@_]*)|\'([^']*)\'):(?|([[:lower:]][[[:alnum:]@_]*)|\'([^']*)\')\/(\d{1,3}) \+ \d+\)$/m, dump)
      |> Enum.map(&parse_dump_match/1)
  end

  defp parse_dump_match([_dump_line, mod, fun, arity]) do
    { binary_to_existing_atom(mod), binary_to_existing_atom(fun),
      binary_to_integer(arity), []}
  end

  defp format_stacktrace(stack) do
    formatted = Exception.format_stacktrace(stack)
    # drop last \n
    :binary.part(formatted, 0, byte_size(formatted) - 1)
  end

end
