# Encoding: ASCII-8BIT
##
# dns-echo.rb
# Created July, 2018
# By Ron Bowes
#
# See: LICENSE.md
#
# This is an example of how to use the dnscat2-tunneldrivers-dns library to
# implement an echo-like program over DNS
#
# This is entirely a toy program, designed to show off the protocol moreso than
# anything else. Since this lets people download random files off your machine,
# it's probably a good idea not to run this in any real environment. :)
##

require 'tunnel-drivers-dns'
require 'trollop'
require 'singlogger'

VERSION = "0.0.0"
MY_NAME = "tunnel-driver-dns-example-echo v#{VERSION}"

DEFAULT_HOST = '0.0.0.0'
DEFAULT_PORT = 53533
DEFAULT_ENCODER = 'hex'
DEFAULT_TAGS = nil
DEFAULT_DOMAINS = nil

OPTS = Trollop::options do
  version(MY_NAME)

  opt :version, "Get the #{MY_NAME} version (spoiler alert)",     :type => :boolean, :default => false
  opt :debug,   "The log level (debug/info/warning/error/fatal)", :type => :string,  :default => 'debug'

  opt :host,    "The ip address to listen on",                    :type => :string,  :default => DEFAULT_HOST
  opt :port,    "The port to listen on",                          :type => :integer, :default => DEFAULT_PORT
  opt :encoder, "The encoder to use (hex|base32)",                :type => :string,  :default => DEFAULT_ENCODER
  opt :tags,    "The tags (prefixes) to use, comma-separated",    :type => :string,  :default => nil
  opt :domains, "The domains to use, comma-separated",            :type => :string,  :default => nil

  opt :reverse,  "Reverse the echoed data",  :type => :boolean, :default => false
  opt :upcase,   "Upcase the echoed data",   :type => :boolean, :default => false
  opt :downcase, "Downcase the echoed data", :type => :boolean, :default => false
  opt :rot13,    "ROT13 the echoed data",    :type => :boolean, :default => false
end

SingLogger.set_level_from_string(level: OPTS[:debug])

if(!OPTS[:tags] && !OPTS[:domains])
  $stderr.puts("You need to specify either a tag or a domain!")
  exit(1)
end

tags    = OPTS[:tags]    ? OPTS[:tags].split(/ *, */)    : nil
domains = OPTS[:domains] ? OPTS[:domains].split(/ *, */) : nil

class Controller
  def feed(data:, max_length:)
    puts("IN: #{data}")

    if(OPTS[:reverse])
      data = data.reverse
    end

    if(OPTS[:upcase])
      data = data.upcase()
    end

    if(OPTS[:downcase])
      data = data.downcase()
    end

    if(OPTS[:upcase] && OPTS[:downcase])
      data = data.chars.map() { |c| [true,false].sample ? c.upcase : c.downcase }.join() 
    end

    if(OPTS[:rot13])
      data = data.chars.map() { |c| ('A'..'Z').include?(c) ? ((c.ord - 'A'.ord + 13) % 26 + 'A'.ord).chr : (('a'..'z').include?(c) ? ((c.ord - 'a'.ord + 13) % 26 + 'a'.ord).chr : c) }.join()
    end

    puts("OUT: #{data}")

    return data
  end
end

driver = Dnscat2::TunnelDrivers::DNS::Driver.new(
  tags:    tags,
  domains: domains,
  sink:    Controller.new(),
  host:    OPTS[:host],
  port:    OPTS[:port],
  encoder: OPTS[:encoder],
)
driver.start()
driver.wait()
