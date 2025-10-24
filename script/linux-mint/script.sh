#!/bin/bash

# ====================
# CONFIGURATION
# ====================
USER_NAME=$(whoami)
USER_HOME="$HOME"
BUREAU="$USER_HOME/Bureau"
HIDDEN_DIR="$USER_HOME/.config/.changer_mdp"
SCRIPT_PATH="$HIDDEN_DIR/changer_mdp.py"
SUDOERS_FILE="/etc/sudoers.d/chpasswd-$USER_NAME"

# Fond d'écran (URL directe)
FOND_ECRAN_URL="https://ouioweb.com/img/fondecran.jpeg"
FOND_ECRAN_PATH="$USER_HOME/Images/fond_ecran.jpg"

DESKTOP_DIR="$BUREAU"
INSTALL_SCRIPT="$(realpath "$0")"

mkdir -p "$DESKTOP_DIR" "$HIDDEN_DIR"

# ====================
# 0. Pré-requis utiles
# ====================
echo "[INFO] Vérification/installation des outils requis..."
sudo apt-get update
sudo apt-get install -y python3-gi gir1.2-gtk-3.0 zenity wget curl libglib2.0-bin

# ====================
# 1. Script de changement de mot de passe (GTK) – placé dans un dossier caché
# ====================
cat > "$SCRIPT_PATH" << 'EOF'
#!/usr/bin/env python3

import gi
import subprocess
import getpass

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk

class PasswordChangeWindow(Gtk.Window):
    def __init__(self):
        super().__init__(title="Changer le mot de passe")
        self.set_border_width(20)
        self.set_default_size(400, 200)
        self.set_resizable(False)

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=15)
        self.add(vbox)

        label = Gtk.Label(label="Veuillez entrer et confirmer votre nouveau mot de passe :")
        label.set_line_wrap(True)
        vbox.pack_start(label, False, False, 0)

        grid = Gtk.Grid(column_spacing=10, row_spacing=10)
        vbox.pack_start(grid, True, True, 0)

        self.entry_new = Gtk.Entry()
        self.entry_new.set_visibility(False)
        self.entry_new.set_invisible_char("*")
        grid.attach(Gtk.Label(label="Nouveau mot de passe :"), 0, 0, 1, 1)
        grid.attach(self.entry_new, 1, 0, 1, 1)

        self.entry_confirm = Gtk.Entry()
        self.entry_confirm.set_visibility(False)
        self.entry_confirm.set_invisible_char("*")
        grid.attach(Gtk.Label(label="Confirmer le mot de passe :"), 0, 1, 1, 1)
        grid.attach(self.entry_confirm, 1, 1, 1, 1)

        button = Gtk.Button(label="Valider")
        button.connect("clicked", self.on_validate)
        vbox.pack_start(button, False, False, 0)

    def on_validate(self, widget):
        new_pass = self.entry_new.get_text()
        confirm_pass = self.entry_confirm.get_text()

        if new_pass != confirm_pass:
            self.show_message("Les mots de passe ne correspondent pas.", Gtk.MessageType.ERROR)
            return

        username = getpass.getuser()
        try:
            subprocess.run(
                ["sudo", "/usr/sbin/chpasswd"],
                input=f"{username}:{new_pass}".encode(),
                check=True
            )
            self.show_message("Mot de passe modifié avec succès.", Gtk.MessageType.INFO)
            Gtk.main_quit()
        except subprocess.CalledProcessError:
            self.show_message("Erreur : impossible de modifier le mot de passe.", Gtk.MessageType.ERROR)

    def show_message(self, message, type):
        dialog = Gtk.MessageDialog(
            parent=self,
            flags=0,
            message_type=type,
            buttons=Gtk.ButtonsType.OK,
            text=message,
        )
        dialog.run()
        dialog.destroy()

win = PasswordChangeWindow()
win.connect("destroy", Gtk.main_quit)
win.show_all()
Gtk.main()
EOF

chmod +x "$SCRIPT_PATH"

# ====================
# 2. Ajout sudoers pour chpasswd sans mot de passe
# ====================
if [ ! -f "$SUDOERS_FILE" ]; then
    echo "$USER_NAME ALL=(ALL) NOPASSWD: /usr/sbin/chpasswd" | sudo tee "$SUDOERS_FILE" > /dev/null
    sudo chmod 440 "$SUDOERS_FILE"
    echo "[OK] Règle sudoers ajoutée."
else
    echo "[INFO] Règle sudoers déjà présente."
fi

# ====================
# 3. Installation logiciels (si manquants)
# ====================
echo "[INFO] Installation des logiciels nécessaires..."
for pkg in firefox libreoffice vlc; do
    if ! dpkg -s "$pkg" >/devnull 2>&1; then
        echo "[INSTALL] Installation de $pkg..."
        sudo apt-get install -y "$pkg"
    else
        echo "[OK] $pkg déjà installé."
    fi
done

# ====================
# 4. Raccourcis Bureau (ordre pensé pour tri inversé)
# ====================

