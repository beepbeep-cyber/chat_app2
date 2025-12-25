import 'package:my_porject/configs/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:my_porject/db/log_repository.dart';
import 'package:my_porject/resources/methods.dart';

import '../models/log_model.dart';

class CallLogListContainer extends StatefulWidget {
  const CallLogListContainer({Key? key}) : super(key: key);

  @override
  State<CallLogListContainer> createState() => _CallLogListContainerState();
}

class _CallLogListContainerState extends State<CallLogListContainer> {
  getIcon(String? callStatus) {
    Icon _icon;
    double _iconSize = 18;

    switch (callStatus) {
      case 'dialled':
        _icon = Icon(
          Icons.call_made,
          size: _iconSize,
          color: AppTheme.success,
        );
        break;

      case 'missed':
        _icon = Icon(
          Icons.call_missed,
          color: AppTheme.error,
          size: _iconSize,
        );
        break;

      default:
        _icon = Icon(
          Icons.call_received,
          size: _iconSize,
          color: Colors.grey,
        );
        break;
    }

    return Container(
      margin: const EdgeInsets.only(right: 5),
      child: _icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SingleChildScrollView(
        child: FutureBuilder<dynamic>(
          future: LogRepository.getLogs(),
          builder: (context, AsyncSnapshot snapshot) {
            if(snapshot.connectionState == ConnectionState.waiting){
              return const Center(
                child: CircularProgressIndicator(),
              );
            }
            if(snapshot.hasData) {
              // List<dynamic> list = snapshot.data;
              List<dynamic> logList = snapshot.data;
              if(logList.isNotEmpty) {
                return ListView.builder(
                  padding: const EdgeInsets.all(0),
                  shrinkWrap: true,
                  reverse: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: logList.length,
                    itemBuilder: (context, i) {
                      Log _log = logList[i];
                      bool hasDialled = _log.callStatus == "dialled";
                      return GestureDetector(
                        onLongPress: () {
                          // showDialog(
                          //     context: context,
                          //     builder: (context) =>  AlertDialog(
                          //       title: const Text("Delete this log?"),
                          //       content: const Text("Are you sure to delete this log?"),
                          //       actions: <Widget>[
                          //         TextButton(
                          //             onPressed: () async {
                          //               Navigator.maybePop(context);
                          //               await LogRepository.deleteLogs(i);
                          //               if (mounted) {
                          //                 setState(() {});
                          //               }
                          //             },
                          //             child: const Text("Yes"),
                          //         ),
                          //         TextButton(
                          //           onPressed: () async {
                          //             Navigator.maybePop(context);
                          //           },
                          //           child: const Text("No"),
                          //         ),
                          //       ],
                          //     )
                          // );
                        },
                        child: Container(
                          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            leading: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                backgroundImage: hasDialled
                                    ? CachedNetworkImageProvider(_log.receiverPic!)
                                    : CachedNetworkImageProvider(_log.callerPic!),
                                radius: 24,
                              ),
                            ),
                            title: Text(
                              hasDialled ? _log.receiverName! : _log.callerName!,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  getIcon(_log.callStatus),
                                  SizedBox(width: 4),
                                  Text(
                                    formatTimestampSafe(_log.timeStamp),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.gray600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.phone,
                                color: AppTheme.accent,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                );
              }
              return Container();
            }
            return Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.call_outlined,
                      size: 64,
                      color: AppTheme.gray400,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No Call Logs',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.gray800,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Your call history will appear here',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.gray600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
