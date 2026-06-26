<div align="center">

# Loopline

**Usa tu iPhone como micrófono y altavoz de tu PC, por USB.**

Audio de baja latencia entre iPhone y Windows sobre el túnel USB de Apple
(usbmux) — sin Wi-Fi, sin servidores en la nube, sin cuentas.

</div>

---

## ¿Qué hace?

Mientras el servidor corre en tu PC y el iPhone está conectado por cable:

- 🎙️ **Micrófono:** la voz captada por el iPhone aparece en Windows como un
  micrófono normal — úsalo en Zoom, Discord, OBS, lo que sea.
- 🔊 **Altavoz:** todo lo que reproduce la PC suena por el altavoz del iPhone.
- 🔁 **Full-duplex** real (mic y altavoz a la vez) con cancelación de eco por
  hardware en iOS.

Todo viaja por el **cable USB** usando el mismo canal `usbmux` que usa iTunes /
Apple Devices, así que no toca la red.

## Arquitectura

```
 iPhone (app SwiftUI, iOS 26 · Liquid Glass)
   AVAudioEngine ──► NWListener TCP :7001 ──┐
   AVAudioEngine ◄── PCM 48 kHz mono int16 ─┤
                                            │  usbmux (Apple Mobile Device Service :27015)
 PC (Loopline.Server, .NET + NAudio)        │
   CABLE-A Input  ◄── mic del iPhone        │  apps graban de  CABLE-A Output
   CABLE-B Output ──► audio de apps ────────┘  apps reproducen en CABLE-B Input
   IPolicyConfig: fija los "default device" al iniciar y los restaura al salir
```

El protocolo de cable está documentado en [`docs/protocol.md`](docs/protocol.md).

## Requisitos

**PC (Windows 10/11):**
- **Apple Devices** (o iTunes) instalado — provee el servicio usbmux. Si tu
  iPhone aparece en el Explorador al conectarlo, ya lo tienes.
- **Dos cables de audio virtuales** para full-duplex. Recomendado:
  [VB-CABLE A+B](https://vb-audio.com/Cable/) (gratis) o
  [VoiceMeeter](https://vb-audio.com/Voicemeeter/). Con un solo VB-Cable,
  Loopline funciona en **half-duplex** (mic *o* altavoz).

**iPhone:** iOS 26 o superior.

## Instalación

### 1. Servidor de Windows

Descarga `Loopline.Server.exe` de la última
[Release](../../releases) (o de los *artifacts* de la pestaña **Actions**).
Es un ejecutable autónomo, no necesita instalar .NET.

```powershell
# Ver tus dispositivos de audio detectados:
.\Loopline.Server.exe --list

# Correr:
.\Loopline.Server.exe
```

### 2. App del iPhone (sideload sin Mac)

El build de CI produce un **IPA sin firmar** (`Loopline-unsigned.ipa`). Para
instalarlo desde Windows con tu Apple ID gratis:

1. Instala [SideStore](https://sidestore.io) (o
   [AltStore](https://altstore.io)) siguiendo su guía — usa el mismo servicio
   de Apple Devices que ya tienes.
2. Arrastra `Loopline-unsigned.ipa` a SideStore/AltStore para firmarlo con tu
   Apple ID e instalarlo.
3. La firma gratis caduca a los 7 días; SideStore puede **renovarla
   automáticamente** por Wi-Fi. (Con una cuenta Apple Developer de pago dura un
   año — ver [`docs/sideload-ios.md`](docs/sideload-ios.md).)

Detalles paso a paso: [`docs/sideload-ios.md`](docs/sideload-ios.md).

## Uso

1. Conecta el iPhone por USB (acepta *"Confiar en esta computadora"*).
2. Corre `Loopline.Server.exe` en la PC.
3. Abre **Loopline** en el iPhone y toca **Iniciar**.
4. El servidor enlaza por USB, fija los dispositivos virtuales como
   predeterminados y empieza a enrutar. Verás los medidores de nivel en la
   consola y en la app.
5. Al cerrar el servidor (Ctrl+C), **restaura** tus dispositivos de audio
   originales.

Banderas útiles del servidor:

| Flag | Efecto |
|------|--------|
| `--list` | Lista dispositivos de reproducción y grabación y sale. |
| `--no-default-switch` | No cambia los dispositivos por defecto de Windows. |
| `--port N` | Puerto del túnel hacia la app (por defecto `7001`). |

## Compilar desde el código

No necesitas Mac: **GitHub Actions** compila ambos artefactos.

- **iOS** (`macos-26`, Xcode 26): genera el `.xcodeproj` con
  [XcodeGen](https://github.com/yonaskolb/XcodeGen), rasteriza el icono y
  empaqueta el IPA sin firmar.
- **Windows** (`windows-latest`): `dotnet publish` self-contained `win-x64`.

Para una **Release** con binarios adjuntos, empuja un tag `vX.Y.Z`:

```bash
git tag v1.0.0 && git push origin v1.0.0
```

Detalles de la configuración de audio en Windows:
[`docs/setup-windows.md`](docs/setup-windows.md).

## Limitaciones / notas

- La firma gratis de sideload caduca cada 7 días (límite de Apple).
- Full-duplex requiere **dos** cables virtuales; con uno solo es half-duplex.
- `IPolicyConfig` es una API no documentada de Windows (la que usan nircmd y
  similares) — estable en la práctica, pero no oficial.
- Pensado para uso personal en tu propio equipo.

## Licencia

[MIT](LICENSE).
