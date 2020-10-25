import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

class SocketLabsClient {
  final _log = Logger('SocketLabsClient');
  final Uri apiUrl;
  final String serverId;
  final String apiKey;

  final http.Client httpClient;

  SocketLabsClient({
    @required this.serverId,
    @required this.apiKey,
    String apiUrl = 'https://inject.socketlabs.com/api/v1',
    http.Client httpClient,
  })  : httpClient = httpClient ?? http.Client(),
        apiUrl = Uri.parse(apiUrl);

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

abstract class Message {
  Map<String, dynamic> toJson();
}

class BasicMessage extends Message {
  final to = <Email>[];
  final Email from;
  final String subject;

  Email /*?*/ replyTo;
  String /*?*/ textBody;
  String /*?*/ htmlBody;
  String /*?*/ ampBody;
  String /*?*/ messageId;
  String /*?*/ mailingId;
  String /*?*/ charset;
  MergeData /*?*/ mergeData;

  @override
  Map<String, dynamic> toJson() => {
        'To': to.map((email) => email.toJson()).toList(),
        'Subject': subject,
        'From': from.toJson(),
        if (replyTo != null) 'ReplyTo': replyTo /*!*/ .toJson(),
        if (textBody != null) 'TextBody': textBody,
        if (htmlBody != null) 'HtmlBody': htmlBody,
        if (ampBody != null) 'AmpBody': ampBody,
        if (messageId != null) 'MessageId': messageId,
        if (mailingId != null) 'MailingId': mailingId,
        if (charset != null) 'Charset': charset,
        if (mergeData != null) 'MergeData': mergeData /*!*/ .toJson(),
      };

  BasicMessage({
    @required this.from,
    @required this.subject,
  });
}

class Email {
  final String address;
  final String /*?*/ friendlyName;

  Email(this.address, [this.friendlyName]);

  Map<String, String> toJson() => {
        'EmailAddress': address,
        if (friendlyName != null) 'FriendlyName': friendlyName /*!*/,
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
