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
# See README.md in this repository for gory detail!
#
# TODO: Handle record type `any`
##

require 'nesser'
require 'singlogger'
require 'socket'
require 'thread'

require 'dnscat2/tunnel_drivers/dns/builders/a'
require 'dnscat2/tunnel_drivers/dns/builders/aaaa'
require 'dnscat2/tunnel_drivers/dns/builders/cname'
require 'dnscat2/tunnel_drivers/dns/builders/mx'
require 'dnscat2/tunnel_drivers/dns/builders/ns'
require 'dnscat2/tunnel_drivers/dns/builders/txt'

require 'dnscat2/tunnel_drivers/dns/encoders/base32'
require 'dnscat2/tunnel_drivers/dns/encoders/hex'

require 'dnscat2/tunnel_drivers/dns/readers/standard'

require 'dnscat2/tunnel_drivers/dns/constants'
require 'dnscat2/tunnel_drivers/dns/exception'

module Dnscat2
  module TunnelDrivers
    module DNS
      class Driver
        BUILDERS = {
          ::Nesser::TYPE_A     => Builders::A,
          ::Nesser::TYPE_AAAA  => Builders::AAAA,
          ::Nesser::TYPE_CNAME => Builders::CNAME,
          ::Nesser::TYPE_MX    => Builders::MX,
          ::Nesser::TYPE_NS    => Builders::NS,
          ::Nesser::TYPE_TXT   => Builders::TXT,
        }

        private
        def _handle_question(question:)
          # We need to be able to set the question_type separate from
          # question.type in TYPE_ANY situations
          question_type = question.type
          # Handle the ANY type
          if(question.type == ::Nesser::TYPE_ANY)
            # We need the key so we can build the return packet later
            # (We exclude AAAA because not all OSes support it (I'm looking at
            # you, Windows!)
            question_type = BUILDERS.keys.select { |k| k != ::Nesser::TYPE_AAAA }.sample
            builder = BUILDERS[question_type]
            @l.debug("TunnelDrivers::DNS ANY request!")
          else
            # Make sure the incoming message is a known type
            builder = BUILDERS[question.type]
            if(builder.nil?)
              raise(Exception, "Received a DNS packet of unknown type: #{question.type}")
            end
          end

          # We only have one reader right now, so use it
          reader = Readers::Standard.new(tags: @tags, domains: @domains, encoder: @encoder)

          # Parse the incoming message
          incoming_data, tag, domain = reader.read_data(question: question)
          if(incoming_data.nil?)
            @l.debug("TunnelDrivers::DNS question wasn't for us: #{question}")
            return nil
          end

          # Initialize a builder with the infos we got (we need this now so we
          # can determine the maximum length)
          builder = builder.new(tag: tag, domain: domain, encoder: @encoder)

          # Exchange data with the sink
          outgoing_data = @sink.feed(data: incoming_data, max_length: builder.max_length)

          # Make sure the sink didn't mess with us
          if(outgoing_data.length > builder.max_length)
            raise(Exception, "The sink returned too much data: #{outgoing_data.length}, max_length was #{builder.max_length}")
          end

          # Encode it
          rrs = builder.build(data: outgoing_data)

          return rrs.map() do |rr|
            Nesser::Answer.new(
              name: question.name,
              type: question_type,
              cls:  question.cls,
              ttl:  3600, # TTL doesn't really matter
              rr:   rr,
            )
          end
        end

        private
        def _handle_transaction(transaction:)
          begin
            @l.debug("TunnelDrivers::DNS Received a message!")

            request = transaction.request
            if(request.questions.length != 1)
              raise(Exception, "Incoming DNS request had a weird number of questions (expected: 1, it had: #{request.questions.length})")
            end

            question = request.questions[0]
            @l.debug("TunnelDrivers::DNS Question = #{question}")

            answers = _handle_question(question: question)
            @l.debug("TunnelDrivers::DNS Answers = #{answers}")
            if(!answers || answers.length == 0)
              transaction.error!(Nesser::RCODE_NAME_ERROR) # TODO: Configurable error / passthrough?
              return
            end

            transaction.answer!(answers)
          rescue Exception => e # One of our exceptions
            @l.error("TunnelDrivers::DNS An error occurred processing the DNS request: #{e}")
            transaction.error!(Nesser::RCODE_SERVER_FAILURE)
          rescue ::Exception => e # A BAD exception! We don't want these to ever happen!
            @l.fatal("TunnelDrivers::DNS A serious error occurred processing the DNS request: #{e}")
            e.backtrace.each do |bt|
              @l.debug("#{bt}")
            end
            transaction.error!(Nesser::RCODE_SERVER_FAILURE)
          end
        end

        public
        def initialize(tags:, domains:, sink:, host:"0.0.0.0", port:53, **settings)
          @l = SingLogger.instance()
          @l.debug("TunnelDrivers::DNS New instance! tags = #{tags}, domains = #{domains}, sink = #{sink}, host = #{host}, port = #{port}")

          @tags     = tags
          @domains  = domains
          @sink     = sink
          @host     = host
          @port     = port

          if(settings[:encoder] == 'base32')
            @l.info("TunnelDrivers::DNS Setting encoder to Base32!")
            @encoder = Encoders::Base32
          else
            @encoder = Encoders::Hex
          end

          @mutex = Mutex.new()
        end

        def start(s:nil, auto_close_socket:true)
          @l.info("TunnelDrivers::DNS Starting DNS tunnel driver!")
          @mutex.synchronize() do
            if(!@nesser.nil?)
              raise(Exception, "DNS tunnel is already running")
            end

            @s = UDPSocket.new()
            @auto_close_socket = auto_close_socket
            @nesser = Nesser::Nesser.new(s: @s, logger: @l, host: @host, port: @port) do |transaction|
              _handle_transaction(transaction: transaction)
            end
          end
        end

        public
        def stop()
          @l.info("TunnelDrivers::DNS Stopping DNS tunnel!")
          @mutex.synchronize() do
            if(@nesser.nil?)
              raise(Exception, "DNS tunnel isn't running!")
            end

            @nesser.stop()
            @nesser = nil
            if(@auto_close_socket)
              @s.close()
            end
          end
        end

        public
        def wait()
          if(!@nesser)
            return
          end
          @nesser.wait()
        end
      end
    end
  end
end
