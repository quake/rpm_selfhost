require 'cuba'
require 'json'
require 'zlib'
require 'influxdb'

module RpmSelfhostHelper
  def json_body
    req.body.rewind
    body = req.body.read
    body = Zlib::Inflate.inflate(body) if req.env["HTTP_CONTENT_ENCODING"] == "deflate"
    JSON.parse body
  end

  def response(result = nil)
    res.write({return_value: result}.to_json)
  end

  def to_influx(data)
    influxdb.write_points(data)
  end

  def influxdb
    @influxdb ||= InfluxDB::Client.new 'collector', host: 'localhost'
  end

  def get_runner(run_id)
    influxdb.query("select * from runner where run_id = '#{run_id}'") do |name, tags, values|
      return values[0]['app_name'], values[0]['host']
    end
  end
end

Cuba.plugin RpmSelfhostHelper

Cuba.define do
  on 'agent_listener/:api_version' do |api_version|
    on ':license_key' do |license_key|

      on 'get_redirect_host' do
        response 'localhost'
      end

      on 'connect' do
        run_id = (Time.now.to_f * 1000000 + rand(10000)).to_i
        c = json_body[0]
        data = [{
          series: 'runner',
          tags: {run_id: run_id, host: c['host'], app_name: c['app_name'][0]},
          values: {pid: c['pid']}
        }]
        to_influx(data)
        response agent_run_id: run_id
      end

      on 'get_agent_commands' do
        response []
      end

      on 'agent_command_results' do
        response []
      end

      on 'metric_data' do
        body = json_body
        timestamp = body[1].to_i
        data = body[3].map do |m, v|
          {
            series: 'metric_data',
            tags: { name: m['name'], scope: m['scope'] }.reject{|key, value| value == ''},
            values: { call_count: v[0], total_call_time: v[1], total_exclusive_time: v[2], min_call_time: v[3], max_call_time: v[4], sum_of_squares: v[5] },
            timestamp: timestamp
          }
        end
        to_influx(data)
        response
      end

      on 'sql_trace_data' do
        response
      end

      on 'transaction_sample_data' do
        response
      end

      on 'error_data' do
        data = json_body[1].map do |e|
          data = {
            series: 'error_data',
            tags: { error_method: e[1], req_uri: e[4]['req_uri'] },
            values: { message: e[2] },
            timestamp: e[0].to_i
          }
        end
        to_influx(data)
        response
      end

      on 'profile_data' do
        response
      end

      on 'shutdown' do
        response
      end

      on 'analytic_event_data' do
        app_name, host = get_runner(req.params['run_id'])
        data = json_body[1].map do |d, _|
          {
            series: 'analytic_event_data',
            tags: { name: d['name'], type: d['type'], app_name: app_name, host: host },
            values: { duration: d['duration'], database_duration: d['databaseDuration'].to_f, external_duration: d['externalDuration'].to_f },
            timestamp: d['timestamp'].to_i
          }
        end
        to_influx(data)
        response
      end

      on 'custom_event_data' do
        response
      end

      on 'error_event_data' do
        response
      end

    end
  end
end