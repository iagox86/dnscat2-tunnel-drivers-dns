# Dnscat2::TunnelDrivers::DNS

This is a "tunnel driver" for dnscat2 (specifically, dnscat2-core).

A tunnel driver is a "driver" that sits between dnscat2 and the Internet.
Despite the project's name, a dnscat2 driver can theoretically use any protocol
(TCP, UDP, ICMP, HTTPS, etc.). In practice, it is optimized for one-way
client-to-server request/response communication (DNS, ping, etc)

This driver, in particular, implements dnscat2's namesake protocol: DNS. It
implements encoding and decoding to a number of record types, and in two
different formats: hex and base32.

This README should be considered the authoritative source for the dnscat2
Tunnel Protocol for DNS, superseding all others (although it is nearly identical
to the previous, as far as I'd documented it).

**CURRENT STATUS: DRAFT**

## TODO

This document needs tested max length values for names and each record type

The trailing period here is concerning:

    $ dig @localhost -p 53533 +short -t ANY abc.41424344
    abc.44434241.

As is the leading period here:

    D, [2018-07-18T13:04:18.639225 #32553] DEBUG -- : TunnelDrivers::DNS::Readers::Standard Message is for me, based on tag! abc.41424344
    D, [2018-07-18T13:04:18.639247 #32553] DEBUG -- : TunnelDrivers::DNS::Readers::Standard Decoding .41424344...


## Concept

The basic concept is: this driver starts a DNS server on port 53, using the
[Nesser](https://github.com/iagox86/nesser) library.

Data enters via a DNS request, encoded into the requested name.

The data is decoded and send to a "sink", which is how the data is processed and
how the response (if any) is generated.

The outgoing data is encoded as whatever record type was requested (or any of
them if ANY was the requested type), and returned.

Repeat on a timer.

## Protocol

This protocol is essentially layer 2 - it's simply data on the wire.

There are no guarantees that data will arrive, will be acknowledged, or won't
be duplicated (DNS lovvvvves duplicating data).

If guarantees are needed - which is generally the case - a higher level
protocol is required (which is where
[dnscat2-core](https://github.com/iagox86/dnscat2-core) comes into play).

### Encoding

Encoding is required throughout, as this protocol is designed to transport
binary data via a limited character set (frequently, DNS names). The client and
server are both required to encode names in most cases. The current options for
encoding are hex and base32.

Due to space and character set limitations, the only reasonable way to select
between the different encoding schemes is simple pre-agreement: the client
and server select the one they wish to use beforehand. The official
implementation herein supports both, but clients may choose to use one or the
other.

I strongly recommend using base32, simply because it is more efficient, and
somewhat less obvious "on the wire", in part due to old versions of dnscat2
exclusively using hex, and in part due to hex-encoded ASCII being fairly common
knowledge at this point.

Encoding in hex is simple: the data is simply converted to ASCII. The
characters are `0`-`9` and `a`-`f`. Case MUST be ignored (as some intermediate
DNS servers change case), and periods MUST be ignored as well (they'll be
discussed later).

Any packet that contains an odd number of characters, or characters that are
not in the correct character set (not counting the tag or domain, discussed
later), can be handled however the implementation chooses. That being said,
dropping messages is bad on DNS, since it will cause a ton of chatter, so
responding with an error packet (such as ServFail or NXDomain) is likely the
best option.

Encoding in base32 is a little more involved, since there isn't a neat
translation. The data is encoded as outlined
[here](https://tools.ietf.org/html/rfc4648), and can be tested in the browser
[on this page](https://emn178.github.io/online-tools/base32_encode.html).

Once again, due to the nature of DNS, case MUST be ignored. Additionally, the
padding symbols (`=` signs) are removed in transit, and re-added (or ignored)
during decoding. If re-adding `=` signs, zero or more are appended to make the
data's length is a multiple of 8 charcters.

### Names

Names are a special case, because they must conform to DNS naming standards,
which states, in brief:
* Names are made up of period-separated segments (eg, `"a.b.c"`), where each
  segment is at least 1 byte and no more than 63 bytes long
* All text is case insensitive, and can randomly change in transit
* The set of allowed characters are `a-z`, `0-9`, and `-`, though a domain
  cannot start with `-` (for simplicity, we don't use `-` for anything)

For the purposes of transporting data, the tunnel protocol allows periods to be
sprinkled throughout a name as desired, within the parameters of DNS outlined
above, and MUST be ignored by the recipient. `414141.example.org` is
functionally identical to `4.1.414.1.example.org`, for example.

To confirm to the tunnel protocol, a `tag` must be prepended, or a `domain`
appended. One or the other MUST be present, but both MAY NOT be.

A `tag` is a pre-arranged value that is prepended, such as `abc.<data>`. It is
designed to uniquely identify traffic as tunnel traffic. Traditionally, dnscat2
uses `dnscat` as the tag, and will likely continue to. But the protocol itself
can use any pre-arranged tag.

Since there's no valid domain name involved, messages with a tag (rather than a
domain) are not DNS-routable names. Therefore, they will not traverse the DNS
hierarchy, and are only to be used for direct "connections".

I find it helpful to use a hardcoded tag by default, unless a domain name is
specifically requested. That way, it "just works" if no configuration is done!

A `domain` is likewise a pre-arranged value, but in this case it is appended,
and is further used to route the message through the real DNS hierarchy. A
domain name such as "example.org" is appended. In theory, the server should be
running on the authoritative DNS server for that domain, but it will still work
with a direct connection the same way as a tag.

The overall length for a name cannot exceed 253 bytes, including tag/domain and
the periods. When that is made into a DNS message, it's actually 255 bytes
(there is, in a sense, a leading and trailing period we don't see - a length
prefix and a null terminator).

To summarize: data is encoded in a pre-agreed-upon format (hex or base32).
Periods are added by the encoder with at least 1 character between and at most
63 characters between. They are to be removed/ignored by the decoder. A tag is
prepended or a domain is appended. And that's that!

These are used in all requests (questions), and in some types of responses
(answers) - specifically, `CNAME`, `NS`, and `MX`, as we'll see shortly.

### Client -> server (requests)

To deliver data from a client to the server, a DNS packet MUST be sent with the
data encoded into it.

The DNS should be a standard DNS packet (RFC1035), with a single `question`
record. A question has a `name`, `type`, and `class`.

The `name` MUST be the outgoing data, encoded as discussed above. The name MUST
either start with a tag or end with a domain. Sending zero bytes of data (ie,
just the tag or domain) is absolutely possible. But caching can become an issue
(see below for discussion on caching).

The `type` can be one of the following DNS types: `A`, `AAAA`, `CNAME`, `NS`,
`MX`, or `TXT`. Additionally, it can also be `ANY`. The server's response will
be in the requested type (see below).

The `class` MUST be `IN` (`0x0001`), which is the only supported class.

### Server -> client (responses)

The server MUST respond to every client request in some way - even if it is
simply with a DNS error.

Responses are sent as a standard DNS response. Like any DNS response, the
transaction id field MUST match the request, the question field MUST match the
requests question field, the `R` flag MUST be set, and so on.

The data is encoded into the answer record(s), in accordance with the type
that the question requested: `A`, `AAAA`, `CNAME`, `NS`, `MX`, or `TXT`. If the
request was for `ANY` type, it's up to the server which type to use (in general,
it's nice to randomize it or use round-robin).

A server SHOULD endeavour to support every type listed here. A client MAY
support any one or more types, since the client can choose which record type
they want to use.

The actual encoding of the data varies based on the record type.

#### `TXT` records

A `TXT` response consists of a single `TXT` record, with encoded data.

In general, a `TXT` record is pretty much free-form: you specify binary data in
whatever format or structure you want. But, there's a problem: some libraries
don't handle NUL bytes (`\x00`) very well (I'm looking at you, Windows!). As a
result, if we want to be compatible with OS resolvers (we do), we unfortunately
have to encode the data.

A `TXT` response is simply encoded as either hex or base32, as agreed upon.
Otherwise, the data is stuck into a standard TXT packet (which also has a length
prefix).

#### `CNAME` and `NS` records

A `CNAME` or `NS` response encodes a single record of the requested type, with
a name encoded exactly like a request name, including tag or domain.

#### `MX` record

An `MX` record is essentially the same as `CNAME`/`NS` - the name is encoded
into the `exchange` field as a typical name.

The `MX` record type also defines a `preference` field, which can have any
random value (the client MUST ignore it). I randomize it between
`[10, 20, 30, 40, 50]`, because those are realistic values, but the client MUST
ignore/discard that value.

#### `A` and `AAAA` records

Data encoded into `A` or `AAAA` records are split across as many records as
desired (that fit into a DNS packet), with bits of data and sequence numbers in
each.

There are several challenges with using these record types. For example, from
experimentation, I found out (the hard way) that records can be rearranged in
transit, so each field MUST contain a sequence number. Additionally, because
data may not be a length that's a multiple of the field length, a length prefix
is also required.

To overcome these problems, the first octet in each record is a sequence number.
The actual values don't matter, as long as each one is larger than the previous
(so `1, 2, 3, 4, ...` is as valid as `1, 15, 20, 33, 100, 101, ...`).

Additionally, the second octet in the first record is the total length (in
bytes) of the data being transferred.

Finally, the last addresses is padded out to the full address length with
any value to make up a full address (I use `\xFF`). The client MUST discard that
value.

Otherwise, the data is encoded (byte by byte) into addresses: either IPv4 or
IPv6 addresses.

Let's look at encoding `"ABCDEFGHI"` in IPv4:
* `0.9.65.66` - `0` is the sequence number, and `9` is the length. `65` and `66`
  are the first two bytes of data
* `1.67.68.69` - `1` is the sequence number, followed by three bytes of data
* `2.70.71.72` - `2` is the sequence number, followed by more data
* `3.73.255.255` - `3` is the sequence number, `73` is the last byte of data,
  and `255.255` are padding

Now let's encode the full alphabet - `"ABCDEFGHIJKLMNOPQRSTUVWXYZ"` - as IPv6:
* `001a:4142:4344:4546:4748:494a:4b4c:4d4e` - The sequence number is `00` (keep
  in mind that leading zeroes aren't normally printed), `1a` is the length, and
  the remainder of the address is data
* `14f:5051:5253:5455:5657:5859:5aff:ffff` - The sequence number is `11`, the
  values from `4f` to `5a` are data, and the `ff:ffff` at the end is padding.

#### Errors

If an error occurs, it is still important to respond in one way or another.
Otherwise, the DNS infrastructure gets angry and will retransmit like crazy.
A higher level protocol MAY re-define how errors are transmitted and handled,
but if an error reaches this library, it will respond with either an `NXDomain`
("name not found") for a "normal" error (one that we generated), or `ServFail`
("server error") for anything else.

### Other notes

#### Caching

Caching is a huge problem! If the client sends the same request more than once,
the server most likely will NOT see the second request. This problem is not
solved at this protocol layer, but higher level protocols SHOULD endeavour to
handle this, if it is an issue.

A typical solution is to include random data or sequence number in the protocol.

#### Retransmission

DNS does a ton of duplication and gratuitous retransmission. As such, you will
almost certainly see duplicate packets arrive.

Again, this is NOT solved at this protocol layer, and SHOULD be solved at higher
level layers, if this is a problem.

#### Packets without a tag/domain

If a packet is received with no tag nor domain, that means it likely isn't
destined for us. The Internet is full of random DNS traffic.

The packet's data SHOULD be ignored; however, it is necessary to respond to the
packet. Otherwise, retransmissions and such will become noisy.

This can be handled in at least two clean ways:
* Respond with an error, such as `NXDomain`; or
* Forward the request to a "real" DNS server - a "passthrough"

Currently, this library only supports the former, but may eventually support the
latter. The protocol is agnostic, since the data is ignored anyways.

## Basic usage

Add this line to your application's Gemfile:

```ruby
gem 'dnscat2-tunneldrivers-dns'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install dnscat2-tunneldrivers-dns


And import using:

    require 'tunnel-drivers-dns'

## Detailed usage

### Initialization

The driver is initialized with the following:

    driver = Dnscat2::TunnelDrivers::DNS::Driver.new(
      host:
      port:
      passthrough:
    )

The main parameters are:
* `host` is the host to listen on (`127.0.0.1`, `0.0.0.0`, etc)
* `port` is the port to listen on (`53` is a nice choice)
* `passthrough` is an upstream server (`"ip:port"`) to send unrecognized DNS
  requests to, for stealth reasons. `nil` means that unhandled requests will
  respond with a DNS error.

As soon as the class is created, a DNS server starts up and will listen for
requests. Any requests that come in before a sink is added will respond with an
error (or pass the request upstream, if that's set).

After that, add one or more domains or tags. There are a number of functions for
doing this, most of which are convenience functions, but they all come down to
a function like `add_sink` or `add_sinks`. Those call `add_domain` or `add_tag`,
based on the domains and tags you pass as arguments.

The arguments you'll need are:
* `domain` or `tag` (or `domains`/`tags`): a string or list of strings that this
  particular sink will handle
* `sink`: An implementation of a "sink" class (see below)
* `encoder` is the encoder to use, as a string - either `"hex"` or "`base32`"

The sinks can also be removed, with `remove_domain` and `remove_tag`.

And finally, `kill` stops the DNS server and removes all sinks.

### Sink

The sink, which I also call a controller, is a class that implements, at a
minimum, a single method: `feed(data:, max_length:)`.

When data arrives over DNS, the data is sent to `feed()` via the `data:`
argument. The `max_length:` argument tells the controller the maximum amount of
data the protocol can handle right now (it can and will vary between calls, so
it MUST NOT be stored). It's expected to return between `0` and `max_length:`
bytes of binary data, or `nil`.

Any error raised is caught, and transmitted back to the client as an error
condition (`NXDomain` or `ServFail`). That's the best way to handle any kind of
error condition at this level of the protocol (in theory, higher level
protocols should have their own error handling mechanism).

### Errors

Any errors that occur, such as calling `kill()` in the wrong state, will raise
a `Dnscat2::TunnelDrivers::DNS::Exception`.

### Wait

If the DNS driver is the only thing going on, you can wait for it to finish
by using the `wait()` method. It is essentially the same as using `join()` on
the thread.

### Logging

Logging uses the [SingLogger](https://github.com/iagox86/singlogger) (Singleton
Logger) library I wrote. If you want to change the sink for the logger, be sure
to initialize it in your script before including any driver files.

The log level can be changed any time.

## Examples

### dns-echo

[dns-echo](examples/dns-echo.rb) is a simple script that simply echoes back the
data that it receives. A few transformations are also supported - `--upcase`,
`--downcase`, `--reverse`, and `--rot13` will transform the data in that way
before returning it.

Example of running it:

    $ ruby examples/dns-echo.rb --tags 'abc' --port=53535 --reverse
    D, [2018-07-18T12:59:47.256988 #31816] DEBUG -- : TunnelDrivers::DNS New instance! tags = ["abc"], domains = , sink = #<Controller:0x000000000203f348>, host = 0.0.0.0, port = 53533
    I, [2018-07-18T12:59:47.257260 #31816]  INFO -- : TunnelDrivers::DNS Starting DNS tunnel!

Then making a request, the data must be encoded. If not specified, the default
encoder is hex:

    $ dig @localhost -p 53533 +short abc.41424344
    0.4.68.67
    1.66.65.255

Note that it responds as an A record by default (it's `dig`'s default, not
ours). The data is `68 67 66 65` in decimal, which is `44434241` in hex.

We can also get a CNAME or TXT record, for example:

    $ dig @localhost -p 53533 +short -t CNAME abc.41424344
    abc.44434241.
    
    $ dig @localhost -p 53533 +short -t TXT abc.41424344
    "44434241"

Or ANY:

    $ dig @localhost -p 53533 +short -t ANY abc.41424344
    0.4.68.67
    1.66.65.255
    
    $ dig @localhost -p 53533 +short -t ANY abc.41424344
    
    50 abc.44434241.
    $ dig @localhost -p 53533 +short -t ANY abc.41424344
    abc.44434241.
    
    $ dig @localhost -p 53533 +short -t ANY abc.41424344
    abc.44434241.
    
    $ dig @localhost -p 53533 +short -t ANY abc.41424344
    0.4.68.67
    1.66.65.255

### dns-discard

[dns-discard](examples/dns-discard.rb) simply accepts a request, and returns
nothing. Depending on arguments, that nothing can be a blank message or an
error. Different options let you test different error-handling code (such as by
raising different kinds of exceptions).

### dns-chargen

[dns-chargen](examples/dns-chargen.rb) generates a random stream of text that is
the maximum size of the packet. This makes it easy to ensure that our maximum
size works and can make it through real DNS servers.

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/iagox86/dnscat2-tunneldrivers-dns
