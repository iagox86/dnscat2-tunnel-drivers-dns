# Encoding: ASCII-8BIT

##
# driver_dns.rb
# Created July, 2018
# By Ron Bowes
#
# See: LICENSE.md
#
# A dnscat2 "driver" is simply something that will send and receive data.
# Outgoing and incoming data are literally just packets of bytes, with a
# particular maximum length. I call this a "transport protocol".
#
# This is strictly "layer 2" style - there is no de-duplication or delivery
# guarantees at this level. That's expected to be handled by the dnscat2
# protocol.
#
# I have documented this like crazy in README.md, so you best check that out!
##

require 'nesser'
require 'singlogger'
require 'socket'

require 'dnscat2/tunnel_drivers/dns/builders/a'
require 'dnscat2/tunnel_drivers/dns/builders/aaaa'
require 'dnscat2/tunnel_drivers/dns/builders/cname'
require 'dnscat2/tunnel_drivers/dns/builders/mx'
require 'dnscat2/tunnel_drivers/dns/builders/ns'
require 'dnscat2/tunnel_drivers/dns/builders/txt'

require 'dnscat2/tunnel_drivers/dns/encoders/base32'
require 'dnscat2/tunnel_drivers/dns/encoders/hex'

require 'dnscat2/tunnel_drivers/dns/readers/standard'

require 'dnscat2/tunnel_drivers/dns/exception'

