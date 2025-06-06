import 'dart:convert';
import 'package:bluetooth_project/widgets/action_button.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final _bluetooth = FlutterBluetoothSerial.instance;
  bool _bluetoothState = false;
  bool _isConnecting = false;
  BluetoothConnection? _connection;
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _deviceConnected;
  int times = 0;

  void _getDevices() async {
    var res = await _bluetooth.getBondedDevices();
    setState(() => _devices = res);
  }

  void _receiveData() {
    _connection?.input?.listen((event) {
      if (String.fromCharCodes(event) == "p") {
        setState(() => times = times + 1);
      }
    });
  }

  void _sendData(String data) {
    if (_connection?.isConnected ?? false) {
      _connection?.output.add(ascii.encode(data));
    }
  }

  void _requestPermission() async {
    await Permission.location.request();
    await Permission.bluetooth.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
  }

  @override
  void initState() {
    super.initState();

    _requestPermission();

    _bluetooth.state.then((state) {
      setState(() => _bluetoothState = state.isEnabled);
    });

    _bluetooth.onStateChanged().listen((state) {
      switch (state) {
        case BluetoothState.STATE_OFF:
          setState(() => _bluetoothState = false);
          break;
        case BluetoothState.STATE_ON:
          setState(() => _bluetoothState = true);
          break;
        // case BluetoothState.STATE_TURNING_OFF:
        //   break;
        // case BluetoothState.STATE_TURNING_ON:
        //   break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('Control de Leds')),
      body: Column(
        children: [
          _controlBT(),
          _infoDevice(),
          Expanded(child: _listDevices()),
          _buttons(),
        ],
      ),
    );
  }

  Widget _controlBT() {
    return SwitchListTile(
      value: _bluetoothState,
      onChanged: (bool value) async {
        if (value) {
          await _bluetooth.requestEnable();
        } else {
          await _bluetooth.requestDisable();
        }
      },
      tileColor: Colors.black26,
      title: Text(
        _bluetoothState ? "Bluetooth encendido" : "Bluetooth apagado",
      ),
    );
  }

  Widget _infoDevice() {
    return ListTile(
      tileColor: Colors.black12,
      title: Text("Conectado a: ${_deviceConnected?.name ?? "ninguno"}"),
      trailing:
          _connection?.isConnected ?? false
              ? TextButton(
                onPressed: () async {
                  await _connection?.finish();
                  setState(() => _deviceConnected = null);
                },
                child: const Text("Desconectar"),
              )
              : TextButton(
                onPressed: _getDevices,
                child: const Text("Ver dispositivos"),
              ),
    );
  }

  Widget _listDevices() {
    return _isConnecting
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
          child: Container(
            color: Colors.grey.shade100,
            child: Column(
              children: [
                ...[
                  for (final device in _devices)
                    ListTile(
                      title: Text(device.name ?? device.address),
                      trailing: TextButton(
                        child: const Text('conectar'),
                        onPressed: () async {
                          setState(() => _isConnecting = true);

                          _connection = await BluetoothConnection.toAddress(
                            device.address,
                          );
                          _deviceConnected = device;
                          _devices = [];
                          _isConnecting = false;

                          _receiveData();

                          setState(() {});
                        },
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
  }

  Widget _buttons() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 8.0),
      color: Colors.black12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Controles para LED', style: TextStyle(fontSize: 18.0)),
          const SizedBox(height: 16.0),
          _rowButtons("Foco 1", "a", "b", Colors.green, Colors.red),
          const SizedBox(height: 8.0),
          _rowButtons("Foco 2", "c", "d", Colors.green, Colors.red),
          const SizedBox(height: 8.0),
          _rowButtons("Foco 3", "e", "f", Colors.green, Colors.red),
        ],
      ),
    );
  }

  Widget _rowButtons(
    String label,
    String onCmd,
    String offCmd,
    Color onColor,
    Color offColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4.0),
        Row(
          children: [
            Expanded(
              child: ActionButton(
                text: "Encender",
                color: onColor,
                onTap: () {
                  // print("Enviando comando: $onCmd");
                  _sendData(onCmd);
                },
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: ActionButton(
                text: "Apagar",
                color: offColor,
                onTap: () {
                  //   print("Enviando comando: $offCmd");
                  _sendData(offCmd);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
