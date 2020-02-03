vcl 4.1;
# Based on: https://github.com/mattiasgeniar/varnish-6.0-configuration-templates/blob/master/default.vcl

import std;
import directors;

backend server1 { # Define one backend
  .host = "localhost";    # IP or Hostname of backend
  .port = "80";           # Port Apache or whatever is listening
  .max_connections = 100; # That's it

  .probe = {
    #.url = "/"; # short easy way (GET /)
    # We prefer to only do a HEAD /
    .request =
      "HEAD / HTTP/1.1"
      "Host: localhost"
      "Connection: close"
      "User-Agent: Varnish Health Probe";

    .interval  = 5s; # check the health of each backend every 5 seconds
    .timeout   = 1s; # timing out after 1 second.
    .window    = 5;  # If 3 out of the last 5 polls succeeded the backend is considered healthy, otherwise it will be marked as sick
    .threshold = 3;
  }

  .first_byte_timeout     = 300s;   # How long to wait before we receive a first byte from our backend?
  .connect_timeout        = 5s;     # How long to wait for a backend connection?
  .between_bytes_timeout  = 2s;     # How long to wait between bytes received from our backend?
}


acl purge {
  # ACL we'll use later to allow purges
  "localhost";
  "127.0.0.1";
  "::1";
}

sub vcl_init {
  # Called when VCL is loaded, before any requests pass through it.
  # Typically used to initialize VMODs.

  new vdir = directors.round_robin();
  vdir.add_backend(server1);
}

sub vcl_recv {
  # Called at the beginning of a request, after the complete request has been received and parsed.
  # Its purpose is to decide whether or not to serve the request, how to do it, and, if applicable,
  # which backend to use.
  # also used to modify the request

  set req.backend_hint = vdir.backend(); # send all traffic to the vdir director

  # Normalize the header if it exists, remove the port (in case you're testing this on various TCP ports)
  if (req.http.Host) {
   set req.http.Host = regsub(req.http.Host, ":[0-9]+", "");
  }

  # Remove the proxy header (see https://httpoxy.org/#mitigate-varnish)
  unset req.http.proxy;

  # Normalize the query arguments
  set req.url = std.querysort(req.url);

  # Allow purging
  if (req.method == "PURGE") {
    if (!client.ip ~ purge) { # purge is the ACL defined at the begining
      # Not from an allowed IP? Then die with an error.
      return (synth(405, "This IP is not allowed to send PURGE requests."));
    }
    # If you got this stage (and didn't error out above), purge the cached result
    return (purge);
  }

  # Only deal with "normal" types
  if (req.method != "GET" &&
      req.method != "HEAD" &&
      req.method != "PUT" &&
      req.method != "POST" &&
      req.method != "TRACE" &&
      req.method != "OPTIONS" &&
      req.method != "PATCH" &&
      req.method != "DELETE") {
    /* Non-RFC2616 or CONNECT which is weird. */
    return (pipe);
  }

  # Only cache GET or HEAD requests. This makes sure the POST requests are always passed.
  if (req.method != "GET" && req.method != "HEAD") {
    return (pass);
  }

  # Strip hash, server doesn't need it.
  if (req.url ~ "\#") {
    set req.url = regsub(req.url, "\#.*$", "");
  }

  # Strip a trailing ? if it exists
  if (req.url ~ "\?$") {
    set req.url = regsub(req.url, "\?$", "");
  }

  # Remove all cookies for static files
  if (req.url ~ "^[^?]*\.(bmp|css|csv|gif|gz|ico|jpeg|jpg|js|pbf|png|rar|svg|svgz|tar|ttf|txt|xls|xlsx|xml|zip)(\?.*)?$") {
    unset req.http.Cookie;
    return (hash);
  }

  # Send Surrogate-Capability headers to announce ESI support to backend
  set req.http.Surrogate-Capability = "key=ESI/1.0";
}

# The data on which the hashing will take place
sub vcl_hash {
  # Called after vcl_recv to create a hash value for the request. This is used as a key
  # to look up the object in Varnish.

  hash_data(req.url);
}

sub vcl_hit {
  # Called when a cache lookup is successful.

  if (obj.ttl >= 0s) {
    # A pure unadultered hit, deliver it
    return (deliver);
  }
}

sub vcl_miss {
  # Called after a cache lookup if the requested document was not found in the cache. Its purpose
  # is to decide whether or not to attempt to retrieve the document from the backend, and which
  # backend to use.

  return (fetch);
}

# Handle the HTTP request coming from our backend
sub vcl_backend_response {
  # Called after the response headers has been successfully retrieved from the backend.

  # Pause ESI request and remove Surrogate-Control header
  if (beresp.http.Surrogate-Control ~ "ESI/1.0") {
    unset beresp.http.Surrogate-Control;
    set beresp.do_esi = true;
  }

  # Enable cache for all static files
  if (bereq.url ~ "^[^?]*\.(bmp|css|csv|gif|gz|ico|jpeg|jpg|js|pbf|png|rar|svg|svgz|tar|ttf|txt|xls|xlsx|xml|zip)(\?.*)?$") {
    unset beresp.http.set-cookie;

    # Large static files are delivered directly to the end-user without waiting for Varnish to fully read the file first.
    # Check memory usage it'll grow in fetch_chunksize blocks (128k by default) if the backend doesn't send a Content-Length header, so only enable it for big objects
    # set beresp.do_stream = true;
  }

  # Set 5h cache if unset for static files
  if (beresp.ttl <= 0s || beresp.http.Set-Cookie || beresp.http.Vary == "*") {
    # Important, you shouldn't rely on this, SET YOUR HEADERS in the backend
    set beresp.ttl = 5h;
    
    # Let the client ask for no-cache
    # https://varnish-cache.org/docs/5.1/users-guide/increasing-your-hitrate.html#pragma
    set beresp.uncacheable = true;
    return (deliver);
  }

  /* Set the clients TTL on this object */
  set beresp.http.cache-control = "max-age=900";

  # Don't cache 50x responses
  if (beresp.status == 500 || beresp.status == 502 || beresp.status == 503 || beresp.status == 504) {
    return (abandon);
  }

  # Allow stale content, in case the backend goes down.
  # make Varnish keep all objects for 6 hours beyond their TTL
  # set beresp.grace = 6h;

  return (deliver);
}

# The routine when we deliver the HTTP request to the user
# Last chance to modify headers that are sent to the client
sub vcl_deliver {
  # Called before a cached object is delivered to the client.

  if (obj.hits > 0) { # Add debug header to see if it's a HIT/MISS and the number of hits, disable when not needed
    set resp.http.X-Cache = "HIT";
  } else {
    set resp.http.X-Cache = "MISS";
  }

  # Please note that obj.hits behaviour changed in 4.0, now it counts per objecthead, not per object
  # and obj.hits may not be reset in some cases where bans are in use. See bug 1492 for details.
  # So take hits with a grain of salt
  set resp.http.X-Cache-Hits = obj.hits;

  # Remove some headers: Apache version & OS
  unset resp.http.Server;
  unset resp.http.X-Drupal-Cache;
  unset resp.http.X-Varnish;
  unset resp.http.Via;
  unset resp.http.Link;
  unset resp.http.X-Generator;

  return (deliver);
}

sub vcl_purge {
  # Only handle actual PURGE HTTP methods, everything else is discarded
  if (req.method != "PURGE") {
    # restart request
    set req.http.X-Purge = "Yes";
    return(restart);
  }
}

sub vcl_fini {
  # Called when VCL is discarded only after all requests have exited the VCL.
  # Typically used to clean up VMODs.

  return (ok);
}