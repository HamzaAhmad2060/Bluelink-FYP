import 'dart:math';
import 'dart:typed_data';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../exports.dart';

class PublicChatScreen extends StatefulWidget {
  const PublicChatScreen({super.key});

  @override
  State<PublicChatScreen> createState() => _MyPublicChatScreenState();
}

class _MyPublicChatScreenState extends State<PublicChatScreen> {
  bool isAdvertising = true;
  final String userName = Random().nextInt(10000).toString();
  final Strategy strategy = Strategy.P2P_CLUSTER;
  Map<String, ConnectionInfo> endpointMap = {};
  final List<ChatMessage> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  String? tempFileUri;
  Map<int, String> map = {};
  Map<String, int> pendingFilePayloads = {};

  @override
  void initState() {
    super.initState();
    requestPermissions();
    _startBluetoothChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    requestPermissions();
    Nearby().stopAllEndpoints();
    super.dispose();
  }

  Future<bool> requestPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.nearbyWifiDevices,
      Permission.location, // If location is needed
    ].request();
    return statuses.values.every((status) => status.isGranted);
  }

  void _startBluetoothChat() async {
    try {
      bool advertisingStarted = await Nearby().startAdvertising(
        userName,
        strategy,
        onConnectionInitiated: _onConnectionInit,
        onConnectionResult: (id, status) {
          showSnackbar("Connection $status with $id");
        },
        onDisconnected: (id) {
          showSnackbar("Disconnected: ${endpointMap[id]?.endpointName}, id $id");
          setState(() {
            endpointMap.remove(id);
          });
        },
      );
      showSnackbar("Advertising: $advertisingStarted");

      bool discoveryStarted = await Nearby().startDiscovery(
        userName,
        strategy,
        onEndpointFound: (id, name, serviceId) {
          Nearby().requestConnection(
            userName,
            id,
            onConnectionInitiated: _onConnectionInit,
            onConnectionResult: (id, status) {
              showSnackbar("Connection $status with $id");
            },
            onDisconnected: (id) {
              showSnackbar("Disconnected: ${endpointMap[id]?.endpointName}, id $id");
              setState(() {
                endpointMap.remove(id);
              });
            },
          );
        },
        onEndpointLost: (id) {
          showSnackbar("Lost endpoint: ${endpointMap[id]?.endpointName}, id $id");
        },
      );
      showSnackbar("Discovery: $discoveryStarted");
      setState(() {
        isAdvertising = false;
      });
    } catch (e) {
      setState(() {
        isAdvertising = false;
      });
      showSnackbar("Error: $e");
    }
  }

  void _onConnectionInit(String id, ConnectionInfo info) async {
    if (!endpointMap.containsKey(id)) {
      setState(() {
        endpointMap[id] = info;
      });
      await Nearby().acceptConnection(id, onPayLoadRecieved: (endid, payload) async {
        if (payload.type == PayloadType.BYTES) {
          String str = String.fromCharCodes(payload.bytes!);
          if (str.contains(':')) {
            int payloadId = int.parse(str.split(':')[0]);
            String fileName = str.split(':')[1];
            map[payloadId] = fileName;
            if (tempFileUri != null && pendingFilePayloads[endid] == payloadId) {
              showSnackbar("Metadata received for payloadId: $payloadId");
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
          pendingFilePayloads[endid] = payload.id ?? Random().nextInt(100000);
          showSnackbar("File transfer started from $endid");
        }
      }, onPayloadTransferUpdate: (endid, payloadTransferUpdate) async {
        if (payloadTransferUpdate.status == PayloadStatus.SUCCESS) {
          showSnackbar("Transfer from $endid successful");
          if (tempFileUri != null && map.containsKey(payloadTransferUpdate.id)) {
            String fileName = map[payloadTransferUpdate.id]!;
            String movedFilePath = await _moveFile(tempFileUri!, fileName);
            setState(() {
              _messages.add(ChatMessage(
                text: "Image received",
                imagePath: movedFilePath,
                isSentByMe: false,
                senderName: endpointMap[endid]?.endpointName ?? "Unknown",
                timestamp: DateTime.now(),
              ));
            });
            tempFileUri = null;
            map.remove(payloadTransferUpdate.id);
            pendingFilePayloads.remove(endid);
          }
        } else if (payloadTransferUpdate.status == PayloadStatus.FAILURE) {
          showSnackbar("Transfer from $endid failed");
        }
      });
    }
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
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 14.h),
            child: Column(
              children: <Widget>[
                SizedBox(height: 24.h),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                      ),
                    ),
                    TextWidget(
                      text: "Public Chat",
                      color: AppColors.primaryTextColor,
                      fontSize: 24.sp,
                    ),
                  ],
                ),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return buildMessageBubble(message);
                    },
                  ),
                ),
                SizedBox(height: 54.h),
              ],
            ),
          ),
          Positioned(
            bottom: 18.h,
            right: 18.w,
            left: 18.w,
            child: _buildBottomSheet(),
          ),
        ],
      ),
    );
  }

  Align buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color: message.isSentByMe ? const Color(0xffADADAD) : const Color(0xff339FE1),
              borderRadius: BorderRadius.circular(20.0.r),
            ),
            child: Column(
              crossAxisAlignment: message.isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (message.imagePath != null)
                  Image.file(
                    File(message.imagePath!),
                    width: 150,
                    height: 150,
                    fit: BoxFit.cover,
                  )
                else
                  Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 18.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            DateFormat.jm().format(message.timestamp),
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8.h),
        ],
      ),
    );
  }

  Widget _buildBottomSheet() {
    return Container(
      height: 54.h,
      width: 360.w,
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(44.r),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: _sendFilePayload,
            tooltip: "Send Image",
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w300,
              ),
              decoration: InputDecoration(
                hintText: "Type a Message",
                hintStyle: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w300,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: _outlinedInputBorder(),
                enabledBorder: _outlinedInputBorder(),
                errorBorder: _outlinedInputBorder(),
                focusedBorder: _outlinedInputBorder(),
                disabledBorder: _outlinedInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () {
              if (_messageController.text.trim().isEmpty) return;
              _sendTextMessage();
            },
            tooltip: "Send Image",
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _outlinedInputBorder() {
    return const OutlineInputBorder(
      borderSide: BorderSide(color: Colors.transparent),
    );
  }

  void _sendTextMessage() {
    String message = _messageController.text;
    setState(() {
      _messages.add(ChatMessage(
        text: message,
        isSentByMe: true,
        senderName: "Me ($userName)",
        timestamp: DateTime.now(),
      ));
    });
    endpointMap.forEach((key, value) {
      Nearby().sendBytesPayload(key, Uint8List.fromList(message.codeUnits));
    });
    _messageController.clear();
  }

  void _sendFilePayload() async {
    XFile? file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;

    String filePath = file.path;
    setState(() {
      _messages.add(ChatMessage(
        text: "Image sent",
        imagePath: filePath,
        isSentByMe: true,
        senderName: "Me ($userName)",
        timestamp: DateTime.now(),
      ));
    });

    for (MapEntry<String, ConnectionInfo> m in endpointMap.entries) {
      int payloadId = await Nearby().sendFilePayload(m.key, filePath);
      showSnackbar("Sending file with payloadId: $payloadId to ${m.key}");
      Nearby().sendBytesPayload(
        m.key,
        Uint8List.fromList("$payloadId:${filePath.split('/').last}".codeUnits),
      );
    }
  }

  Future<String> _moveFile(String uri, String fileName) async {
    String parentDir = (await getExternalStorageDirectory())!.absolute.path;
    final newPath = '$parentDir/$fileName';
    await Nearby().copyFileAndDeleteOriginal(uri, newPath);
    showSnackbar("File moved to: $newPath");
    return newPath;
  }

  void showSnackbar(dynamic message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.toString())),
    );
  }
}
