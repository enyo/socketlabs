import 'package:socketlabs/socketlabs.dart';

void main() async {
  final socketLabs = SocketLabsClient(serverId: 'server-id', apiKey: 'api-key');

  final message = BasicMessage(from: Email('from@test'), subject: 'Subject')
    ..to.add(Email('to@email.com'))
    ..textBody = 'Email Content'
    ..htmlBody = '<html><strong>Email Content</strong></html>';

  await socketLabs.send([message]);
}
