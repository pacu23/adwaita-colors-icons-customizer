# adwaita-colors-icons-customizer
AI-generated script to customize the colors of the Adwaita Colors icon pack.

Required: bc (for calculating the "darker" color, MoreWaita and Adwaita Colors installed and ~/.icons to exist.

Creates custom themes in ~/.icons, recoloring SVGs. Prompts you for a light and a dark color hex. Make sure the contrast is good. Dark color could be your system's accent, light should be very light, as in Adwaita's folders.

Option to include or exclude the MoreWaita app icons. If excluded, still uses the rest of the icons from MoreWaita for extra coverage – had to also exclude the monochrome app icons since they caused issues, but it shouldn't matter unless you specifically need them. 

Theme Libadwaita/adw-gtk3/GNOME shell: https://github.com/pacu23/adwaita-accent-color-changer

<img width="707" height="297" alt="image" src="https://github.com/user-attachments/assets/adb2ee3d-9a74-4603-a3ba-da33bff3b4f5" />

