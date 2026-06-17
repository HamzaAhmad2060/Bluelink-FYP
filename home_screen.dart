import 'dart:math';

import '../exports.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String userName = Random().nextInt(10000).toString();
  final Strategy strategy = Strategy.P2P_STAR;
  Map<String, ConnectionInfo> endpointMap = {};
  final List<ChatMessage> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  String? tempFileUri;
  Map<int, String> map = {};
  Map<String, int> pendingFilePayloads = {};

  @override
  void initState() {
    super.initState();
    _startBluetoothChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    Nearby().stopAllEndpoints();
    super.dispose();
  }

  void _startBluetoothChat() async {
    try {
      bool advertisingStarted = await Nearby().startAdvertising(
        userName,
        strategy,
        onConnectionInitiated: _onConnectionInit,
        onConnectionResult: (id, status) {},
        onDisconnected: (id) {
          setState(() {
            endpointMap.remove(id);
          });
        },
      );

      bool discoveryStarted = await Nearby().startDiscovery(
        userName,
        strategy,
        onEndpointFound: (id, name, serviceId) {
          Nearby().requestConnection(
            userName,
            id,
            onConnectionInitiated: _onConnectionInit,
            onConnectionResult: (id, status) {},
            onDisconnected: (id) {
              setState(() {
                endpointMap.remove(id);
              });
            },
          );
        },
        onEndpointLost: (id) {},
      );
    } catch (e) {}
  }

  void _onConnectionInit(String id, ConnectionInfo info) async {
    setState(() {
      endpointMap[id] = info;
    });
    await Nearby().acceptConnection(
      id,
      onPayLoadRecieved: (endid, payload) async {
        if (payload.type == PayloadType.BYTES) {
          String str = String.fromCharCodes(payload.bytes!);
          if (str.contains(':')) {
            int payloadId = int.parse(str.split(':')[0]);
            String fileName = str.split(':')[1];
            map[payloadId] = fileName;
            if (tempFileUri != null &&
                pendingFilePayloads[endid] == payloadId) {
              tempFileUri = null;
              pendingFilePayloads.remove(endid);
            }
          } else {
            // Handle text message
            setState(() {
              _messages.add(ChatMessage(
                text: str,
                isSentByMe: false,
                senderName: endpointMap[endid]?.endpointName ?? "Unknown",
                timestamp: DateTime.now(),
              ));
            });
          }
        } else if (payload.type == PayloadType.FILE) {
          tempFileUri = payload.uri;
          pendingFilePayloads[endid] =
              payload.id ?? Random().nextInt(100000); // Store payloadId
        }
      },
      onPayloadTransferUpdate: (endid, payloadTransferUpdate) async {
        if (payloadTransferUpdate.status == PayloadStatus.SUCCESS) {
          if (tempFileUri != null &&
              map.containsKey(payloadTransferUpdate.id)) {
            String fileName = map[payloadTransferUpdate.id]!;
            // String movedFilePath = await _moveFile(tempFileUri!, fileName);
            // setState(() {
            //   _messages.add(ChatMessage(
            //     text: "Image received",
            //     imagePath: movedFilePath,
            //     isSentByMe: false,
            //     senderName: endpointMap[endid]?.endpointName ?? "Unknown",
            //     timestamp: DateTime.now(),
            //   ));
            // });
            tempFileUri = null;
            map.remove(payloadTransferUpdate.id);
            pendingFilePayloads.remove(endid);
          }
        } else if (payloadTransferUpdate.status == PayloadStatus.FAILURE) {}
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset(
              AppAssets.bgImage,
              fit: BoxFit.cover,
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 22.h),
                TextWidget(
                  text: "Bluelink",
                  color: AppColors.primaryTextColor,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                ),
                const SizedBox(height: 16),
                ChatOptionTile(
                  title: "Public Chat",
                  subtitle: "Join the public chat room",
                  icon: Icons.chat,
                  onTap: () => context.navigateWithTransition(
                      const PublicChatScreen(), TransitionType.fade),
                ),
                const Divider(),
                const SizedBox(height: 16),
                TextWidget(
                  text: "Chats",
                  color: AppColors.primaryTextColor,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                ),
                const SizedBox(height: 16),
                endpointMap.isEmpty
                    ? TextWidget(
                        text: "No chats found",
                        color: Colors.grey,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w300,
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: endpointMap.length,
                        itemBuilder: (context, index) {
                          final peerId = endpointMap.keys.elementAt(index);
                          final connectionInfo = endpointMap[peerId]!;

                          return ChatOptionTile(
                            title: connectionInfo.endpointName,
                            subtitle: "Join the public chat room",
                            icon: Icons.chat,
                            onTap: () => context.navigateWithTransition(
                                const PublicChatScreen(),
                                TransitionType.fade),
                          );
                        }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