module Dnscat2
  module TunnelDrivers
    module DNS
      ##
      # The main class for this library - see README.md for full usage
      # documentation!
      ##
      class Driver
        # A simple map of all the "builders" we support
        BUILDERS = {
          ::Nesser::TYPE_A     => Builders::A,
          ::Nesser::TYPE_AAAA  => Builders::AAAA,
          ::Nesser::TYPE_CNAME => Builders::CNAME,
          ::Nesser::TYPE_MX    => Builders::MX,
          ::Nesser::TYPE_NS    => Builders::NS,
          ::Nesser::TYPE_TXT   => Builders::TXT,
        }.freeze

        ##
        # Take a question, unpack it, pass it to the sink, get the data back,
        # and encode the message into a series of resource records.
        ##
        private
        def _handle_question(question:)
          # We need to be able to set the question_type separate from
          # question.type in TYPE_ANY situations
          question_type = question.type
          # Handle the ANY type
          if question.type == ::Nesser::TYPE_ANY
            # We need the key so we can build the return packet later
            # (We exclude AAAA because not all OSes support it (I'm looking at
            # you, Windows!)
            question_type = BUILDERS.keys.reject { |k| k == ::Nesser::TYPE_AAAA }.sample
            builder = BUILDERS[question_type]
            @l.debug('TunnelDrivers::DNS ANY request!')
          else
            # Make sure the incoming message is a known type
            builder = BUILDERS[question.type]
            if builder.nil?
              raise(Exception, "Received a DNS packet of unknown type: #{question.type}")
            end
          end

          # We only have one reader right now, so use it
          reader = Readers::Standard.new(tags: @tags, domains: @domains, encoder: @encoder)

          # Parse the incoming message
          incoming_data, tag, domain = reader.read_data(question: question)
          if incoming_data.nil?
            @l.debug("TunnelDrivers::DNS question wasn't for us: #{question}")
            return nil
          end

          # Initialize a builder with the infos we got (we need this now so we
          # can determine the maximum length)
          builder = builder.new(tag: tag, domain: domain, encoder: @encoder)

          # Exchange data with the sink
          outgoing_data = @sink.feed(data: incoming_data, max_length: builder.max_length)

          # Handle a nil return cleanly
          outgoing_data ||= ''

          # Make sure the sink didn't mess with us
          if outgoing_data.length > builder.max_length
            raise(Exception, "The sink returned too much data: #{outgoing_data.length}, max_length was #{builder.max_length}")
          end

          # Encode it into one or more resource records
          rrs = builder.build(data: outgoing_data)

          # Stuff each resource record into an Answer object
          return rrs.map do |rr|
            Nesser::Answer.new(
              name: question.name,
              type: question_type,
              cls:  question.cls,
              ttl:  3600, # TTL doesn't really matter
              rr:   rr,
            )
          end
        end

        ##
        # Unpack and sanity check a transaction. This is also where all
        # exceptions are handled.
        ##
        private
        def _handle_transaction(transaction:)
          @l.debug('TunnelDrivers::DNS Received a message!')

          request = transaction.request
          if request.questions.length != 1
            raise(Exception, "Incoming DNS request had a weird number of questions (expected: 1, it had: #{request.questions.length})")
          end

          question = request.questions[0]
          @l.debug("TunnelDrivers::DNS Question = #{question}")

          answers = _handle_question(question: question)
          @l.debug("TunnelDrivers::DNS Answers = #{answers}")
          if !answers || answers.empty?
            transaction.error!(Nesser::RCODE_NAME_ERROR) # TODO: Configurable error / passthrough?
            return
          end

          transaction.answer!(answers)
        rescue Dnscat2::TunnelDrivers::Exception => e # One of our exceptions
          @l.error("TunnelDrivers::DNS An error occurred processing the DNS request: #{e}")
          transaction.error!(Nesser::RCODE_SERVER_FAILURE)
        rescue ::StandardError => e # A BAD exception! We don't want these to ever happen!
          @l.fatal("TunnelDrivers::DNS A serious error occurred processing the DNS request: #{e}")
          e.backtrace.each do |bt|
            @l.debug(bt.to_s)
          end
          transaction.error!(Nesser::RCODE_SERVER_FAILURE)
        end

        ##
        # Create an instance of the tunnel driver.
        #
        # tags: An array of tags (prefixes) that we are listening for (or nil)
        # domains: An array of domains (postfixes) that we are listening for (or
        #   nil)
        # sink: The sink to send data to and get it from (simply a class that
        #   has one method: `feed(data:, max_length:)`. For more information,
        #   see README.md
        # host: The ip address to listen on
        # port: The port to listen on
        # settings: Any other settings that we decide to define (such as
        #   `encoder:`)
        ##
        public
        def initialize(tags:, domains:, sink:, host: '0.0.0.0', port: 53, **settings)
          @l = SingLogger.instance
          @l.debug("TunnelDrivers::DNS New instance! tags = #{tags}, domains = #{domains}, sink = #{sink}, host = #{host}, port = #{port}")

          @tags     = tags
          @domains  = domains
          @sink     = sink
          @host     = host
          @port     = port

          if settings[:encoder] == 'base32'
            @l.info('TunnelDrivers::DNS Setting encoder to Base32!')
            @encoder = Encoders::Base32
          else
            @encoder = Encoders::Hex
          end

          @mutex = Mutex.new
        end

        ##
        # Start the driver. If this is called while it's already started,
        # `Exception` is thrown.
        #
        # If no socket is passed in, a new UDPSocket is created.
        ##
        public
        def start(s: nil, auto_close_socket: true)
          @l.info('TunnelDrivers::DNS Starting DNS tunnel driver!')
          @mutex.synchronize do
            unless @nesser.nil?
              raise(Exception, 'DNS tunnel is already running')
            end

            @s = s || ::UDPSocket.new
            @auto_close_socket = auto_close_socket
            @nesser = Nesser::Nesser.new(s: @s, logger: @l, host: @host, port: @port) do |transaction|
              _handle_transaction(transaction: transaction)
            end
          end
        end

        ##
        # Stop the driver. If thi sis called while it's already stopped,
        # `Exception` is thrown.
        #
        # Also closes the socket if `auto_close_socket` was `true` when
        # `start()` was called.
        ##
        public
        def stop
          @l.info('TunnelDrivers::DNS Stopping DNS tunnel!')
          @mutex.synchronize do
            if @nesser.nil?
              raise(Exception, "DNS tunnel isn't running!")
            end

            @nesser.stop
            @nesser = nil
            if @auto_close_socket
              @s.close
            end
          end
        end

        ##
        # Returns when the service stops (or never).
        ##
        public
        def wait
          unless @nesser
            return
          end
          @nesser.wait
        end
      end
    end
  end
end
