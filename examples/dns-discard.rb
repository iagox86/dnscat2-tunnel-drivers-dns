# Encoding: ASCII-8BIT
##
# dns-discard.rb
# Created July, 2018
# By Ron Bowes
#
# See: LICENSE.md
#
# This is an example of how to use the dnscat2-tunneldrivers-dns library to
# implement a discard-like program over DNS
#
# This is entirely a toy program, designed to show off the protocol moreso than
# anything else. Since this lets people download random files off your machine,
# it's probably a good idea not to run this in any real environment. :)
##

require 'tunnel-drivers-dns'
require 'trollop'
require 'singlogger'

VERSION = "0.0.0"
MY_NAME = "tunnel-driver-dns-example-discard v#{VERSION}"

DEFAULT_HOST = '0.0.0.0'
DEFAULT_PORT = 53533
DEFAULT_TAGS = nil
DEFAULT_DOMAINS = nil

OPTS = Trollop::options do
  version(MY_NAME)

  opt :version, "Get the #{MY_NAME} version (spoiler alert)",     :type => :boolean, :default => false
  opt :debug,   "The log level (debug/info/warning/error/fatal)", :type => :string,  :default => 'debug'

  opt :host,    "The ip address to listen on",                    :type => :string,  :default => DEFAULT_HOST
  opt :port,    "The port to listen on",                          :type => :integer, :default => DEFAULT_PORT
  opt :tags,    "The tags (prefixes) to use, comma-separated",    :type => :string,  :default => nil
  opt :domains, "The domains to use, comma-separated",            :type => :string,  :default => nil

  opt :response,   "How should we respond? Options: blank|nil|error|critical", :type => :string, :default => 'blank'
  opt :error_text, "The text to use for the error or critical error",          :type => :string, :default => "Exception!!!"
end

SingLogger.set_level_from_string(level: OPTS[:debug])

if(!OPTS[:tags] && !OPTS[:domains])
  $stderr.puts("You need to specify either a tag or a domain!")
  exit(1)
end

tags    = OPTS[:tags]    ? OPTS[:tags].split(/ *, */)    : nil
domains = OPTS[:domains] ? OPTS[:domains].split(/ *, */) : nil

if(['blank', 'nil', 'error', 'critical'].index(OPTS[:response]).nil?)
  $stderr.puts("The response options are 'blank', 'nil', 'error', or 'critical'")
  exit(1)
end

class Controller
  def feed(data:, max_length:)
    puts("IN: #{data}")

    case OPTS[:response]
    when 'blank'
      return ''
    when 'nil'
      return nil
    when 'error'
      raise Dnscat2::TunnelDrivers::DNS::Exception.new(OPTS[:error_text])
    when 'critical'
      raise Exception.new(OPTS[:error_text])
    end
  end
end

driver = Dnscat2::TunnelDrivers::DNS::Driver.new(
  tags:    tags,
  domains: domains,
  sink:    Controller.new(),
  host:    OPTS[:host],
  port:    OPTS[:port],
  encoder: 'hex',
)

driver.start()
driver.wait()
