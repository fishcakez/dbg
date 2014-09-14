defmodule Dbg.Handler do
  @moduledoc false

  def spec(device) do
    { &__MODULE__.handle_event/2, device }
  end

  def handle_event(event, device) do
    options = IEx.configuration()
    formatted = try do
      inspect_event(event, options)
    rescue
      _exception ->
        ["unknown event:" | safe_inspect(event, options)]
    end
    write(device, ["** (Dbg) " | formatted], options)
    device
  end

  ## internal

  defp inspect_event({ :trace, pid, tag, arg }, options) do
    [inspect_pid(pid), ?\s | inspect_trace(tag, arg, options)]
  end

  defp inspect_event({ :trace, pid, tag, arg1, arg2 }, options) do
    [inspect_pid(pid), ?\s | inspect_trace(tag, arg1, arg2, options)]
  end

  defp inspect_event({ :trace_ts, pid, tag, arg, ts }, options) do
    [inspect_pid(pid), " (at ", inspect_ts(ts), ") " |
      inspect_trace(tag, arg, options)]
  end

  defp inspect_event({ :trace_ts, pid, tag, arg1, arg2, ts }, options) do
    [inspect_pid(pid), " (at ", inspect_ts(ts), ") " |
      inspect_trace(tag, arg1, arg2, options)]
  end

  defp inspect_event({ :seq_trace, label, info}, options) do
    ["(Seq ", inspect(label), ") " | inspect_seq_trace(info, options)]
  end

  defp inspect_event({ :seq_trace, label, info, ts }, options) do
    ["(Seq ", inspect(label), ") (at ", inspect_ts(ts), ") " |
      inspect_seq_trace(info, options)]
  end

  defp inspect_event(:end_of_trace, _options) do
    "end of trace"
  end

  defp inspect_event(other, options) do
    ["unknown event:" | safe_inspect(other, options)]
  end

  defp inspect_trace(:receive, msg, options) do
    ["receives:" | safe_inspect(msg, options)]
  end

  defp inspect_trace(:call, { mod, fun, arity }, _options)
      when is_integer(arity) do
    ["calls " | Exception.format_mfa(mod, fun, arity)]
  end

  defp inspect_trace(:call, { mod, fun, args }, options) do
    arity = length(args)
    ["calls ", Exception.format_mfa(mod, fun, arity), " with arguments:" |
      safe_inspect(args, options)]
  end

  defp inspect_trace(:return_to, :undefined, _options) do
    "returns to calling function"
  end

  defp inspect_trace(:return_to, { mod, fun, arity }, _options) do
    ["returns to " | Exception.format_mfa(mod, fun, arity)]
  end

  defp inspect_trace(:exit, reason, options) do
    ["exits: " | safe_format_exit(reason, options)]
  end

  defp inspect_trace(:link, pid, _options) do
    ["links to " | inspect_pid(pid)]
  end

  defp inspect_trace(:unlink, pid, _options) do
    ["unlinks from " | inspect_pid(pid)]
  end

  defp inspect_trace(:getting_linked, pid, _options) do
    ["gets link to " | inspect_pid(pid)]
  end

  defp inspect_trace(:getting_unlinked, pid, _options) do
    ["gets unlink from " | inspect_pid(pid)]
  end

  defp inspect_trace(:register, name, _options) do
    ["registers as " | inspect(name)]
  end

  defp inspect_trace(:unregister, name, _options) do
    ["unregisters as " | inspect(name)]
  end

  defp inspect_trace(:in, { mod, fun, arity }, _options) do
    ["schedules in with " | Exception.format_mfa(mod, fun, arity)]
  end

  defp inspect_trace(:in, 0, _options) do
    "schedules in"
  end

  defp inspect_trace(:out, { mod, fun, arity }, _options) do
    ["schedules out with " | Exception.format_mfa(mod, fun, arity)]
  end

  defp inspect_trace(:out, 0, _options) do
    "schedules out"
  end

  defp inspect_trace(:gc_start, info, options) do
    ["starts garbage collecting:" | safe_inspect(info, options)]
  end

  defp inspect_trace(:gc_end, info, options) do
    ["stops garbage collecting:" | safe_inspect(info, options)]
  end

  defp inspect_trace(tag, arg, options) do
    ["unknown trace event ", inspect(tag), " with info:" |
      safe_inspect([arg], options)]
  end

  defp inspect_trace(:send, msg, to, options) do
    ["sends to ", inspect_pid(to), ":" | safe_inspect(msg, options)]
  end

  defp inspect_trace(:send_to_non_existing_process, msg, to, options) do
    ["sends to (non-existing) ", inspect_pid(to), ":" |
      safe_inspect(msg, options)]
  end

  defp inspect_trace(:return_from, { mod, fun, arity }, res, options) do
    [Exception.format_mfa(mod, fun, arity), " returns:" |
      safe_inspect(res, options)]
  end

  defp inspect_trace(:exception_from, { mod, fun, arity }, { kind, payload },
      _options) do
    [Exception.format_mfa(mod, fun, arity), " raises:" |
      indent(Exception.format_banner(kind, payload, []))]
  end

  defp inspect_trace(:spawn, pid, { mod, fun, arity }, _options)
       when is_integer(arity) do
    ["spawns ", inspect_pid(pid), " with " |
      Exception.format_mfa(mod, fun, arity)]
  end

  defp inspect_trace(:spawn, pid, { mod, fun, args }, options) do
    arity = length(args)
    ["spawns ", inspect_pid(pid), " with ",
      Exception.format_mfa(mod, fun, arity), " with arguments:" |
      safe_inspect(args, options)]
  end

  defp inspect_trace(:call, { mod, fun, arity }, info, options)
      when is_integer(arity) do
    ["calls ", Exception.format_mfa(mod, fun, arity) |
      inspect_call_info(info, options)]
  end

  defp inspect_trace(:call, { mod, fun, args }, info, options) do
    arity = length(args)
    ["calls ", Exception.format_mfa(mod, fun, arity), " with arguments:",
      safe_inspect(args, options) | inspect_call_info(info, options)]
  end

  defp inspect_trace(tag, arg1, arg2, options) do
    ["unknown trace event ", inspect(tag), " with info:" |
      safe_inspect([arg1, arg2], options)]
  end

  defp inspect_seq_trace({ :send, serial, pid, to, msg }, options) do
    [?(, inspect(serial), ") ", inspect_pid(pid), " sends (to ",
      inspect_pid(to), "):" | safe_inspect(msg, options)]
  end

  defp inspect_seq_trace({ :receive, serial, from, pid, msg }, options) do
    [?(, inspect(serial), ") ", inspect_pid(pid), " receives (from ",
      inspect_pid(from), "):" | safe_inspect(msg, options)]
  end

  defp inspect_seq_trace({ :print, serial, pid, _, info}, options) do
    [?(, inspect(serial), ") ", inspect_pid(pid), " prints:" |
      safe_inspect(info, options)]
  end

  defp inspect_seq_trace(other, options) do
    ["unknown seq_trace event:" | safe_inspect(other, options)]
  end

  defp inspect_ts(now) do
    { _, { hour, min, sec} } = :calendar.now_to_local_time(now)
    :io_lib.format('~2..0b:~2..0b:~2..0b', [hour, min, sec])
  end

  defp inspect_pid({pid, node_name}) do
    [inspect(pid), " (on ", to_string(node_name), ?)]
  end

  defp inspect_pid(pid) when node(pid) === node() or is_atom(pid) do
    inspect(pid)
  end

  defp inspect_pid(pid) do
    inspect_pid({pid, node(pid)})
  end

  # Stacktrace from dump
  defp inspect_call_info( <<"=proc:", _rest :: binary >> = dump, options) do
    inspect_dump(dump, options)
  end

  # rewrite caller as single entry stacktrace
  defp inspect_call_info({mod, fun, arity}, options)
      when is_atom(mod) and is_atom(fun) and is_integer(arity) do
    format_stacktrace([{mod, fun, arity, []}], options)
  end

  # :undefined caller from tail call, ignore.
  defp inspect_call_info(:undefined, _options), do: []

  defp write(device, iodata, options) do
    colors_options = Keyword.get(options, :colors, [])
    enabled_color = Keyword.get(colors_options, :enabled, false)
    info_color = Keyword.get(colors_options, :trace_info, :magenta)
    iodata = [?\n, IO.ANSI.format_fragment(info_color, enabled_color),
      iodata | IO.ANSI.format_fragment(:reset, enabled_color)]
    :ok = IO.puts(device, iodata)
  end

  defp safe_format_exit(reason, options) do
    try do
      Exception.format_exit(reason)
    else
      formatted ->
        formatted
    catch
      _, _ ->
        safe_inspect(reason, options)
    end
  end

  defp safe_inspect(term, options) do
    inspect_options = Keyword.get(options, :inspect, [])
    try do
      inspect(term, inspect_options)
    else
      formatted ->
        indent(formatted)
    catch
      _, _ ->
        inspect(term, [records: false, structs: false] ++ inspect_options)
        |> indent()
    end
  end

  defp indent(formatted) do
    :binary.split(formatted, [<<?\n>>], [:global])
    |> Enum.map(&( ["\n    " | &1] ))
  end

  defp inspect_dump(dump, options) do
    parse_dump(dump)
    |> format_stacktrace(options)
  end

  defp parse_dump(dump) do
    Regex.scan(~r/^(?|CP:|0x[0-9a-f]{8,16} Return addr) 0x[0-9a-f]{8,16} \((?|([[:lower:]][[:alnum:]@_]*)|\'([^']*)\'):(?|([[:lower:]][[[:alnum:]@_]*)|\'([^']*)\')\/(\d{1,3}) \+ \d+\)$/m, dump)
      |> Enum.map(&parse_dump_match/1)
  end

  defp parse_dump_match([_dump_line, mod, fun, arity]) do
    { String.to_existing_atom(mod), String.to_existing_atom(fun),
      String.to_integer(arity), []}
  end

  # Rest of file based on code from IEx.Evaluator
  #
  # Copyright 2012-2013 Plataformatec.
  #
  # Licensed under the Apache License, Version 2.0 (the "License");
  # you may not use this file except in compliance with the License.
  # You may obtain a copy of the License at
  #
  # http://www.apache.org/licenses/LICENSE-2.0
  #
  # Unless required by applicable law or agreed to in writing, software
  # distributed under the License is distributed on an "AS IS" BASIS,
  # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  # See the License for the specific language governing permissions and
  # limitations under the License.

  defp format_stacktrace(stack, options) do
    entries =
      for entry <- stack do
        split_entry(Exception.format_stacktrace_entry(entry))
      end

    width = Enum.reduce entries, 0, fn {app, _}, acc ->
      max(String.length(app), acc)
    end

    colors_options = Keyword.get(options, :colors, [])
    enabled_color = Keyword.get(colors_options, :enabled, false)
    info_color = Keyword.get(colors_options, :trace_info, :magenta)
    app_color = Keyword.get(colors_options, :trace_app, [:magenta | :bright])
    Enum.map(entries, &(["\n    " |
      format_entry(&1, width, app_color, info_color, enabled_color)]))
  end

  defp split_entry(entry) do
    case entry do
      "(" <> _ ->
        case :binary.split(entry, ") ") do
          [left, right] -> {left <> ") ", right}
          _ -> {"", entry}
        end
      _ ->
        {"", entry}
    end
  end

  defp format_entry({app, info}, width, app_color, info_color, enabled_color) do
    app = String.rjust(app, width)
    IO.ANSI.format([app_color, app, :reset, info_color, info], enabled_color)
  end

end
