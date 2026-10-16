# 🐳 DeepSeek Whale Girl · mascota de escritorio para Mac

[简体中文](README.md) · [English](README.en.md) · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · **Español** · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [Русский](README.ru.md)

Una chica ballena de DeepSeek que vive en la parte inferior de la pantalla de tu Mac. Corretea de un lado a otro, sigue el cursor con la mirada, habla cuando haces clic en ella, llora cuando la levantas y, cuando se aburre, se pone a «pensar a fondo». A veces sostiene un cartel con «区» y pregunta qué significa «凶».

![Vista previa](docs/preview.png)

> Este es un proyecto no oficial hecho por fans. No está afiliado a DeepSeek ni cuenta con su respaldo.

## Instalación

Requiere macOS 13 o posterior. Funciona en Mac con Apple Silicon y con Intel.

### Opción 1: instalar con un solo comando (recomendado)

Abre Terminal, pega esta línea y pulsa Retorno:

```bash
curl -fsSL https://raw.githubusercontent.com/jianzhou0420/deepseek-whale-girl-mac/main/install.sh | bash
```

Instala la app en `~/Applications` y la abre.

### Opción 2: descarga manual

1. Descarga `WhaleGirl-macOS.zip` desde [Releases](https://github.com/jianzhou0420/deepseek-whale-girl-mac/releases/latest) y haz doble clic para descomprimirlo.
2. Arrastra `WhaleGirl.app` a la carpeta Aplicaciones.
3. La primera vez que la abras, macOS dirá que no puede verificar al desarrollador, porque la app no está notarizada. Para abrirla igualmente:
   - Haz **clic derecho** en `WhaleGirl.app`, elige **Abrir** y vuelve a hacer clic en **Abrir**.
   - Si aun así no se abre, ejecuta esto en Terminal:
     ```bash
     xattr -dr com.apple.quarantine /Applications/WhaleGirl.app
     ```

### Opción 3: compilar desde el código fuente

Necesitas Xcode o las herramientas de línea de comandos de Xcode (si no las tienes, ejecuta `xcode-select --install`).

```bash
git clone https://github.com/jianzhou0420/deepseek-whale-girl-mac.git
cd deepseek-whale-girl-mac
./build.sh
open WhaleGirl.app
```

## Cómo jugar

Habla en chino. Sus frases son bromas sobre DeepSeek, como «服务器繁忙，请稍后再试» («El servidor está ocupado, inténtalo más tarde»).

| Tú haces | Ella hace |
|---|---|
| Mover el ratón | Gira la cabeza hacia el cursor (16 direcciones) |
| Hacer clic en ella | Saluda, da un saltito, dice algo o se pone a «pensar a fondo» |
| Arrastrarla | Llora «¡bájame!» y cae al suelo cuando la sueltas |
| Clic derecho sobre ella, o 🐳 en la barra de menús | Menú: hablar, pensar, mostrar el cartel, dormir, volver al centro, salir |
| Dejarla tranquila | Pasea, se queda en las nubes, echa la siesta y muestra su cartel |

No te estorbará. Los clics en la zona transparente a su alrededor pasan directamente a la ventana de detrás.

**Salir**: Haz clic en 🐳 en la barra de menús y elige 退出鲸鱼娘 (Salir). La app no tiene icono en el Dock, así que ⌘Q no funciona.

**Volver a abrirla**: Busca `WhaleGirl` en Spotlight (⌘ Espacio).

**Desinstalar**: Ciérrala y mueve `WhaleGirl.app` a la Papelera.

## Personalízala

Todo el código está en un único archivo, [`main.swift`](main.swift):

- Sus frases y los textos del menú están en `enum Lines`.
- Los fotogramas de animación de cada estado están en `struct Anim`.
- La frecuencia con la que camina, duerme y habla se decide en `decide()`.

Después de hacer cambios, vuelve a ejecutar `./build.sh`.

## Créditos y licencia

- Atlas de animación del personaje de [f0909172434/deepseek-girl-codex-pet](https://github.com/f0909172434/deepseek-girl-codex-pet) (licencia MIT). Consulta [`assets/SOURCE.md`](assets/SOURCE.md) y [`assets/LICENSE`](assets/LICENSE).
- El código de este proyecto se publica bajo la [licencia MIT](LICENSE).
- El nombre y el logotipo de DeepSeek pertenecen a sus respectivos propietarios.
