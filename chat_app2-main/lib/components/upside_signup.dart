import 'package:flutter/material.dart';

class Upside extends StatelessWidget {
  final String imgUrl;

  const Upside({Key? key, required this.imgUrl}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Stack(
      children: [
        Container(
          width: size.width,
          height: size.height / 2,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/images/background_login.jpeg"),
              fit: BoxFit.cover,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Image.asset(
              imgUrl,
              alignment: Alignment.topCenter,
              scale: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
