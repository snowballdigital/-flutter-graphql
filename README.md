# GraphQL Flutter

[![version][version-badge]][package]
[![MIT License][license-badge]][license]
[![All Contributors](https://img.shields.io/badge/all_contributors-15-orange.svg?style=flat-square)](#contributors)
[![PRs Welcome][prs-badge]](http://makeapullrequest.com)

[![Watch on GitHub][github-watch-badge]][github-watch]
[![Star on GitHub][github-star-badge]][github-star]

## Table of Contents

- [GraphQL Flutter](#graphql-flutter)
  - [Table of Contents](#table-of-contents)
  - [About this project](#about-this-project)
  - [Installation](#installation)
  - [Usage](#usage)
    - [GraphQL Provider](#graphql-provider)
    - [Offline Cache](#offline-cache)
      - [Normalization](#normalization)
    - [Queries](#queries)
    - [Mutations](#mutations)
    - [Subscriptions (Experimental)](#subscriptions-experimental)
    - [Graphql Consumer](#graphql-consumer)
  - [Roadmap](#roadmap)
  - [Contributing](#contributing)
  - [New Contributors](#new-contributors)
  - [Base Contributors](#base-contributors)

## About this project

GraphQL brings many benefits, both to the client: devices will need less requests, and therefore reduce data useage. And to the programer: requests are arguable, they have the same structure as the request.

This project combines the benefits of GraphQL with the benefits of `Streams` in Dart to deliver a high performace client.

The project took inspriation from the [Apollo GraphQL client](https://github.com/apollographql/apollo-client), great work guys!

## Installation

First depend on the library by adding this to your packages `pubspec.yaml`:

```yaml
dependencies:
  flutter_graphql: ^1.0.0-alpha
```

Now inside your Dart code you can import it.

```dart
import 'package:flutter_graphql/flutter_graphql.dart';
```

## Usage

To use the client it first needs to be initialized with an link and cache. For this example we will be uing an `HttpLink` as our link and `InMemoryCache` as our cache. If your endpoint requires authentication you can provide some custom headers to `HttpLink`.

> For this example we will use the public GitHub API.

```dart
...

import 'package:flutter_graphql/flutter_graphql.dart';

void main() {
  HttpLink link = HttpLink(
    uri: 'https://api.github.com/graphql',
    headers: <String, String>{
      'Authorization': 'Bearer <YOUR_PERSONAL_ACCESS_TOKEN>',
    },
  );

  ValueNotifier<GraphQLClient> client = ValueNotifier(
    GraphQLClient(
      cache: InMemoryCache(),
      link: link,
    ),
  );

  ...
}

...
```

### GraphQL Provider

In order to use the client, you `Query` and `Mutation` widgets to be wrapped with the `GraphQLProvider` widget.

> We recommend wrapping your `MaterialApp` with the `GraphQLProvider` widget.

```dart
  ...

  return GraphQLProvider(
    client: client,
    child: MaterialApp(
      title: 'Flutter Demo',
      ...
    ),
  );

  ...
```

### Offline Cache

The in-memory cache can automatically be saved to and restored from offline storage. Setting it up is as easy as wrapping your app with the `CacheProvider` widget.

> It is required to place the `CacheProvider` widget is inside the `GraphQLProvider` widget, because `GraphQLProvider` makes client available trough the build context.

```dart
...

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GraphQLProvider(
      client: client,
      child: CacheProvider(
        child: MaterialApp(
          title: 'Flutter Demo',
          ...
        ),
      ),
    );
  }
}

...
```

#### Normalization
To enable [apollo-like normalization](https://www.apollographql.com/docs/react/advanced/caching.html#normalization), use a `NormalizedInMemoryCache`:
```dart
ValueNotifier<GraphQLClient> client = ValueNotifier(
  GraphQLClient(
    cache: NormalizedInMemoryCache(
      dataIdFromObject: typenameDataIdFromObject,
    ),
    link: link,
  ),
);
```
`dataIdFromObject` is required and has no defaults. Our implementation is similar to apollo's, requiring a function to return a universally unique string or `null`. The predefined `typenameDataIdFromObject` we provide is similar to apollo's default:
```dart
String typenameDataIdFromObject(Object object) {
  if (object is Map<String, Object> &&
      object.containsKey('__typename') &&
      object.containsKey('id')) {
    return "${object['__typename']}/${object['id']}";
  }
  return null;
}
```
However note that **`graphql-flutter` does not inject __typename into operations** the way apollo does, so if you aren't careful to request them in your query, this normalization scheme is not possible.


### Queries

Creating a query is as simple as creating a multiline string:

```dart
String readRepositories = """
  query ReadRepositories(\$nRepositories) {
    viewer {
      repositories(last: \$nRepositories) {
        nodes {
          id
          name
          viewerHasStarred
        }
      }
    }
  }
"""
    .replaceAll('\n', ' ');
```

In your widget:

```dart
...

Query(
  options: QueryOptions(
    document: readRepositories, // this is the query string you just created
    variables: {
      'nRepositories': 50,
    },
    pollInterval: 10,
  ),
  builder: (QueryResult result) {
    if (result.errors != null) {
      return Text(result.errors.toString());
    }

    if (result.loading) {
      return Text('Loading');
    }

    // it can be either Map or List
    List repositories = result.data['viewer']['repositories']['nodes'];

    return ListView.builder(
      itemCount: repositories.length,
      itemBuilder: (context, index) {
        final repository = repositories[index];

        return Text(repository['name']);
    });
  },
);

...
```

### Mutations

Again first create a mutation string:

```dart
String addStar = """
  mutation AddStar(\$starrableId: ID!) {
    addStar(input: {starrableId: \$starrableId}) {
      starrable {
        viewerHasStarred
      }
    }
  }
"""
    .replaceAll('\n', ' ');
```

The syntax for mutations is fairly similar to that of a query. The only diffence is that the first argument of the builder function is a mutation function. Just call it to trigger the mutations (Yeah we deliberately stole this from react-apollo.)

```dart
...

Mutation(
  options: MutationOptions(
    document: addStar, // this is the mutation string you just created
  ),
  builder: (
    RunMutation runMutation,
    QueryResult result,
  ) {
    return FloatingActionButton(
      onPressed: () => runMutation({
        'starrableId': <A_STARTABLE_REPOSITORY_ID>,
      }),
      tooltip: 'Star',
      child: Icon(Icons.star),
    );
  },
);

...
```

### Subscriptions (Experimental)

The syntax for subscriptions is again similar to a query, however, this utilizes WebSockets and dart Streams to provide real-time updates from a server.
Before subscriptions can be performed a global intance of `socketClient` needs to be initialized.

> We are working on moving this into the same `GraphQLProvider` stucture as the http client. Therefore this api might change in the near future.

```dart
socketClient = await SocketClient.connect('ws://coolserver.com/graphql');
```

Once the `socketClient` has been initialized it can be used by the `Subscription` `Widget`

```dart
class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Subscription(
          operationName,
          query,
          variables: variables,
          builder: ({
            bool loading,
            dynamic payload,
            dynamic error,
          }) {
            if (payload != null) {
              return Text(payload['requestSubscription']['requestData']);
            } else {
              return Text('Data not found');
            }
          }
        ),
      )
    );
  }
}
```

### Graphql Consumer

You can always access the client direcly from the `GraphQLProvider` but to make it even easier you can also use the `GraphQLConsumer` widget.

```dart
  ...

  return GraphQLConsumer(
    builder: (GraphQLClient client) {
      // do something with the client

      return Container(
        child: Text('Hello world'),
      );
    },
  );

  ...
```

## Roadmap

This is currently our roadmap, please feel free to request additions/changes.

| Feature                 | Progress |
| :---------------------- | :------: |
| Queries                 |    ✅    |
| Mutations               |    ✅    |
| Subscriptions           |    ✅    |
| Query polling           |    ✅    |
| In memory cache         |    ✅    |
| Offline cache sync      |    ✅    |
| Optimistic results      |    🔜    |
| Client state management |    🔜    |
| Modularity              |    🔜    |

## Contributing

Feel free to open a PR with any suggestions! We'll be actively working on the library ourselves.

## New Contributors

This package was originally created and published by the engineers at [Zino App BV](https://zinoapp.com). Since then the community has helped to make it even more useful for even more developers.

Thanks goes to these wonderful people ([emoji key](https://github.com/kentcdodds/all-contributors#emoji-key)):

Coming soon

## Base Contributors

This package was originally created and published by the engineers at [Zino App BV](https://zinoapp.com). Since then the community has helped to make it even more useful for even more developers.

Thanks goes to these wonderful people ([emoji key](https://github.com/kentcdodds/all-contributors#emoji-key)):

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore -->
| [<img src="https://avatars2.githubusercontent.com/u/4757453?v=4" width="100px;"/><br /><sub><b>Eustatiu Dima</b></sub>](http://eusdima.com)<br />[🐛](https://github.com/zino-app/graphql-flutter/issues?q=author%3Aeusdima "Bug reports") [💻](https://github.com/zino-app/graphql-flutter/commits?author=eusdima "Code") [📖](https://github.com/zino-app/graphql-flutter/commits?author=eusdima "Documentation") [💡](#example-eusdima "Examples") [🤔](#ideas-eusdima "Ideas, Planning, & Feedback") [👀](#review-eusdima "Reviewed Pull Requests") | [<img src="https://avatars3.githubusercontent.com/u/17142193?v=4" width="100px;"/><br /><sub><b>Zino Hofmann</b></sub>](https://github.com/HofmannZ)<br />[🐛](https://github.com/zino-app/graphql-flutter/issues?q=author%3AHofmannZ "Bug reports") [💻](https://github.com/zino-app/graphql-flutter/commits?author=HofmannZ "Code") [📖](https://github.com/zino-app/graphql-flutter/commits?author=HofmannZ "Documentation") [💡](#example-HofmannZ "Examples") [🤔](#ideas-HofmannZ "Ideas, Planning, & Feedback") [🚇](#infra-HofmannZ "Infrastructure (Hosting, Build-Tools, etc)") [👀](#review-HofmannZ "Reviewed Pull Requests") | [<img src="https://avatars2.githubusercontent.com/u/15068096?v=4" width="100px;"/><br /><sub><b>Harkirat Saluja</b></sub>](https://github.com/jinxac)<br />[📖](https://github.com/zino-app/graphql-flutter/commits?author=jinxac "Documentation") [🤔](#ideas-jinxac "Ideas, Planning, & Feedback") | [<img src="https://avatars3.githubusercontent.com/u/5178217?v=4" width="100px;"/><br /><sub><b>Chris Muthig</b></sub>](https://github.com/camuthig)<br />[💻](https://github.com/zino-app/graphql-flutter/commits?author=camuthig "Code") [📖](https://github.com/zino-app/graphql-flutter/commits?author=camuthig "Documentation") [💡](#example-camuthig "Examples") [🤔](#ideas-camuthig "Ideas, Planning, & Feedback") | [<img src="https://avatars1.githubusercontent.com/u/7611406?v=4" width="100px;"/><br /><sub><b>Cal Pratt</b></sub>](http://stackoverflow.com/users/3280538/flkes)<br />[🐛](https://github.com/zino-app/graphql-flutter/issues?q=author%3Acal-pratt "Bug reports") [💻](https://github.com/zino-app/graphql-flutter/commits?author=cal-pratt "Code") [📖](https://github.com/zino-app/graphql-flutter/commits?author=cal-pratt "Documentation") [💡](#example-cal-pratt "Examples") [🤔](#ideas-cal-pratt "Ideas, Planning, & Feedback") | [<img src="https://avatars0.githubusercontent.com/u/9830761?v=4" width="100px;"/><br /><sub><b>Miroslav Valkovic-Madjer</b></sub>](http://madjer.info)<br />[💻](https://github.com/zino-app/graphql-flutter/commits?author=mmadjer "Code") | [<img src="https://avatars2.githubusercontent.com/u/4523129?v=4" width="100px;"/><br /><sub><b>Aleksandar Faraj</b></sub>](https://github.com/AleksandarFaraj)<br />[🐛](https://github.com/zino-app/graphql-flutter/issues?q=author%3AAleksandarFaraj "Bug reports") |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| [<img src="https://avatars0.githubusercontent.com/u/403029?v=4" width="100px;"/><br /><sub><b>Arnaud Delcasse</b></sub>](https://www.scity.coop)<br />[🐛](https://github.com/zino-app/graphql-flutter/issues?q=author%3Aadelcasse "Bug reports") [💻](https://github.com/zino-app/graphql-flutter/commits?author=adelcasse "Code") | [<img src="https://avatars0.githubusercontent.com/u/959931?v=4" width="100px;"/><br /><sub><b>Dustin Graham</b></sub>](https://github.com/dustin-graham)<br />[🐛](https://github.com/zino-app/graphql-flutter/issues?q=author%3Adustin-graham "Bug reports") [💻](https://github.com/zino-app/graphql-flutter/commits?author=dustin-graham "Code") | [<img src="https://avatars3.githubusercontent.com/u/1375034?v=4" width="100px;"/><br /><sub><b>Fábio Carneiro</b></sub>](https://github.com/fabiocarneiro)<br />[🐛](https://github.com/zino-app/graphql-flutter/issues?q=author%3Afabiocarneiro "Bug reports") | [<img src="https://avatars0.githubusercontent.com/u/480546?v=4" width="100px;"/><br /><sub><b>Gregor</b></sub>](https://github.com/lordgreg)<br />[🐛](https://github.com/zino-app/graphql-flutter/issues?q=author%3Alordgreg "Bug reports") [💻](https://github.com/zino-app/graphql-flutter/commits?author=lordgreg "Code") [🤔](#ideas-lordgreg "Ideas, Planning, & Feedback") | [<img src="https://avatars1.githubusercontent.com/u/5159563?v=4" width="100px;"/><br /><sub><b>Kolja Esders</b></sub>](https://github.com/kolja-esders)<br />[🐛](https://github.com/zino-app/graphql-flutter/issues?q=author%3Akolja-esders "Bug reports") [💻](https://github.com/zino-app/graphql-flutter/commits?author=kolja-esders "Code") [🤔](#ideas-kolja-esders "Ideas, Planning, & Feedback") | [<img src="https://avatars1.githubusercontent.com/u/8343799?v=4" width="100px;"/><br /><sub><b>Michael Joseph Rosenthal</b></sub>](https://github.com/micimize)<br />[🐛](https://github.com/zino-app/graphql-flutter/issues?q=author%3Amicimize "Bug reports") [💻](https://github.com/zino-app/graphql-flutter/commits?author=micimize "Code") [📖](https://github.com/zino-app/graphql-flutter/commits?author=micimize "Documentation") [💡](#example-micimize "Examples") [🤔](#ideas-micimize "Ideas, Planning, & Feedback") [⚠️](https://github.com/zino-app/graphql-flutter/commits?author=micimize "Tests") | [<img src="https://avatars2.githubusercontent.com/u/735858?v=4" width="100px;"/><br /><sub><b>Igor Borges</b></sub>](http://borges.me/)<br />[🐛](https://github.com/zino-app/graphql-flutter/issues?q=author%3AIgor1201 "Bug reports") [💻](https://github.com/zino-app/graphql-flutter/commits?author=Igor1201 "Code") |
| [<img src="https://avatars1.githubusercontent.com/u/6992724?v=4" width="100px;"/><br /><sub><b>Rafael Ring</b></sub>](https://github.com/rafaelring)<br />[🐛](https://github.com/zino-app/graphql-flutter/issues?q=author%3Arafaelring "Bug reports") [💻](https://github.com/zino-app/graphql-flutter/commits?author=rafaelring "Code") |
<!-- ALL-CONTRIBUTORS-LIST:END -->

This project follows the [all-contributors](https://github.com/kentcdodds/all-contributors) specification. Contributions of any kind are welcome!

[version-badge]: https://img.shields.io/pub/v/flutter_graphql.svg?style=flat-square
[package]: https://pub.dartlang.org/packages/flutter_graphql/versions/1.0.0-alpha.3
[license-badge]: https://img.shields.io/github/license/zino-app/graphql-flutter.svg?style=flat-square
[license]: https://github.com/zino-app/graphql-flutter/blob/master/LICENSE
[prs-badge]: https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square
[prs]: http://makeapullrequest.com
[github-watch-badge]: https://img.shields.io/github/watchers/zino-app/graphql-flutter.svg?style=social
[github-watch]: https://github.com/zino-app/graphql-flutter/watchers
[github-star-badge]: https://img.shields.io/github/stars/zino-app/graphql-flutter.svg?style=social
[github-star]: https://github.com/zino-app/graphql-flutter/stargazers
