# Loopline wire protocol

A tiny framed protocol spoken over a single reliable byte stream. On the device
the iPhone app listens on TCP `:7001`; on the PC the server reaches that port
through Apple's usbmux tunnel (USB), so no Wi-Fi / network is involved.

## Framing

Every message is:

```
+--------+------------------+----------------------+
| type   | length (uint32)  | payload (length bytes)|
| 1 byte | little-endian    |                       |
+--------+------------------+----------------------+
```

`length` is the size of `payload` only (it does not include the 5-byte header).

## Message types

| type | name     | direction      | payload                                   |
|------|----------|----------------|-------------------------------------------|
| 0x01 | HELLO    | both           | UTF-8 JSON (see below), sent once on connect |
| 0x10 | MIC_PCM  | iPhone → PC    | raw PCM: int16 LE, mono, 48 kHz           |
| 0x11 | SPK_PCM  | PC → iPhone    | raw PCM: int16 LE, mono, 48 kHz           |
| 0x20 | PING     | both           | 8-byte LE timestamp (ms)                  |
| 0x21 | PONG     | both           | echo of the PING payload                  |
| 0x30 | BYE      | both           | empty                                     |

### Audio format (fixed, no negotiation)

* Sample rate: **48000 Hz**
* Channels: **1 (mono)**
* Sample format: **signed 16-bit, little-endian**
* Recommended packet: **10 ms = 480 samples = 960 bytes**

Keeping the format fixed avoids negotiation logic; each side converts to/from its
native engine format. Over USB the bandwidth (~1.5 Mbps even at stereo) is a
non-issue, so we send uncompressed PCM for the lowest possible latency.

### HELLO payload

```json
{ "role": "phone" | "pc", "name": "Maykol's iPhone", "version": 1,
  "sampleRate": 48000, "channels": 1 }
```

Used only for display and a sanity check. If the formats disagree the receiver
logs a warning but still assumes the fixed format above.
