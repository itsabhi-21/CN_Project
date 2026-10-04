# Viva preparation

Answer these out loud without notes. Each answer should reference something you can *show* in this project.

## DNS

**What happens when I type `app.team1.test`?** The OS resolver checks its cache; on a miss it sends a UDP query (random ephemeral port → 53) to the configured server, Mac 1. dnsmasq finds the name in our hosts file and answers with Mac 2's IP and TTL 30. Only then does the browser open a TCP connection to that IP.

**Why `.test` and not `.local`?** `.test` is reserved (RFC 2606/6761) for testing and will never exist on the internet. `.local` is used by multicast DNS (Bonjour); macOS would send those lookups to mDNS instead of our server.

**DNS resolution vs connection?** DNS returns an address and is done; it carries none of the application traffic. Proof: failure demo 2 — DNS succeeds with a wrong IP and the connection fails.

**What is TTL?** How long a resolver may cache an answer. Short TTL = changes take effect quickly but more queries; long TTL = less load, slower changes.

**Why UDP for DNS?** Small request/response, no handshake cost. DNS falls back to TCP for large responses (truncated flag) and zone transfers.

**Why does `dig` show the new IP while `curl` still uses the old one?** `dig` talks straight to the DNS server and ignores the OS cache; `curl` uses the OS resolver (mDNSResponder), which keeps the cached answer until TTL expires.

**Recursive vs authoritative?** Our dnsmasq is authoritative for `team1.test` (it is the source of truth, `local=/team1.test/`) and acts as a forwarder for everything else.

## TCP / transport

**Three-way handshake?** SYN (client picks initial sequence number) → SYN-ACK (server's ISN, acks client ISN+1) → ACK. It synchronises sequence numbers on both sides before any data.

**Socket pair?** (client IP, client ephemeral port, server IP, server port) — e.g. 192.168.1.14:53122 ↔ 192.168.1.12:443. It uniquely identifies one TCP connection; that's how many browser tabs share port 443.

**How does TCP make delivery reliable?** Sequence numbers count bytes; the receiver acknowledges the next expected byte; missing data is retransmitted after a timeout or duplicate ACKs; the receive window (flow control) stops a fast sender from overrunning the receiver.

**Connection refused vs timeout?** Refused = host replied with RST (reachable, nothing listening). Timeout = no reply (host down, or a firewall dropping — our pf `block drop`).

**Ephemeral vs well-known ports?** Servers listen on fixed known ports (53, 443, 3001); clients get a temporary high port from the OS (macOS range 49152–65535).

## TLS

**Handshake steps (TLS 1.2)?** ClientHello (versions, ciphers, random, SNI) → ServerHello (chosen cipher, random) → Certificate → ServerKeyExchange → ServerHelloDone → ClientKeyExchange → ChangeCipherSpec → Finished (both sides). TLS 1.3 shortens to one round trip, and encrypts everything after ServerHello — which is why our 1.3 capture doesn't show the certificate.

**How does the client trust our certificate?** The server cert is signed by our team CA; we installed the CA in each client's trust store. The client checks: signature chain to a trusted root, validity dates, and that the requested name is in the SAN.

**What is TLS termination?** TLS ends at nginx. nginx decrypts, reads the HTTP request to choose a backend, and forwards plain HTTP over the LAN. Benefits: one place for certificates, backends stay simple, the LB can see paths/headers. Trade-off: the LAN hop is unencrypted (fine in a trusted network; otherwise re-encrypt to backends).

**What is SNI?** Server Name Indication — the hostname sent in plaintext in ClientHello so the server can choose the right certificate before encryption starts.

**Why `-k` is not allowed?** It disables verification, so a man-in-the-middle could impersonate the server. `--cacert` keeps verification on, just with an explicit trust anchor.

## HTTP, REST, caching

**HTTP/1.1 vs HTTP/2 vs HTTP/3?** 1.1: text, one outstanding request per connection (head-of-line blocking). 2: binary frames, multiplexed streams over one TCP connection, header compression (HPACK), negotiated via ALPN in TLS. 3: runs over QUIC on UDP, removing TCP head-of-line blocking (explanation only).

**What makes our API REST?** Resources identified by URLs (`/api/status`), standard methods (GET), stateless requests, representations in JSON, cacheability declared by headers.

**Fresh hit vs conditional vs full request?** Fresh hit: within `max-age`, the browser uses its copy, no network. Conditional: after expiry it asks `If-None-Match: <etag>`; unchanged → 304 with no body. Full: no copy or changed → 200 with body.

**What is an ETag?** A version identifier of a resource. Ours is a hash of the content, identical on both backends.

**How does this relate to CDNs?** A CDN edge is a cache close to users obeying these same headers, so most requests never reach the origin.

## Load balancing & resilience

**Round robin vs least_conn?** Round robin rotates through servers in order. least_conn picks the server with fewest active connections — better when requests vary in duration.

**How does nginx detect a dead backend?** Passively: a connection error/timeout counts as a failure; after `max_fails` within `fail_timeout` the server is skipped for `fail_timeout` seconds. `proxy_next_upstream` retries the failed request on the other server so the client sees 200.

**Why 502 when both backends are down?** The client's connection to nginx works (DNS, TCP, TLS all fine), but nginx can't get a response from any upstream: "Bad Gateway" means the gateway itself is fine, what's behind it isn't.

**Single point of failure?** The edge, Mac 2. Remedies: second edge plus a floating VIP (VRRP/keepalived), DNS failover with health checks, or a managed cloud LB spread across availability zones.

**Why restrict backend ports?** Defence in depth: clients must pass through the edge, where TLS, logging, rate-limits live. Equivalent to a security group allowing only the LB's security group.

**DNS failure vs application failure?** DNS failure: no IP, no connection ever attempted ("could not resolve host"). App failure: name resolves, TCP/TLS succeed, the HTTP status shows the error (502).

## Network basics

**IP vs MAC address?** IP is a logical, routable (layer 3) address; MAC is the hardware (layer 2) address used within the local link. ARP maps one to the other on the LAN.

**Subnet mask /24?** First 24 bits identify the network, so 192.168.1.0–255 are local and reached directly; anything else goes to the default gateway.

**Why can a client reach an IP but not resolve a name?** Different systems — routing gets packets to the IP; DNS is a separate application-layer lookup (failure demo 1).

**Email protocols (explanation only)?** SMTP (25/587) sends and relays mail between servers; IMAP (993) syncs mailboxes on the server; POP3 (995) downloads and typically deletes. MX records in DNS tell senders which server accepts mail for a domain.

**Cloud mapping?** dnsmasq ↔ Route 53 private hosted zone; nginx ↔ ALB / Cloud Load Balancing; backends ↔ EC2 instances in a target group; pf rules ↔ security groups; TTL-based cutover ↔ blue/green DNS migration.
