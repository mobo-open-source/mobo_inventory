import 'dart:async';
import 'dart:io';

import 'package:odoo_rpc/odoo_rpc.dart';

/// Turns whatever the server-URL check threw into a sentence that tells the
/// user what to change.
///
/// The screen used to answer nearly everything with "Unable to connect to
/// server. Please verify the server URL is correct." — which is true of a typo,
/// a DNS failure, a server that is down and, most often, an `https://` address
/// for a server that only speaks plain HTTP. Those need four different actions,
/// and the one message suggested only the first.
///
/// [scheme] is the protocol the user picked, so the advice can name the
/// opposite one rather than saying "try switching" and leaving them to work out
/// which way.
String serverUrlErrorMessage(Object error, {String? scheme}) {
  final usingHttps = scheme == null || scheme.startsWith('https');
  final otherScheme = usingHttps ? 'http://' : 'https://';
  final msg = error.toString().toLowerCase();

  // TLS first. Pointing https at a plain-HTTP port is the single most common
  // way to get here, and it arrives as a handshake failure rather than as
  // anything mentioning the protocol.
  if (error is HandshakeException || error is TlsException) {
    return usingHttps
        ? 'Secure connection failed. This server may not use HTTPS — try '
              'http:// instead.'
        : 'Secure connection failed. Try https:// instead, or contact your '
              'administrator.';
  }

  if (error is SocketException) {
    final osMessage = error.osError?.message.toLowerCase() ?? '';
    final combined = '$msg $osMessage';

    // DNS: the name never resolved, so the URL itself is wrong or the device
    // cannot reach a nameserver. Nothing about the port or protocol matters
    // yet.
    if (combined.contains('failed host lookup') ||
        combined.contains('no address associated') ||
        combined.contains('name or service not known') ||
        combined.contains('nodename nor servname')) {
      return 'Server not found. Check the address for typos — if it is a '
          'hostname, your device could not resolve it (DNS).';
    }
    if (combined.contains('connection refused')) {
      return 'Nothing is listening at that address and port. Check the port '
          'number and that the server is running.';
    }
    if (combined.contains('network is unreachable') ||
        combined.contains('no route to host')) {
      return 'No route to that server. Check your internet or VPN connection.';
    }
    if (combined.contains('connection reset')) {
      return 'The server closed the connection. If it only serves HTTP, try '
          '$otherScheme instead.';
    }
    return 'Could not reach the server. Check the address, port and your '
        'network connection.';
  }

  if (error is TimeoutException || msg.contains('timed out')) {
    return 'Connection timed out. The server may be slow, unreachable, or '
        'blocked by a firewall.';
  }

  // An Odoo server answering over the wrong scheme usually redirects rather
  // than failing outright.
  if (error is HttpException ||
      msg.contains('redirect') ||
      msg.contains(' 301') ||
      msg.contains(' 302')) {
    return 'The server redirected the request. Try $otherScheme instead.';
  }

  // HTML where JSON was expected: a login page, a proxy error page, or a
  // web server that is not Odoo at all.
  if (error is FormatException ||
      msg.contains('<html') ||
      msg.contains('<!doctype')) {
    return 'That address did not return an Odoo response. Check the URL, and '
        'whether it should be $otherScheme.';
  }

  if (error is OdooException) return _odooMessage(error, otherScheme);

  if (msg.contains('certificate')) {
    return 'The server\'s security certificate could not be verified. Try '
        'http:// if this is an internal server, or contact your administrator.';
  }

  return 'Could not connect to the server. Check the address, the port, and '
      'whether it should be $otherScheme.';
}

String _odooMessage(OdooException error, String otherScheme) {
  final message = error.message.toLowerCase();

  if (message.contains('404') || message.contains('not found')) {
    return 'The server answered, but there is no Odoo at that address. Check '
        'the URL path.';
  }
  if (message.contains('403') || message.contains('forbidden')) {
    return 'The server refused the request. It may not allow listing '
        'databases from outside.';
  }
  if (message.contains('500') || message.contains('internal server error')) {
    return 'The server hit an internal error. Please contact your '
        'administrator.';
  }
  if (message.contains('timeout') || message.contains('timed out')) {
    return 'Connection timed out. Please try again.';
  }
  if (message.contains('ssl') || message.contains('certificate')) {
    return 'Secure connection failed. Try $otherScheme instead, or contact '
        'your administrator.';
  }
  if (message.contains('connection refused') || message.contains('refused')) {
    return 'Nothing is listening at that address and port. Check the port '
        'number.';
  }
  return 'The server could not be reached. Check the address and your network '
      'connection.';
}
