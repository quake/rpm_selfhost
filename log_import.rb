require 'net/http'
require 'zlib'

File.open(ARGV[0]).each_slice(2) do |uri_log, body_log|
  uris = uri_log.strip.split("/")
  body = body_log.gsub(/.*\: REQUEST BODY\: /, '')
  http = Net::HTTP.new('localhost', 9292)
  req = Net::HTTP::Post.new("/" + uris[1..-1].join("/"), 'CONTENT-ENCODING' => 'deflate')
  req.content_type = "application/octet-stream"

  if uris[4] =~ /^analytic_event_data|metric_data|error_data/
    req.body = Zlib::Deflate.deflate(body, Zlib::DEFAULT_COMPRESSION)
    http.request(req)
  end
end