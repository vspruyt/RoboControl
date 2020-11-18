# RoboControl
Simple IOS app to control a robot over BLE Bluetooth.
It sends 7 byte acceleration and steering messages in the following format:

```
0x1 (start-of-header) | 0x2 (start-of-text) | [0,1] (0=velocity, 1=steering) | 4-byte float (velocity or steering)
```

It also receives and displays any short String message, as long as that message starts with the 0x01 character.

