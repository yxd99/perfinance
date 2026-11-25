# Ícono de la app

Las fuentes son los SVG (grilla de 108 × 108, la del ícono adaptativo de Android):

- `icon.svg`: ícono completo para iOS y Play Store. Cuadrado, sin esquinas redondeadas.
- `icon_foreground.svg`: capa frontal del ícono adaptativo. El fondo es el color `#432A5C`.
- `icon_monochrome.svg`: capa para los íconos temáticos de Android 13+. Solo cuenta la opacidad.

Después de cambiar un SVG, regenera los PNG y los íconos de la app:

```bash
cd assets/icon
for f in icon icon_foreground icon_monochrome; do rsvg-convert -w 1024 -h 1024 $f.svg -o $f.png; done
rsvg-convert -w 512 -h 512 icon.svg -o play_store_512.png
cd ../..
dart run flutter_launcher_icons
```

`play_store_512.png` es el ícono que se sube en Play Console (Ficha de la tienda).
