import 'package:flutter/material.dart';
import 'package:chat_app/book.dart';

class BookCard extends StatelessWidget {
  final Book card;
  final VoidCallback delete;

  const BookCard({super.key, required this.card, required this.delete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 20.0),
      child: Padding(
        padding: EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [Text("Name : "), Text(card.name)]),
            Row(children: [Text("Author : "), Text(card.author)]),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(onPressed: delete, child: Icon(Icons.delete)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
