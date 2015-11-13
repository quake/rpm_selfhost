require 'net/http'
require 'JSON'

File.open(ARGV[0]).each_slice(2) do |uri_log, body_log|
  uris = uri_log.strip.split("/")
  body = body_log.gsub(/.*\: REQUEST BODY\: /, '')
  http = Net::HTTP.new('localhost', 9292)
  req = Net::HTTP::Post.new("/" + uris[1..-1].join("/"), {'Content-Type' =>'application/json'})

  if uris[4].start_with? 'analytic_event_data'
    req.body = body
    http.request(req)
  end
end