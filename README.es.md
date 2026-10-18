# 🐋 WhaleSeek · una chica ballena que vigila tu uso de IA en el Mac

[简体中文](README.md) · [English](README.en.md) · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · **Español** · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [Русский](README.ru.md)

Una chica ballena de DeepSeek que vive en una esquina de la pantalla de tu Mac. Su bocadillo muestra tu saldo de DeepSeek, el gasto de hoy y una cuenta atrás hasta el siguiente cambio de tarifa punta / valle. Es una versión nativa para Mac del [widget de saldo de DSH](https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget) y no necesita DeepSeek Harness.

![Vista previa](docs/preview.png)

![10 movimientos generados con IA](docs/animations.gif)

> Este es un proyecto no oficial hecho por fans. No está afiliado a DeepSeek ni cuenta con su respaldo.
>
> Antes se llamaba WhaleBalance; desde la v0.0.6 se llama WhaleSeek. Al actualizar, los ajustes, el registro y las claves de API se migran automáticamente.

## Funciones

- **Saldo**: consulta tu saldo de DeepSeek con tu clave de API, se actualiza cada 60 segundos y al hacer clic en ella. Puede mostrar el saldo total, el bonificado y el recargado por separado.
- **Gasto de hoy**: suma las bajadas de saldo como gasto. Las recargas se registran aparte y nunca anulan el gasto, y puedes corregir cualquier día a mano. Cada clave de API tiene su propio libro.
- **Ventana de cuentas**: hoy, los últimos 7 días o todo el historial, con detalle por entrada, búsqueda por fecha o modelo y un desglose del gasto.
- **Punta / valle**: los días laborables de 9 a 12 y de 14 a 18 (hora de Pekín) son hora punta; los fines de semana y los festivos chinos son valle todo el día. Cinco estilos, incluida una cuenta atrás en vivo.
- **Bocadillos personalizables**: secuencia de clics, elección A/B ponderada y módulos de texto, enlaces, frases aleatorias, imágenes, saldo, gasto de hoy, estado punta / valle, otros proveedores y uso de Codex. Cada módulo tiene su propio tamaño, colores, degradado animado y fuente.
- **Alertas**: avisos de saldo bajo y de presupuesto diario, con contenido editable.
- **Otros proveedores**: 34 plantillas, con saldos de OpenRouter, Kimi, StepFun y Novita, cuotas de suscripción de Zhipu, Kimi Coding, MiniMax y OpenCode Go, y pasarelas compatibles con OpenAI. Las claves solo se envían al endpoint oficial de cada plantilla, salvo que permitas uno personalizado.
- **Estadísticas de Codex**: lee los registros locales de sesiones de Codex para contar tokens y ventanas de suscripción, sin conexión a internet.
- **App nativa de Mac**: arrástrala a cualquier sitio; se pega a los bordes de la pantalla y se voltea al pegarse a la izquierda. Saldo en la barra de menús, inicio automático al iniciar sesión y claves de API guardadas en el Llavero.
- **Suscripciones y costes de API**: detecta automáticamente cswap (el uso de 5 horas, 7 días, gasto extra y por modelo de cada cuenta de Claude), el plan y los tokens de Claude Code y el plan de ChatGPT detrás de Codex. Con una clave Admin de organización también muestra los costes de las API de OpenAI y Claude.
- **Reproducción automática**: cada 1–3 minutos hace algo por su cuenta: un pequeño movimiento, una burbuja aleatoria o un informe de uso. Cada movimiento trae 5 frases a juego que no se repiten. También avisa al cambiar entre hora punta y valle, o cuando una suscripción supera su umbral o se reinicia. Se queda en silencio en pantalla completa, en reuniones, cuando no estás y de noche, y la reproducción automática nunca suena.
- **Movimientos generados con IA**: 10 animaciones fotograma a fotograma creadas con el pipeline de arte (estirarse, comer, dormitar, teclear, bailar, contar dinero y más), mezcladas con los movimientos originales.
- **Chatea con ella**: pasa el ratón por encima y pulsa el botón de chat. Responde a través de la API de DeepSeek: pícara, pero te dice con exactitud tu saldo, el gasto de hoy y el uso de tus suscripciones. Con la «voz interior» activada muestra además una línea de lo que piensa de verdad. También puede hablarte por su cuenta durante la reproducción automática (desactivado por defecto). Al chatear se envían a api.deepseek.com el personaje, tu saldo, el gasto de hoy, los porcentajes de suscripción y los mensajes recientes, con cargo a tu saldo de DeepSeek; el historial se queda en tu Mac.

