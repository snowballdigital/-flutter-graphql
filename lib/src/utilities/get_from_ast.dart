import 'package:collection/collection.dart' show IterableExtension;
import 'package:graphql_parser2/graphql_parser2.dart';

String? getOperationName(String rawDoc) {
  final List<Token> tokens = scan(rawDoc);
  final Parser parser = Parser(tokens);

  if (parser.errors.isNotEmpty) {
    // Handle errors...
    print(parser.errors.toString());
  }

  // Parse the GraphQL document using recursive descent
  final DocumentContext doc = parser.parseDocument();

  if (doc.definitions != null && doc.definitions.isNotEmpty) {
    final OperationDefinitionContext? definition = doc.definitions.lastWhereOrNull(
      (DefinitionContext context) => context is OperationDefinitionContext,
    ) as OperationDefinitionContext?;

    if (definition != null) {
      if (definition.name != null) {
        return definition.name;
      }
    }
  }

  return null;
}
