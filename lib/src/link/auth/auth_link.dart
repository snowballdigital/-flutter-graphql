import 'dart:async';

import 'package:flutter_graphql/src/link/fetch_result.dart';
import 'package:flutter_graphql/src/link/link.dart';
import 'package:flutter_graphql/src/link/operation.dart';

typedef GetToken = Future<String> Function();

class AuthLink extends Link {
  AuthLink({
    this.getToken,
  }) : super(
          request: (Operation? operation, [NextLink? forward]) {
            late StreamController<FetchResult> controller;

            Future<void> onListen() async {
              try {
                final String token = await getToken!();

                operation?.setContext(<String, Map<String, String>>{
                  'headers': <String, String>{
                    'Authorization': token
                  }
                });
              } catch (error) {
                controller.addError(error);
              }
              if (forward != null && operation != null) {
                await controller.addStream(forward(operation));
              }
              await controller.close();
            }

            controller = StreamController<FetchResult>(onListen: onListen);

            return controller.stream;
          },
        );

  GetToken? getToken;
}
