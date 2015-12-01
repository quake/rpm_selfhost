require 'net/http'
require 'json'
require 'zlib'

run_id = nil

2.times do
  File.open(ARGV[0]).each_slice(2) do |uri_log, body_log|
    uris = uri_log.strip.split("/")
    body = body_log.gsub(/.*\: REQUEST BODY\: /, '')
    http = Net::HTTP.new('localhost', 9292)

    if run_id.nil?
      if uris[4] =~ /^connect/
        req = Net::HTTP::Post.new("/" + uris[1..-1].join("/"), 'CONTENT-ENCODING' => 'deflate')
        req.content_type = "application/octet-stream"
        req.body = Zlib::Deflate.deflate(body, Zlib::DEFAULT_COMPRESSION)
        run_id = JSON.parse(http.request(req).body)["return_value"]["agent_run_id"].to_s
        break
      end
    else
      if uris[4] =~ /^analytic_event_data|metric_data|error_data/
        uris[-1].gsub!(/run_id=(\d+)/, "run_id=#{run_id}")
        req = Net::HTTP::Post.new("/" + uris[1..-1].join("/"), 'CONTENT-ENCODING' => 'deflate')
        req.content_type = "application/octet-stream"
        req.body = Zlib::Deflate.deflate(body, Zlib::DEFAULT_COMPRESSION)
        http.request(req)
      end
    end
  end
end