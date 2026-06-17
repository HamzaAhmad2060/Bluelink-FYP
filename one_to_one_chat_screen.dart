import 'dart:math';
import 'dart:typed_data';
import 'dart:io';

import '../exports.dart';

class OneToOneChatScreen extends StatefulWidget {
  final String peerName; 

  const OneToOneChatScreen({super.key, required this.peerName});

  @override
  State<OneToOneChatScreen> createState() => _OneToOneChatScreenState();
}

class _OneToOneChatScreenState extends State<OneToOneChatScreen> {
  final String userName = Random().nextInt(10000).toString();
  final Strategy strategy = Strategy.P2P_STAR; 
  String? connectedEndpointId;
  ConnectionInfo? connectionInfo;

  final List<ChatMessage> _messages = [];
  final TextEditingController _messageController = TextEditingController();

  String? tempFileUri;
  Map<int, String> map = {};
  Map<String, int> pendingFilePayloads = {};

  @override
  void initState() {
    super.initState();
    _startDiscoveryForPeer();
  }

  @override
  void dispose() {
    _messageController.dispose();
    Nearby().stopAllEndpoints();
    super.dispose();
  }

  void _startDiscoveryForPeer() async {
    try {
      await Nearby().startAdvertising(
        userName,
        strategy,
        onConnectionInitiated: _onConnectionInit,
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) {
            showSnackbar("Connected to $id");
            setState(() {
              connectedEndpointId = id;
            });
          } else if (status == Status.REJECTED) {
            showSnackbar("Disconnected from $id");
            setState(() {
              connectedEndpointId = null;
              connectionInfo = null;
            });
          }
        },
        onDisconnected: (id) {
          showSnackbar("Disconnected: $id");
          setState(() {
            connectedEndpointId = null;
            connectionInfo = null;
          });
        },
      );

      await Nearby().startDiscovery(
        widget.peerName,
        strategy,
        onEndpointFound: (id, name, serviceId) {
          if (connectedEndpointId == null) {
            Nearby().requestConnection(
              userName,
              id,
              onConnectionInitiated: _onConnectionInit,
              onConnectionResult: (id, status) {
                if (status == Status.CONNECTED) {
                  showSnackbar("Connected to $id");
                  setState(() {
                    connectedEndpointId = id;
                  });
                }
              },
              onDisconnected: (id) {
                showSnackbar("Disconnected from $id");
                setState(() {
                  connectedEndpointId = null;
                  connectionInfo = null;
                });
              },
            );
          }
        },
        onEndpointLost: (id) {
          showSnackbar("Lost endpoint: $id");
        },
      );
    } catch (e) {
      showSnackbar("Error: $e");
    }
  }

  void _onConnectionInit(String id, ConnectionInfo info) async {
    setState(() {
      connectionInfo = info;
      connectedEndpointId = id;
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
              showSnackbar("Metadata received for payloadId: $payloadId");
              tempFileUri = null;
              pendingFilePayloads.remove(endid);
            }
          } else {
            setState(() {
              _messages.add(ChatMessage(
                text: str,
                isSentByMe: false,
                senderName: connectionInfo?.endpointName ?? "Peer",
                timestamp: DateTime.now(),
              ));
            });
          }
        } else if (payload.type == PayloadType.FILE) {
          tempFileUri = payload.uri;
          pendingFilePayloads[endid] = payload.id ?? Random().nextInt(100000);
          showSnackbar("File transfer started from $endid");
        }
      },
      onPayloadTransferUpdate: (endid, payloadTransferUpdate) async {
        if (payloadTransferUpdate.status == PayloadStatus.SUCCESS) {
          showSnackbar("Transfer from $endid successful");
          if (tempFileUri != null &&
              map.containsKey(payloadTransferUpdate.id)) {
            String fileName = map[payloadTransferUpdate.id]!;
            String movedFilePath = await _moveFile(tempFileUri!, fileName);
            setState(() {
              _messages.add(ChatMessage(
                text: "Image received",
                imagePath: movedFilePath,
                isSentByMe: false,
                senderName: connectionInfo?.endpointName ?? "Peer",
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
      },
    );
  }

  Future<String> _moveFile(String uri, String fileName) async {
    String parentDir = (await getExternalStorageDirectory())!.absolute.path;
    final newPath = '$parentDir/$fileName';
    await Nearby().copyFileAndDeleteOriginal(uri, newPath);
    showSnackbar("File moved to: $newPath");
    return newPath;
  }

  void _sendTextMessage() {
    if (connectedEndpointId == null) {
      showSnackbar("Not connected to any user");
      return;
    }
    String message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(
        text: message,
        isSentByMe: true,
        senderName: "Me ($userName)",
        timestamp: DateTime.now(),
      ));
    });

    Nearby().sendBytesPayload(
        connectedEndpointId!, Uint8List.fromList(message.codeUnits));
    _messageController.clear();
  }

  void _sendFilePayload() async {
    if (connectedEndpointId == null) {
      showSnackbar("Not connected to any user");
      return;
    }
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

    int payloadId =
        await Nearby().sendFilePayload(connectedEndpointId!, filePath);
    showSnackbar(
        "Sending file with payloadId: $payloadId to $connectedEndpointId");
    Nearby().sendBytesPayload(
      connectedEndpointId!,
      Uint8List.fromList("$payloadId:${filePath.split('/').last}".codeUnits),
    );
  }

  void showSnackbar(dynamic message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.toString())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Chat with ${widget.peerName}"),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Nearby().stopAllEndpoints();
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment:
          message.isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: message.isSentByMe ? Colors.blueGrey : Colors.blue,
          borderRadius: BorderRadius.circular(16),
        ),
        child: message.imagePath != null
            ? Image.file(
                File(message.imagePath!),
                width: 150,
                height: 150,
                fit: BoxFit.cover,
              )
            : Text(
                message.text,
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.attach_file),
            onPressed: _sendFilePayload,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: "Type a message",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.send),
            onPressed: _sendTextMessage,
          ),
        ],
      ),
    );
  }
}
