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

VERSION = '0.0.0'.freeze
MY_NAME = "tunnel-driver-dns-example-discard v#{VERSION}".freeze

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
    default: DEFAULT_TAGS
  )
  opt(
    :domains, 'The domains to use, comma-separated',
    type:     :string,
    default:  DEFAULT_DOMAINS
  )
  opt(
    :passthrough, 'Upstream DNS to forward unknown requests to',
    type:         :string,
    default:      nil
  )
  opt(
    :encoder, "The encoder to use ('hex' or 'base32')",
    type:     :string,
    default:  'hex'
  )

  opt(
    :response, 'How should we respond? Options: blank|nil|error|critical',
    type:      :string,
    default:  'blank'
  )
  opt(
    :error_text, 'The text to use for the error or critical error',
    type:        :string,
    default:     'Exception!!!'
  )
end

SingLogger.set_level_from_string(level: OPTS[:debug])

if !OPTS[:tags] && !OPTS[:domains]
  raise(ArgumentError, 'You need to specify either a tag or a domain!')
end

tags    = OPTS[:tags]    ? OPTS[:tags].split(/ *, */)    : []
domains = OPTS[:domains] ? OPTS[:domains].split(/ *, */) : []

if ['blank', 'nil', 'error', 'critical'].index(OPTS[:response]).nil?
  raise(ArgumentError, "The response options are 'blank', 'nil', 'error', or 'critical'")
end

##
# A simple controller class to handle incoming requests.
##
class Controller
  def feed(data:, **)
    puts("IN: #{data}")

    case OPTS[:response]
    when 'blank'
      return ''
    when 'nil'
      return nil
    when 'error'
      raise(Dnscat2::TunnelDrivers::DNS::Exception, OPTS[:error_text])
    when 'critical'
      raise(Exception, OPTS[:error_text])
    end
  end
end

driver = Dnscat2::TunnelDrivers::DNS::Driver.new(
  host:        OPTS[:host],
  port:        OPTS[:port],
  passthrough: OPTS[:passthrough],
)
driver.add_sinks(
  domains: domains,
  tags:    tags,
  sink:    Controller.new,
  encoder: OPTS[:encoder],
)
driver.wait
