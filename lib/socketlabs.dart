import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

/// This is your main entry point. You'll probably want to create __one__
/// instance of this class and keep a reference for all further requests.
class SocketLabsClient {
  final _log = Logger('SocketLabsClient');
  final Uri apiUrl;
  final String serverId;
  final String apiKey;

  final http.Client httpClient;

  /// You get the [serverId] and the [apiKey] from SocketLabs when you sign up
  /// to their service.
  /// The [apiUrl] should not be changed normally, unless you have a separate
  /// instance.
  SocketLabsClient({
    required this.serverId,
    required this.apiKey,
    String apiUrl = 'https://inject.socketlabs.com/api/v1',
    @visibleForTesting http.Client? httpClient,
  })  : httpClient = httpClient ?? http.Client(),
        apiUrl = Uri.parse(apiUrl);

  /// Sends the [messages] to the `SocketLabs` API.
  ///
  /// See [BasicMessage] on how to build a message.
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

/// Use [BasicMessage] to build a message.
abstract class Message {
  Map<String, dynamic> toJson();
}

/// This library only supports the [BasicMessage] for now, but you can build
/// everything with it.
/// Refer to the [docs](https://www.socketlabs.com/docs/) for more info.
class BasicMessage extends Message {
  final to = <Email>[];
  final Email from;
  final String subject;

  Email? replyTo;
  String? textBody;
  String? htmlBody;
  String? ampBody;
  String? apiTemplate;
  String? messageId;
  String? mailingId;
  String? charset;
  MergeData? mergeData;

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

  BasicMessage({
    required this.from,
    required this.subject,
  });
}

class Email {
  final String address;
  final String? friendlyName;

  Email(this.address, [this.friendlyName]);

  Map<String, String> toJson() => {
        'EmailAddress': address,
        if (friendlyName != null) 'FriendlyName': friendlyName!,
      };
}

class MergeData {
  final perMessage = <List<KeyPair>>[];
  final global = <KeyPair>[];

  MergeData();

  Map<String, dynamic> toJson() => {
        'PerMessage': perMessage
            .map((list) => list.map((pair) => pair.toJson()).toList())
            .toList(),
        'Global': global.map((pair) => pair.toJson()).toList(),
      };
}

class KeyPair {
  final String field;
  final String value;

  KeyPair(this.field, this.value);

  Map<String, dynamic> toJson() => {'Field': field, 'Value': value};
}

class SocketLabsException implements Exception {
  final String code;
  final String originalResponse;

  SocketLabsException(this.code, this.originalResponse);

  @override
  String toString() => 'SocketLabsException: $code';
}
