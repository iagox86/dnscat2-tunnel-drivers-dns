# Dnscat2::Tunneldrivers::Dns

This is a "tunnel driver" for dnscat2 (specifically, dnscat2-core).

A tunnel driver is a "driver" that sits between dnscat2 and the Internet.
Despite the project's name, a dnscat2 driver can use any protocol - TCP, UDP,
ICMP, HTTPS, etc.

This driver, in particular, implements dnscat2's namesake protocol: DNS. It
implements encoding and decoding to a number of record types, and in two
different formats: hex and base32.

This README should be considered the authoritative source for the dnscat2
DNS tunnel protocol, superseding others.

## Protocol

The basic concept is: this starts a DNS server on port 53, using the
[Nesser](https://github.com/iagox86/nesser) library. Data enters via a DNS
request, encoded into the requested name. The data is decoded and send to a
"sink", which returns the data that is to be sent out (if any). The outgoing
data is encoded as whatever record type was requested (or any of them if ANY
was the requested type), and returned.

In order to do all that, we're going to have to cover an awful lot of ground!
So let's look at those generally in order.

This protocol is essentially layer 2 - it's simply data on the wire. There are
no guarantees that data will arrive, will be acknowledged, or won't be
duplicated (DNS lovvvvves duplicating data). If guarantees are needed - which
is generally the case - a higher level protocol is required (which is where
[dnscat2-core](https://github.com/iagox86/dnscat2-core) comes into play).

### Encoding

Encoding is required throughout, as this protocol is designed to transport
binary data via a limited character set (frequently, DNS names). As discussed,
the encoding options are hex and base32.

Due to space and character set limitations, I have decided that the best way to
select between encoding schemes is simple pre-arrangement: the client and server
select the one they wish to use beforehand. The official implementation herein
supports both, but clients may choose to use one or the other.

Encoding in hex is simple: the characters are `0`-`9` and `a`-`f`. Case MUST be
ignored (as some intermediate DNS servers change case), and periods MUST be
ignored as well (they'll be discussed later). Any packet that contains an odd
number of characters, or characters that are not in the correct character
set, can be handled however the implementation chooses. That being said,
dropping messages is bad on DNS, since it will cause a ton of chatter, so
responding with an error packet (such as SERVFAIL or NXDOMAIN) is likely the
best option.

Encoding in base32 is a little more involved, since there isn't a neat 1:2
translation. The data is encoded as outlined
[here](https://tools.ietf.org/html/rfc4648), and can be tested in the browser
[on this page](https://emn178.github.io/online-tools/base32_encode.html).

Once again, due to the nature of DNS, case MUST be ignored. Additionally, the
padding symbols (`=` signs) are removed in transit, and re-added (or ignored)
during decoding.

### Names

Names are a special case, because they must conform to DNS naming standards,
which states:
* Domain names are made up of multiple segments (eg, "a.b.c"), where each
  segment is no more than 63 bytes
* All text is case insensitive
* The set of allowed characters are `a-z`, `0-9`, and `-`, though a domain
  cannot start with `-`; periods are also allowed, as a separator character,
  but are handled specially (and cannot be adjacent)

For the purposes of transporting data, during encoding periods can be sprinkled
throughout a name as desired, within the parameters of DNS, and MUST be ignored
by the recipient. `414141.example.org` is identical to `4.1.414.1.example.org`,
for example.

A `tag` must be prepended, or a `domain` appended. One or the other MUST be
present, but both MAY NOT be.

A `tag` is a pre-arranged value that is prepended, such as `abc.<data>`. It is
designed to uniquely identify traffic as tunnel traffic. Traditionally, dnscat2
uses `dnscat` as the tag, and will likely continue to. But the protocol itself
can use any pre-arranged tag. Since there's no valid domain name involved,
messages with a tag are not designed to traverse the DNS hierarchy, and are only
to be used for direct "connections".

I find it helpful to use a hardcoded tag by default, unless a domain name is
specifically requested. That way, it "just works" if no configuration is done!

A `domain` is likewise a pre-arranged value, but in this case it is appended,
and is further used to route the message through the real DNS hierarchy. A
domain name such as "example.org" is appended. In theory, the server should be
running on the authoritative DNS server for that domain.

The overall length for a name cannot exceed 253 bytes, including tag/domain and
the periods. When that is made into a DNS message, it's actually 255 bytes
(there is, in a sense, a leading and trailing period we don't see - a length
prefix and a null terminator).

To summarize: data is encoded in a pre-agreed-upon format (hex or base32).
Periods are added by the encoder and removed/ignored by the decoder. A tag
is prepended or a domain is appended. And that's that!

### Client -> server (requests)

To deliver data from a client to the server, a DNS packet must be sent with the
data encoded into it.

The DNS should be a standard DNS packet (RFC1035), with a single `question`
record. A question has a `name`, `type`, and `class`.

The `name` MUST be the outgoing data, encoded as discussed above. The name MUST
either start with a tag or end with a domain. Sending zero bytes of data (ie,
just the tag or domain) is absolutely possible.

The `type` can be one of the following DNS types: `A`, `AAAA`, `CNAME`, `NS`,
`MX`, or `TXT`. Additionally, it can also be `ANY`. The server's response will
be in the requested type (see below).

The `class` MUST be `IN`, or Internet, which is the only supported class.

### Server -> client (responses)

The server MUST respond to every client request in some way - even if it is
simply with a DNS error.

Outgoing responses are sent as a standard DNS response. The transaction id field
MUST match the request, the question field MUST match the requests question
field, and so on - a normal DNS response, in other words.

The data is encoded into the answer record(s), in accordance with the type
that the question requested: `A`, `AAAA`, `CNAME`, `NS`, `MX`, or `TXT`. If the
request was for `ANY` type, it's up to the server which type to use (in general,
it's nice to randomize it or use round-robin).

A server SHOULD endeavour to support every type. A client MAY support any one or
more types, since the client can choose which record type they want to use.

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
into the `exchange` field as a typical name. The `MX` record type also defined
a `preference` field, which can have any random value (the client MUST ignore
it). I randomize it between `[10, 20, 30, 40, 50]`, because those are realistic
values, but the client MUST discard that value anyways.

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
      tags:
      domains:
      sink:
      host:
      port:
      encoder:
    )

* `tags` is either nil, or an array of strings that represent valid tags (for
  example, `["abc", "def", "ghi"]`).
* `domains` is either nil, or an array of strings that represent valid domains
  (for example, `["example.org", "skullseclabs.org"]`).
* `sink` is the sink for old data, and the source for new. See the next section!
* `host` is the host to listen on (`127.0.0.1`, `0.0.0.0`, etc)
* `port` is the port to listen on (`53` is a nice choice)
* `encoder` is the encoder to use, as a string - either `"hex"` or "`base32`"

Most of the communication is done with the sink. The `start()` and `stop()`
methods are also pretty important. More information below!

### Sink

The sink, which I also call a controller, is a class that implements, at a
minimum, a single method: `feed(data:, max_length:)`.

When data arrives over DNS, the data is sent to `feed()` via the `data:`
argument. The `max_length:` argument tells the controller the maximum amount of
data the protocol can handle. It's expected to return between `0` and
`max_length:` bytes of binary data.

Any error raised is caught, and transmitted back to the client as an error
condition. That's the best way to handle any kind of error condition at this
level of the protocol (in theory, higher level protocols should have their own
error handling mechanism).

### Start and stop

The driver doesn't immediately start listening for data. Instead, it sits idle
until the `start()` method is called. At that point, it attempts to open a
socket and start listening on the prescribed port.

When everything is complete, the driver can be stopped with `stop()`, or the
script can simply be exited.

### Errors

Any errors that occur, such as calling `start()` or `stop()` in the wrong state,
will raise a `Dnscat2::TunnelDrivers::DNS::Exception`.

### Wait

If the DNS driver is the only thing going on, you can wait for it to finish
by using the `wait()` method. It is essentially the same as using `join()` on
the thread.

### Logging

Logging uses the [SingLogger](https://github.com/iagox86/singlogger) (Singleton
Logger) library I wrote. If you want to change the sink for the logger, be sure
to initialize it in your script before including any driver files.

The log level can be changed any time.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/iagox86/dnscat2-tunneldrivers-dns
