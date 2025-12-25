import 'package:my_porject/configs/app_theme.dart';
import 'package:flutter/material.dart';

import '../widgets/call_log_list_container.dart';

class CallLogScreen extends StatefulWidget {
  const CallLogScreen({Key? key}) : super(key: key);

  @override
  State<CallLogScreen> createState() => _CallLogScreenState();
}

class _CallLogScreenState extends State<CallLogScreen> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.gray50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: 16, left: 16, bottom: 8),
            child: Text(
              'Recent Calls',
              style: TextStyle(
                color: AppTheme.gray800,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const CallLogListContainer(),
        ],
      ),
    );
  }
}
