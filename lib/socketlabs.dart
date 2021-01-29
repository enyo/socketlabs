import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

/// The main class to be used to send emails.
///
/// This uses the SocketLabs Injection API to send emails. Read more about this
/// API here: https://inject.docs.socketlabs.com/v1/documentation/introduction
///
///
class SocketLabsClient {
  final _log = Logger('SocketLabsClient');
  final Uri apiUrl;
  final String serverId;
  final String apiKey;

  final http.Client httpClient;

  /// Creates the client. You should only create this once and reuse it for
  /// subsequent sends.
  SocketLabsClient({
    required this.serverId,
    required this.apiKey,
    String apiUrl = 'https://inject.socketlabs.com/api/v1',
    http.Client? httpClient,
  })  : httpClient = httpClient ?? http.Client(),
        apiUrl = Uri.parse(apiUrl);

  /// Send a list of messages. Typically you only pass one message, but all
  /// messages provided here are sent to SocketLabs in __one__ API call, so if
  /// you know that you're going to send them, it's more efficient to do it with
  /// one call.
  Future<void> send(List<Message> messages) async {
    _log.finest('Sending email.');

    final body = {
      'ServerId': serverId,
      'ApiKey': apiKey,
      'Messages': messages..map((message) => message.toJson()).toList(),
    };
    final response = await httpClient.post(
      apiUrl.replace(
          pathSegments: List.from(apiUrl.pathSegments)..add('email')),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    try {
      final responseJson = jsonDecode(response.body);
      if (responseJson['ErrorCode'] != 'Success') {
        throw SocketLabsException(responseJson['ErrorCode'], response.body);
      }
    } catch (e) {
      _log.warning('Error sending email: $e');
      _log.info(response.body);
      if (e is SocketLabsException) rethrow;
      throw SocketLabsException('InvalidResponse', response.body);
    }
  }
}

/// The base class for messages.
///
/// You're probably looking for [BasicMessage].
abstract class Message {
  /// Returns the JSON representation of this message.
  Map<String, dynamic> toJson();
}

/// An email message with all relevant data.
class BasicMessage extends Message {
  /// A list of recipients.
  final to = <Email>[];

  /// The sender (your organisation).
  final Email from;

  /// The subject of the email.
  final String subject;

  /// The `ReplyTo` header.
  Email? replyTo;

  /// The plain text body.
  String? textBody;

  /// The HTML body.
  String? htmlBody;

  /// The AMP body. See https://amp.dev/about/email/
  String? ampBody;

  /// The `SocketLabs` API template to use for this email. Use the SocketLabs
  /// "Email Designer" to create the template up front.
  ///
  /// https://inject.docs.socketlabs.com/v1/documentation/use-with-marketing-tools
  String? apiTemplate;

  /// See https://help.socketlabs.com/docs/message-mailing-ids
  String? messageId;

  /// The mailing ID.
  String? mailingId;

  /// Which character set to use. Defaults to UTF8
  String? charset;

  /// `MergeData` to be used for this email. This is mostly used in conjunction
  /// with [apiTemplate].
  MergeData? mergeData;

  BasicMessage({
    required this.from,
    required this.subject,
  });

  @override
  Map<String, dynamic> toJson() => {
        'To': to.map((email) => email.toJson()).toList(),
        'Subject': subject,
        'From': from.toJson(),
        if (replyTo != null) 'ReplyTo': replyTo!.toJson(),
        if (textBody != null) 'TextBody': textBody,
        if (htmlBody != null) 'HtmlBody': htmlBody,
        if (ampBody != null) 'AmpBody': ampBody,
        if (apiTemplate != null) 'ApiTemplate': apiTemplate,
        if (messageId != null) 'MessageId': messageId,
        if (mailingId != null) 'MailingId': mailingId,
        if (charset != null) 'Charset': charset,
        if (mergeData != null) 'MergeData': mergeData!.toJson(),
      };
}

/// A representation of an email recipient or sender.
class Email {
  /// The email address.
  final String address;

  /// The name of the recipient / sender.
  final String? friendlyName;

  /// Creates this email.
  const Email(this.address, [this.friendlyName]);

  /// JSON representation of this email.
  Map<String, String> toJson() => {
        'EmailAddress': address,
        if (friendlyName != null) 'FriendlyName': friendlyName!,
      };
}

/// Merge data used for the inline merge feature.
class MergeData {
  /// Individual merge data.
  final perMessage = <List<KeyPair>>[];

  /// Merge data used for all messages.
  final global = <KeyPair>[];

  /// Instantiate this, and then add data to the [perMessage] and [global] list.
  MergeData();

  /// Builds JSON representation.
  Map<String, dynamic> toJson() => {
        'PerMessage': perMessage
            .map((list) => list.map((pair) => pair.toJson()).toList())
            .toList(),
        'Global': global.map((pair) => pair.toJson()).toList(),
      };
}

/// A simple keypair representation used in [MergeData].
class KeyPair {
  /// Field name.
  final String field;

  /// Field value.
  final String value;

  /// Creates the keypair.
  const KeyPair(this.field, this.value);

  /// Builds JSON representation.
  Map<String, dynamic> toJson() => {'Field': field, 'Value': value};
}

/// The base class for all exceptions thrown by this library.
class SocketLabsException implements Exception {
  /// The code returned by SocketLabs.
  final String code;

  /// The original response from SocketLabs.
  final String originalResponse;

  /// Creates the exception.
  SocketLabsException(this.code, this.originalResponse);

  @override
  String toString() => 'SocketLabsException: $code';
}
