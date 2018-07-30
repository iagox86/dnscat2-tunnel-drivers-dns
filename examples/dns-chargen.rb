# Encoding: ASCII-8BIT

##
# dns-chargen.rb
# Created July, 2018
# By Ron Bowes
#
# See: LICENSE.md
#
# This is an example of how to use the dnscat2-tunneldrivers-dns library to
# implement a chargen program over DNS
#
# This is entirely a toy program, designed to show off the protocol moreso than
# anything else. Since this lets people download random files off your machine,
# it's probably a good idea not to run this in any real environment. :)
##

require 'tunnel-drivers-dns'
require 'trollop'
require 'singlogger'

VERSION = '0.0.0'.freeze
MY_NAME = "tunnel-driver-dns-example-chargen v#{VERSION}".freeze

DEFAULT_HOST = '0.0.0.0'.freeze
DEFAULT_PORT = 53
DEFAULT_TAGS = nil
DEFAULT_DOMAINS = nil

OPTS = Trollop.options do
  version(MY_NAME)

  opt(
    :version, "Get the #{MY_NAME} version (spoiler alert)",
    type:     :boolean,
    default:  false,
  )
  opt(
    :debug,  'The log level (debug/info/warning/error/fatal)',
    type:    :string,
    default: 'debug'
  )

  opt(
    :host,   'The ip address to listen on',
    type:    :string,
    default: DEFAULT_HOST
  )
  opt(
    :port,   'The port to listen on',
    type:    :integer,
    default: DEFAULT_PORT
  )
  opt(
    :tags,   'The tags (prefixes) to use, comma-separated',
    type:    :string,
    default: nil
  )
  opt(
    :domains, 'The domains to use, comma-separated',
    type:     :string,
    default:  nil
  )

  opt(
    binary,  'Send back binary data instead of just text',
    type:    :boolean,
    default: false
  )
end

SingLogger.set_level_from_string(level: OPTS[:debug])

if !OPTS[:tags] && !OPTS[:domains]
  raise(ArgumentError, 'You need to specify either a tag or a domain!')
end

tags    = OPTS[:tags]    ? OPTS[:tags].split(/ *, */)    : nil
domains = OPTS[:domains] ? OPTS[:domains].split(/ *, */) : nil

##
# Just a simple controller that handles the packets.
##
class Controller
  def feed(data:, max_length:)
    puts("IN: #{data}")

    choices = (0..255).to_a
    unless OPTS[:binary]
      choices = (('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a)
    end

    return (1..max_length).map { choices.sample.chr }.join
  end
end

driver = Dnscat2::TunnelDrivers::DNS::Driver.new(
  tags:    tags,
  domains: domains,
  sink:    Controller.new,
  host:    OPTS[:host],
  port:    OPTS[:port],
  encoder: 'hex',
)

driver.start
driver.wait