No se han portado el coste por turno, el sonido de fin de tarea, los avisos de preguntas y aprobaciones ni el módulo de nombre de conversación. Dependen de eventos internos de DeepSeek Harness que una app independiente no puede ver.

## Instalación

Requiere macOS 13 o posterior. Funciona en Mac con Apple Silicon y con Intel.

### Opción 1: instalar con un solo comando (recomendado)

Abre Terminal, pega esta línea y pulsa Retorno:

```bash
curl -fsSL https://raw.githubusercontent.com/jianzhou0420/whaleseek/main/install.sh | bash
```

Instala la app en `~/Applications` y la abre.

### Opción 2: descarga manual

1. Descarga `WhaleSeek-macOS.zip` desde [Releases](https://github.com/jianzhou0420/whaleseek/releases/latest) y haz doble clic para descomprimirlo.
2. Arrastra `WhaleSeek.app` a la carpeta Aplicaciones.
3. La primera vez que la abras, macOS dirá que no puede verificar al desarrollador, porque la app no está notarizada. Para abrirla igualmente:
   - Haz **clic derecho** en `WhaleSeek.app`, elige **Abrir** y vuelve a hacer clic en **Abrir**.
   - Si aun así no se abre, ejecuta esto en Terminal:
     ```bash
     xattr -dr com.apple.quarantine /Applications/WhaleSeek.app
     ```

### Opción 3: compilar desde el código fuente

Necesitas Xcode o las herramientas de línea de comandos de Xcode (si no las tienes, ejecuta `xcode-select --install`).

```bash
git clone https://github.com/jianzhou0420/whaleseek.git
cd whaleseek
./build.sh
open WhaleSeek.app
```

Al abrirla por primera vez se abre la ventana de ajustes. Pega tu clave de API de DeepSeek y guárdala. La clave solo se guarda en el Llavero de macOS.

## Cómo se usa

| Tú haces | Ella hace |
|---|---|
| Clic en ella | Actualiza el saldo y muestra el bocadillo del saldo |
| Clic en el bocadillo | Muestra el siguiente elemento (frases e imágenes aleatorias) y se cierra tras el último |
| Arrastrarla | La mueve; al soltarla se pega al borde más cercano |
| Botón de chat (al pasar el ratón) o el menú 「和鲸鱼娘聊天」 | Abre la ventana de chat |
| Clic derecho sobre ella, el botón ⋯ o 🐳 en la barra de menús | Menú: tamaño, sonidos, bocadillos, anclaje, cuentas, ajustes, salir |

## Generador de ilustraciones

`art-pipeline/` genera nuevas poses de la chica ballena con la generación de imágenes integrada en Codex CLI, usando tu plan de ChatGPT en vez de una clave de API. Quita el fondo, limpia los bordes, revisa cada imagen, vuelve a generar las que fallan e instala las válidas en la galería integrada de la app. Escribe las nuevas poses en `art-pipeline/assets.json` y ejecuta:

```bash
codex login
./art.sh all
```

`./art.sh anim` genera animaciones a partir de `art-pipeline/anims.json`: 6 fotogramas por imagen, recortados automáticamente, alineados por los pies y revisados para que sean coherentes. Después, `./art.sh anim-install` los añade a la app.

Cada imagen tarda unos 40 segundos. Generar imágenes consume los límites de Codex de 3 a 5 veces más rápido que el texto.

![Imágenes creadas por el generador](docs/generated-art.png)

¿Buscas la mascota que camina por el escritorio de la primera versión? Sigue disponible en la [versión v0.0.1](https://github.com/jianzhou0420/whaleseek/releases/tag/v0.0.1).

## Créditos y licencia

- El diseño de funciones, las reglas de contabilidad, las plantillas de proveedores y las frases por defecto se han portado de [MeteorNOX/DeepSeek-Balance-Whale-Widget](https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget) (MIT). Sus imágenes y sonidos no tienen licencia MIT y no se usan aquí.
- Arte del personaje de [f0909172434/deepseek-girl-codex-pet](https://github.com/f0909172434/deepseek-girl-codex-pet) (MIT).
- Las imágenes de `assets/generated` las creó el generador con gpt-image-2 de OpenAI, usando ese personaje como referencia. Consulta [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
- El código de este proyecto se publica bajo la [licencia MIT](LICENSE).