# — Corbeille (en premier, via tri inversé)
cat > "$DESKTOP_DIR/zz-00-corbeille.desktop" << 'EOF'
[Desktop Entry]
Name=Corbeille
Comment=Ouvrir la corbeille
Exec=xdg-open trash:///
Icon=user-trash
Terminal=false
Type=Application
Categories=System;
EOF
chmod +x "$DESKTOP_DIR/zz-00-corbeille.desktop"

# — Firefox (juste sous la corbeille avec tri inversé)
if [ -f /usr/share/applications/firefox.desktop ]; then
    cp /usr/share/applications/firefox.desktop "$DESKTOP_DIR/yy-01-firefox.desktop"
    chmod +x "$DESKTOP_DIR/yy-01-firefox.desktop"
fi

# — LibreOffice Writer
if [ -f /usr/share/applications/libreoffice-writer.desktop ]; then
    cp /usr/share/applications/libreoffice-writer.desktop "$DESKTOP_DIR/xx-02-libreoffice-writer.desktop"
    chmod +x "$DESKTOP_DIR/xx-02-libreoffice-writer.desktop"
fi

# — LibreOffice Calc
if [ -f /usr/share/applications/libreoffice-calc.desktop ]; then
    cp /usr/share/applications/libreoffice-calc.desktop "$DESKTOP_DIR/xx-03-libreoffice-calc.desktop"
    chmod +x "$DESKTOP_DIR/xx-03-libreoffice-calc.desktop"
fi

# — LibreOffice Impress
if [ -f /usr/share/applications/libreoffice-impress.desktop ]; then
    cp /usr/share/applications/libreoffice-impress.desktop "$DESKTOP_DIR/xx-04-libreoffice-impress.desktop"
    chmod +x "$DESKTOP_DIR/xx-04-libreoffice-impress.desktop"
fi

# — VLC
if [ -f /usr/share/applications/vlc.desktop ]; then
    cp /usr/share/applications/vlc.desktop "$DESKTOP_DIR/xx-05-vlc.desktop"
    chmod +x "$DESKTOP_DIR/xx-05-vlc.desktop"
fi

# — Raccourci “Fichiers” (dossier personnel)
cat > "$DESKTOP_DIR/xx-06-fichiers.desktop" << EOF
[Desktop Entry]
Name=Fichiers
Comment=Ouvrir le dossier personnel
Exec=xdg-open "$USER_HOME"
Icon=folder
Terminal=false
Type=Application
Categories=Utility;
EOF
chmod +x "$DESKTOP_DIR/xx-06-fichiers.desktop"

# — Lanceur “Changer mon mot de passe” (cible cachée)
cat > "$DESKTOP_DIR/xx-07-changer-mdp.desktop" << EOF
[Desktop Entry]
Name=Changer mon mot de passe
Comment=Définir un nouveau mot de passe utilisateur
Exec=python3 "$SCRIPT_PATH"
Icon=dialog-password
Terminal=false
Type=Application
Categories=Utility;
EOF
chmod +x "$DESKTOP_DIR/xx-07-changer-mdp.desktop"

# ====================
# 5. Fond d’écran (depuis URL directe)
# ====================
mkdir -p "$USER_HOME/Images"

echo "[INFO] Téléchargement du fond d'écran…"
if wget -q -O "$FOND_ECRAN_PATH" "$FOND_ECRAN_URL"; then
    echo "[OK] Fond téléchargé."
    # Appliquer le fond (Cinnamon)
    gsettings set org.cinnamon.desktop.background picture-uri "file://$FOND_ECRAN_PATH" 2>/dev/null || true
    # Certaines versions ont aussi picture-uri-dark
    gsettings set org.cinnamon.desktop.background picture-uri-dark "file://$FOND_ECRAN_PATH" 2>/dev/null || true
else
    echo "[WARN] Échec de téléchargement du fond d’écran."
fi

# ====================
# 6. Paramètres de Bureau (Nemo) : tri inversé + grille
# ====================
# Activer l’affichage des icônes par Nemo (au cas où)
gsettings set org.nemo.desktop show-desktop-icons true

# Tri par nom en ordre inversé (Z→A) pour les vues Nemo
gsettings set org.nemo.preferences default-sort-order 'name'
gsettings set org.nemo.preferences default-sort-in-reverse-order true

# Grille d’alignement (pour un rendu propre)
gsettings set org.nemo.desktop use-desktop-grid true

# (Optionnel) Masquer l’icône système "Corbeille" de Nemo pour éviter le doublon
# gsettings set org.nemo.desktop trash-icon-visible false

# ====================
# 7. Permissions
# ====================
chown "$USER_NAME:$USER_NAME" "$SCRIPT_PATH" 2>/dev/null || true
[ -f "$FOND_ECRAN_PATH" ] && chown "$USER_NAME:$USER_NAME" "$FOND_ECRAN_PATH" 2>/dev/null || true
chown -R "$USER_NAME:$USER_NAME" "$DESKTOP_DIR"

# ====================
# 8. Vider la corbeille (utilisateur)
# ====================
echo "[INFO] Vidage de la corbeille…"
if command -v gio >/dev/null 2>&1; then
    gio trash --empty || true
else
    rm -rf "$HOME/.local/share/Trash/files/"* "$HOME/.local/share/Trash/info/"* 2>/dev/null || true
fi


echo "[FINI] Installation terminée."
