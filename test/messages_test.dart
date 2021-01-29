import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:socketlabs/socketlabs.dart';
import 'package:test/test.dart';

class MockClient extends Mock implements http.Client {}

class MockResponse extends Mock implements http.Response {}

void main() {
  group('SocketLabs', () {
    group('.send()', () {
      late http.Client httpClient;
      late SocketLabsClient socketLabs;
      setUp(() {
        httpClient = MockClient();
        socketLabs = SocketLabsClient(
          serverId: 'server-id',
          apiKey: 'api-key',
          httpClient: httpClient,
        );
      });
      test('creates a valid http request', () async {
        final response = MockResponse();

        when(response).calls(#body).thenReturn('{"ErrorCode":"Success"}');
        when(httpClient).calls(#post).withArgs(positional: [
          any
        ], named: {
          #headers: any,
          #body: any
        }).thenReturn(Future.value(response));
        final message =
            BasicMessage(from: Email('from@test'), subject: 'Subject');

        message
          ..to.addAll([
            Email('to1@email'),
            Email('to2@email', 'Mr. Two'),
          ])
          ..textBody = 'TEXT';
        await socketLabs.send([message]);

        verify(httpClient).called(#post).withArgs(
          positional: [Uri.parse('https://inject.socketlabs.com/api/v1/email')],
          named: {
            #headers: {'Content-Type': 'application/json'},
            #body:
                '{"ServerId":"server-id","ApiKey":"api-key","Messages":[{"To":[{"EmailAddress":"to1@email"},{"EmailAddress":"to2@email","FriendlyName":"Mr. Two"}],"Subject":"Subject","From":{"EmailAddress":"from@test"},"TextBody":"TEXT"}]}'
          },
        ).once();
      });

      test('properly handles error codes', () async {
        final response = MockResponse();
        final json =
            '{"ErrorCode":"Warning","MessageResults":[{"Index":0,"ErrorCode":"InvalidFromAddress","AddressResults":null}],"TransactionReceipt":null}';
        when(response).calls(#body).thenReturn(json);

        when(httpClient).calls(#post).withArgs(positional: [
          any
        ], named: {
          #headers: any,
          #body: any
        }).thenReturn(Future.value(response));
        final message =
            BasicMessage(from: Email('from@test'), subject: 'Subject');

        expect(
            socketLabs.send([message]),
            throwsA(allOf([
              isA<SocketLabsException>()
                  .having((e) => e.code, 'code', 'Warning'),
              isA<SocketLabsException>()
                  .having((e) => e.originalResponse, 'originalResponse', json),
            ])));
      });
      test('properly handles invalid json response', () async {
        final response = MockResponse();
        when(response).calls(#body).thenReturn(('Invalid Json'));

        when(httpClient).calls(#post).withArgs(positional: [
          any
        ], named: {
          #headers: any,
          #body: any
        }).thenReturn(Future.value(response));
        final message =
            BasicMessage(from: Email('from@test'), subject: 'Subject');

        expect(
            socketLabs.send([message]),
            throwsA(allOf([
              isA<SocketLabsException>()
                  .having((e) => e.code, 'code', 'InvalidResponse'),
              isA<SocketLabsException>().having((e) => e.originalResponse,
                  'originalResponse', 'Invalid Json'),
            ])));
      });
    });
    group('BasicMessage', () {
      test('properly converts to json', () {
        final message =
            BasicMessage(from: Email('from@test'), subject: 'Subject');

        message
          ..to.addAll([
            Email('to1@email'),
            Email('to2@email', 'Mr. Two'),
          ])
          ..replyTo = Email('reply@to')
          ..textBody = 'TEXT'
          ..htmlBody = '<html>TEXT</html>'
          ..ampBody = '<html>AMP</html>'
          ..apiTemplate = '3'
          ..messageId = 'MSG_ID'
          ..mailingId = 'MAILING_ID'
          ..charset = 'utf-8'
          ..mergeData = (MergeData()
            ..global.add(KeyPair('gkey', 'kvalue'))
            ..perMessage.addAll([
              [KeyPair('pmkey', 'pmvalue1'), KeyPair('pmkey2', 'pmvalue1')],
              [KeyPair('pmkey', 'pmvalue2')],
            ]));

        expect(message.toJson(), {
          'To': [
            {'EmailAddress': 'to1@email'},
            {'EmailAddress': 'to2@email', 'FriendlyName': 'Mr. Two'}
          ],
          'Subject': 'Subject',
          'From': {'EmailAddress': 'from@test'},
          'ReplyTo': {'EmailAddress': 'reply@to'},
          'TextBody': 'TEXT',
          'HtmlBody': '<html>TEXT</html>',
          'AmpBody': '<html>AMP</html>',
          'ApiTemplate': '3',
          'MessageId': 'MSG_ID',
          'MailingId': 'MAILING_ID',
          'Charset': 'utf-8',
          'MergeData': {
            'PerMessage': [
              [
                {'Field': 'pmkey', 'Value': 'pmvalue1'},
                {'Field': 'pmkey2', 'Value': 'pmvalue1'}
              ],
              [
                {'Field': 'pmkey', 'Value': 'pmvalue2'}
              ]
            ],
            'Global': [
              {'Field': 'gkey', 'Value': 'kvalue'}
            ]
          }
        });

        // Making sure it encodes properly
        jsonEncode(message.toJson());
      });
    });
  });
}
