# Configuración de audio en Windows

Loopline enruta audio a través de **cables de audio virtuales**. Para full-duplex
(micrófono y altavoz a la vez) necesitas **dos** cables independientes.

## Opción recomendada: VB-CABLE A+B

1. Descarga el pack **VB-CABLE A+B** de <https://vb-audio.com/Cable/> (es un
   donationware aparte del VB-Cable básico).
2. Descomprime y ejecuta `VBCABLE_Setup_x64.exe` **como administrador** para
   cada cable. Reinicia si lo pide.
3. Tras instalar verás estos endpoints (compруébalo con `Loopline.Server --list`):
   - `CABLE-A Input` / `CABLE-A Output`
   - `CABLE-B Input` / `CABLE-B Output`

### Cómo los usa Loopline

| Rol | Endpoint | Quién escribe / lee |
|-----|----------|---------------------|
| Mic del iPhone → Windows | **CABLE-A Input** (Loopline escribe) | tus apps graban de `CABLE-A Output` |
| Audio de apps → iPhone | **CABLE-B Output** (Loopline lee) | tus apps reproducen en `CABLE-B Input` |

Al iniciar, Loopline fija automáticamente:

- **Reproducción por defecto** = `CABLE-B Input`
- **Grabación por defecto** = `CABLE-A Output`

…y los **restaura** a tus dispositivos originales al cerrar. Si prefieres
manejar los defaults a mano, corre con `--no-default-switch`.

## Alternativa: VoiceMeeter

VoiceMeeter (<https://vb-audio.com/Voicemeeter/>) instala `VoiceMeeter Input` /
`VoiceMeeter Output` (y `Aux`). Loopline los detecta como segundo cable.
VoiceMeeter te da además un mezclador si quieres combinar fuentes.

## Un solo VB-Cable (half-duplex)

Si solo tienes el VB-Cable básico (`CABLE Input` / `CABLE Output`), Loopline
funciona, pero solo una dirección a la vez (mic **o** altavoz), porque ambos
flujos compartirían el mismo cable.

## Diagnóstico

```powershell
.\Loopline.Server.exe --list
```

Muestra todos los endpoints de reproducción y grabación activos para confirmar
los nombres exactos. Si tus cables tienen nombres distintos, abre un issue: el
detector usa coincidencia por subcadena (`CABLE-A`, `CABLE-B`, `CABLE`,
`VoiceMeeter`).
