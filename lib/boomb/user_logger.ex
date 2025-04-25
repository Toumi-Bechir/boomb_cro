defmodule Boomb.UserLogger do
  import Plug.Conn
  alias Boomb.Repo
  alias Boomb.UserLog
  alias UAInspector

  # Define log_attempt/6 to include session_token
  def log_attempt(conn, action, status, user \\ nil, error_message \\ nil, session_token \\ nil) do
    ip_address = get_ip_address(conn)
    user_agent = get_user_agent(conn)
    device_info = parse_user_agent(user_agent)
    geo_info = get_geolocation(ip_address)
    local_time = get_local_time(conn)

    attrs = %{
      user_id: if(user, do: user.id, else: nil),
      action: action,
      status: status,
      ip_address: ip_address,
      local_time: local_time,
      timezone: geo_info[:timezone],
      city: geo_info[:city],
      region: geo_info[:region],
      country: geo_info[:country],
      latitude: geo_info[:latitude],
      longitude: geo_info[:longitude],
      user_agent: user_agent,
      device: device_info[:device],
      device_type: device_info[:device_type],
      os: device_info[:os],
      browser: device_info[:browser],
      browser_version: device_info[:browser_version],
      session_token: session_token, # Include session_token in the log
      error_message: error_message
    }

    %UserLog{}
    |> UserLog.changeset(attrs)
    |> Repo.insert()
  end

  defp get_ip_address(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [forwarded_ip | _] ->
        forwarded_ip |> String.split(",") |> List.first() |> String.trim()

      _ ->
        conn.remote_ip
        |> :inet.ntoa()
        |> to_string()
    end
  end

  defp get_user_agent(conn) do
    case get_req_header(conn, "user-agent") do
      [user_agent | _] -> user_agent
      _ -> nil
    end
  end

  defp parse_user_agent(user_agent) do
    case user_agent do
      nil ->
        %{
          device: nil,
          device_type: nil,
          os: nil,
          browser: nil,
          browser_version: nil
        }

      user_agent ->
        case UAInspector.parse(user_agent) do
          %UAInspector.Result{device: device, os: os, client: client} ->
            %{
              device: if(device && device != :unknown, do: device.brand),
              device_type: if(device && device != :unknown, do: device.type),
              os: if(os && os != :unknown, do: os.name),
              browser: if(client && client != :unknown, do: client.name),
              browser_version: if(client && client != :unknown && client.version, do: to_string(client.version))
            }

          _ ->
            %{
              device: nil,
              device_type: nil,
              os: nil,
              browser: nil,
              browser_version: nil
            }
        end
    end
  end

  defp get_geolocation(ip_address) do
    case GeoIP.lookup(ip_address) do
      {:ok, geo_data} ->
        %{
          timezone: geo_data[:time_zone],
          city: geo_data[:city],
          region: geo_data[:region_name],
          country: geo_data[:country_name],
          latitude: geo_data[:latitude],
          longitude: geo_data[:longitude]
        }

      {:error, _reason} ->
        %{
          timezone: nil,
          city: nil,
          region: nil,
          country: nil,
          latitude: nil,
          longitude: nil
        }
    end
  end

  defp get_local_time(conn) do
    DateTime.utc_now()
    |> DateTime.to_string()
  end
end