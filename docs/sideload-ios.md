# Instalar la app en el iPhone sin Mac

El CI de Loopline genera un **IPA sin firmar** (`Loopline-unsigned.ipa`). Como
no tienes Mac, lo firmas e instalas desde Windows con tu **Apple ID gratis**.

## Opción A — SideStore (recomendada)

SideStore renueva la firma por Wi-Fi, así no tienes que reconectar el cable cada
semana.

1. Sigue la guía oficial: <https://sidestore.io>. Usa el servicio **Apple
   Devices / iTunes** que ya tienes instalado (es el que provee usbmux).
2. Empareja el dispositivo e inicia sesión con tu Apple ID.
3. En SideStore, pulsa **+** y elige `Loopline-unsigned.ipa`.
4. La app queda instalada. La firma gratis dura **7 días**; SideStore la
   **renueva sola** mientras el iPhone y el PC estén en la misma red.

## Opción B — AltStore Classic

1. Instala **AltServer** en Windows: <https://altstore.io>.
2. AltServer → *Install AltStore* en el iPhone (pide tu Apple ID).
3. En el iPhone, AltStore → **+** → selecciona el IPA.
4. Mantén AltServer corriendo para las renovaciones automáticas cada 7 días.

## Confiar en el certificado

La primera vez, en el iPhone:
**Ajustes → General → VPN y gestión de dispositivos →** tu Apple ID **→
Confiar**.

## Permisos al abrir

- **Micrófono:** acéptalo — es lo que envía tu voz a la PC.

## Cuenta Apple Developer de pago (opcional)

Con una cuenta de pago ($99/año) la firma dura **1 año** y puedes firmar en CI.
Si vas por esa ruta, dime y configuro el workflow de iOS con tus secretos
(`BUILD_CERTIFICATE_BASE64`, `P12_PASSWORD`, `PROVISIONING_PROFILE_BASE64`) y un
paso de `xcodebuild -exportArchive` con firma real.

## Límites de la cuenta gratis

- Máx. 3 apps sideload a la vez por Apple ID.
- Renovación cada 7 días.
- El App ID se crea solo; no requiere portal de desarrollador.
