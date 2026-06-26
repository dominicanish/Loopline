# Configuración de audio en Windows

Loopline usa **un solo cable de audio virtual** para el micrófono. El audio de
la PC NO necesita cable: se captura por *loopback* del dispositivo de salida
real.

## Instalar VB-CABLE

1. Descarga **VB-CABLE** de <https://vb-audio.com/Cable/>.
2. Descomprime y ejecuta `VBCABLE_Setup_x64.exe` **como administrador**.
   Reinicia si lo pide.
3. Tras instalar verás (compруébalo con `Loopline.Server --list`):
   - `CABLE Input (VB-Audio Virtual Cable)`  — endpoint de reproducción
   - `CABLE Output (VB-Audio Virtual Cable)` — endpoint de grabación

## Cómo enruta Loopline

| Rol | Cómo |
|-----|------|
| **Mic del iPhone → Windows** | Loopline escribe en `CABLE Input` y pone `CABLE Output` como **micrófono por defecto**, así toda app (Zoom, Discord…) usa tu iPhone como mic. |
| **Audio de la PC → iPhone** | Loopline hace *loopback* de tu dispositivo de salida real (Realtek, etc.) y lo envía al teléfono. |
| **Silencio en la PC** | Mientras el iPhone está conectado, Loopline **silencia** la salida real para que el audio solo salga del teléfono. Se restaura al desconectar/cerrar. |

El loopback sigue capturando aunque el dispositivo esté en mute (el mute se
aplica en el endpoint, después del punto de captura) — el mismo principio por el
que OBS graba el audio del escritorio con las bocinas en silencio.

## Banderas útiles

```powershell
.\Loopline.Server.exe --list             # ver tus dispositivos
.\Loopline.Server.exe --no-mute-pc       # no silenciar la PC
.\Loopline.Server.exe --no-default-switch # no cambiar el mic por defecto
```

## Diagnóstico

Con el iPhone conectado, reproduce algo en la PC y observa el medidor `spk` en
la consola: debe moverse. El medidor `mic` se mueve cuando hablas al iPhone. Si
tu cable tiene otro nombre, abre un issue: la detección usa coincidencia por
subcadena (`CABLE`, `CABLE-A`, `VoiceMeeter`).
