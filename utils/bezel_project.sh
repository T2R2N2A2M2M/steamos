#!/usr/bin/env bash
# TODO
# Make sure ROMs is using NO-Intro rom naming convension
# right now testing on emudeck installed retroarch
# add config to game override for setting like opacity 1, hide in menu, etc
# use other thing rather than dialog to avoid install more tihings through pacman or AUR
# remove imgp as dependencies
# what's video_fullscreen????????
# ask for directory path to anything so non emudeck user can use too
# ask if want overlay behind menu
# ask if want to hide in menu
# ask if wnat to enable overlay after initial install
# option to disble/enable overlay after been installed
# option to list game that doesn't have bezel
# add note that the bezel will fit only on 16:9 screen. Force resolution in game property in game mode to 720p or 1080p for bezel to fit properly as I ran the rom through ES-DE. Also need to enable `Set resolution for internal and external display`

RETROARCH_CONFIG_DIR="${HOME}/.var/app/org.libretro.RetroArch/config/retroarch"
OVERLAY_DIR="${RETROARCH_CONFIG_DIR}/overlays"
HEIGHT="15"
WIDTH="55"
RES="640x360"

###############################################################################
# INTRO / WELCOME

dialog --clear \
  --backtitle "The Bezel Project" \
  --title "The Bezel Project - Bezel Pack Utility" \
  --yesno "\nWelcome to The Bezel Project Bezel Utility for Steam Deck.\n
This utility will provide a downloader for RetroArch system bezel packs.\n
These bezel packs rely on ROMs named according to No-Intro or similar sets.\n
Downloaded packs include config files referencing overlays to show them in RetroArch.\n
When new packs appear, use 'Update install script' to see new additions.\n
\nDo you want to proceed?" \
  25 80 2>&1 >/dev/tty || exit

###############################################################################
# MAIN MENU

function main_menu() {
    local choice
    while true; do
        choice=$(dialog --backtitle "The Bezel Project" \
            --title " MAIN MENU " \
            --ok-label OK --cancel-label Exit \
            --menu "What action would you like to perform?" 20 70 10 \
            1 "Update install script - script will exit when updated" \
            2 "Download theme-style bezel pack" \
            3 "Download system-style bezel pack" \
            4 "Info: RetroArch cores setup for bezels per system" \
            5 "Uninstall the bezel project completely" \
            2>&1 >/dev/tty)
        case "$choice" in
            1) update_script ;;
            2) download_bezel ;;
            3) download_bezelsa ;;
            4) retroarch_bezelinfo ;;
            5) removebezelproject ;;
            *)  break ;;
        esac
    done
}

###############################################################################
# UPDATE SCRIPT

function update_script() {
    # Simply re-download this script from your chosen GitHub or personal fork
    local SCRIPT_URL="https://raw.githubusercontent.com/christianhaitian/BezelProject-for-rk3326/master/bezelproject.sh"
    
    # Move the current script as backup
    SCRIPT_PATH="$( cd -- "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 ; pwd -P )"
    mv "${SCRIPT_PATH}/$(basename $0)" "${SCRIPT_PATH}/bezelproject_steamdeck.sh.bkp"

    wget -t 3 -T 60 -q --show-progress "$SCRIPT_URL" 2>&1 | stdbuf -oL sed -E 's/\.\.+/---/g' \
        | dialog --progressbox "Downloading and installing updated script..." $HEIGHT $WIDTH

    # Make the new file executable
    mv -f "$(basename $SCRIPT_URL)" "${SCRIPT_PATH}/$(basename $0)"
    chmod +x "${SCRIPT_PATH}/$(basename $0)"

    dialog --backtitle "The Bezel Project" \
           --title "Script updated" \
           --msgbox "\nThe script has been updated.\nPlease re-run it." 8 40

    exit
}

###############################################################################
# INSTALL / UNINSTALL HELPER FUNCTIONS

function install_bezel_pack() {
    local theme="$1"
    local repo="$2"
    [ -z "$repo" ] && repo="thebezelproject"

    # 1) Clone the pack
    git clone --depth 1 "https://github.com/${repo}/bezelproject-${theme}.git" "/tmp/${theme}" 2>&1
    if [ "$?" != "0" ]; then
        dialog --msgbox "Error cloning the ${theme} pack. Check space or network." 8 50
        rm -rf "/tmp/${theme}"
        return
    fi

    # 2) Modify .cfg references from RetroPie path to our $OVERLAY_DIR
    find "/tmp/${theme}/retroarch/config/" -type f -name "*.cfg" -print0 | while IFS= read -r -d '' file; do
        # Original scripts used /opt/retropie/configs/all/retroarch/overlay
        # We'll point them to $OVERLAY_DIR instead
        sed -i "s+/opt/retropie/configs/all/retroarch/overlay+${OVERLAY_DIR}+g" "$file"
        # Force fullscreen in each config
        echo 'video_fullscreen = "true"' >> "$file"
        # New config option
        echo 'input_overlay_behind_menu = "true"' >> "$file"
        echo 'input_overlay_enable = "true"' >> "$file"
        echo 'input_overlay_hide_in_menu = "false"' >> "$file"
        echo 'input_overlay_opacity = "1.000000"' >> "$file"
        
    done

    # 3) Set the global retroarch.cfg overlay directory (once)
    sed -i "/overlay_directory \=/c\overlay_directory \= \"${OVERLAY_DIR}\"" "${RETROARCH_CONFIG_DIR}/retroarch.cfg"

    # 4) (Optional) Resize images with imgp if installed
    if command -v imgp >/dev/null 2>&1; then
        imgp -x ${RES} -wr "/tmp/${theme}/retroarch/overlay/" | \
         stdbuf -oL sed -E 's/\.\.+/---/g' | \
         dialog --progressbox "Resizing ${theme} bezel pack images..." $HEIGHT $WIDTH
    fi

    # 5) Copy Overlays + Config
    cp -rv "/tmp/${theme}/retroarch/overlay/"* "${OVERLAY_DIR}/" 2>&1 \
       | stdbuf -oL sed -E 's/\.\.+/---/g' \
       | dialog --progressbox "Copying ${theme} overlays to ${OVERLAY_DIR}..." $HEIGHT $WIDTH

    cp -rv "/tmp/${theme}/retroarch/config/" "${RETROARCH_CONFIG_DIR}/" 2>&1 \
       | stdbuf -oL sed -E 's/\.\.+/---/g' \
       | dialog --progressbox "Copying ${theme} configs to ${RETROARCH_CONFIG_DIR}..." $HEIGHT $WIDTH

    rm -rf "/tmp/${theme}"
}

function install_bezel_packsa() {
    # For the 'system-style' repos (bezelprojectsa-xxx)
    local theme="$1"
    local repo="$2"
    [ -z "$repo" ] && repo="thebezelproject"

    git clone --depth 1 "https://github.com/${repo}/bezelprojectsa-${theme}.git" "/tmp/${theme}" 2>&1
    if [ "$?" != "0" ]; then
        dialog --msgbox "Error cloning the ${theme} pack. Check space or network." 8 50
        rm -rf "/tmp/${theme}"
        return
    fi

    find "/tmp/${theme}/retroarch/config/" -type f -name "*.cfg" -print0 | while IFS= read -r -d '' file; do
        sed -i "s+/opt/retropie/configs/all/retroarch/overlay+${OVERLAY_DIR}+g" "$file"
        echo 'video_fullscreen = "true"' >> "$file"
    done

    sed -i "/overlay_directory \=/c\overlay_directory \= \"${OVERLAY_DIR}\"" "${RETROARCH_CONFIG_DIR}/retroarch.cfg"

    if command -v imgp >/dev/null 2>&1; then
        imgp -x ${RES} -wr "/tmp/${theme}/retroarch/overlay/" | \
         stdbuf -oL sed -E 's/\.\.+/---/g' | \
         dialog --progressbox "Resizing ${theme} bezel pack images..." $HEIGHT $WIDTH
    fi

    cp -rv "/tmp/${theme}/retroarch/overlay/"* "${OVERLAY_DIR}/" 2>&1 \
       | stdbuf -oL sed -E 's/\.\.+/---/g' \
       | dialog --progressbox "Copying ${theme} overlays to ${OVERLAY_DIR}..." $HEIGHT $WIDTH

    cp -rv "/tmp/${theme}/retroarch/config/" "${RETROARCH_CONFIG_DIR}/" 2>&1 \
       | stdbuf -oL sed -E 's/\.\.+/---/g' \
       | dialog --progressbox "Copying ${theme} configs to ${RETROARCH_CONFIG_DIR}..." $HEIGHT $WIDTH

    rm -rf "/tmp/${theme}"
}

function uninstall_bezel_pack() {
    # This function is more minimal vs. the original, but you can expand
    # if you want to track which config directories to remove.
    local theme="$1"

    # We do not maintain a special overlay subfolder for each theme in this minimal version,
    # so you may need more advanced logic if you want partial uninstalls.
    # Below is a naive approach:

    dialog --infobox "\nRemoving overlay configs for ${theme}...\n" 6 40
    # Example: remove any config folder matching the theme:
    rm -rf "${RETROARCH_CONFIG_DIR}/config/${theme}"

    # If you had a separate subfolder in overlay for each theme, remove that:
    rm -rf "${OVERLAY_DIR}/${theme}"

    # In the advanced script, there's also a text file `all_emulators.txt` to track everything.
    # If you want that method, reintroduce it as needed.
}

function removebezelproject() {
    # Full wipe of all installed bezel packs from The Bezel Project
    dialog --infobox "\nRemoving all installed bezel overlays and config overrides...\n" 8 50
    rm -rf "${OVERLAY_DIR}/GameBezels"
    rm -rf "${OVERLAY_DIR}/ArcadeBezels"
    # Potentially remove the entire overlay folder if you only used it for BezelProject:
    # rm -rf "${OVERLAY_DIR}/*"

    # Also remove any configs that were installed for these bezels (naive approach):
    # For example, remove entire retroarch/config subdirs that match known cores.
    # or remove references from 'all_emulators.txt' if used.

    dialog --msgbox "Bezel Project overlays removed.\n" 6 40
}

###############################################################################
# MENU FUNCTIONS - THEME STYLE (bezelproject-xxx) & SYSTEM STYLE (bezelprojectsa-xxx)

function download_bezel() {
    # "Theme style" packs from thebezelproject-XXXX
    local themes=(
        'thebezelproject Amiga'
        'thebezelproject Atari2600'
        'thebezelproject Atari5200'
        'thebezelproject Atari7800'
        'thebezelproject AtariJaguar'
        'thebezelproject AtariLynx'
        'thebezelproject Atomiswave'
        'thebezelproject C64'
        'thebezelproject CD32'
        'thebezelproject CDTV'
        'thebezelproject ColecoVision'
        'thebezelproject Dreamcast'
        'thebezelproject FDS'
        'thebezelproject Famicom'
        'thebezelproject GB'
        'thebezelproject GBA'
        'thebezelproject GBC'
        'thebezelproject GCEVectrex'
        'thebezelproject GameGear'
        'thebezelproject Intellivision'
        'thebezelproject MAME'
        'thebezelproject MSX'
        'thebezelproject MSX2'
        'thebezelproject MasterSystem'
        'thebezelproject MegaDrive'
        'thebezelproject N64'
        'thebezelproject NDS'
        'thebezelproject NES'
        'thebezelproject NGP'
        'thebezelproject NGPC'
        'thebezelproject Naomi'
        'thebezelproject PCE-CD'
        'thebezelproject PCEngine'
        'thebezelproject PSX'
        'thebezelproject SFC'
        'thebezelproject SG-1000'
        'thebezelproject SNES'
        'thebezelproject Saturn'
        'thebezelproject Sega32X'
        'thebezelproject SegaCD'
        'thebezelproject SuperGrafx'
        'thebezelproject TG-CD'
        'thebezelproject TG16'
        'thebezelproject Videopac'
        'thebezelproject Virtualboy'
    )

    while true; do
        local options=()
        local i=1
        for t in "${themes[@]}"; do
            local reponame="${t%% *}"
            local themename="${t##* }"
            options+=("${i}" "Install/Update ${themename}")
            ((i++))
        done

        local choice=$(dialog --backtitle "The Bezel Project" \
            --title "Choose a theme-style bezel pack" \
            --menu "Select a bezel pack to install or update." 22 70 16 \
            "${options[@]}" \
            2>&1 >/dev/tty)

        [ -z "$choice" ] && break
        local arrindex=$((choice-1))
        local reponame="${themes[$arrindex]%% *}"
        local themename="${themes[$arrindex]##* }"

        # Example: If you also want an uninstall sub-option:
        # ... you can do a separate mini-menu. For simplicity, we directly install:
        install_bezel_pack "${themename}" "${reponame}"
    done
}

function download_bezelsa() {
    # "System style" packs from thebezelprojectsa-XXXX
    local themes=(
        'thebezelproject Amiga'
        'thebezelproject AmstradCPC'
        'thebezelproject Atari2600'
        'thebezelproject Atari5200'
        'thebezelproject Atari7800'
        'thebezelproject Atari800'
        'thebezelproject AtariJaguar'
        'thebezelproject AtariLynx'
        'thebezelproject AtariST'
        'thebezelproject Atomiswave'
        'thebezelproject C64'
        'thebezelproject CD32'
        'thebezelproject CDTV'
        'thebezelproject ColecoVision'
        'thebezelproject Dreamcast'
        'thebezelproject FDS'
        'thebezelproject Famicom'
        'thebezelproject GB'
        'thebezelproject GBA'
        'thebezelproject GBC'
        'thebezelproject GCEVectrex'
        'thebezelproject GameGear'
        'thebezelproject Intellivision'
        'thebezelproject MAME'
        'thebezelproject MSX'
        'thebezelproject MSX2'
        'thebezelproject MasterSystem'
        'thebezelproject MegaDrive'
        'thebezelproject N64'
        'thebezelproject NDS'
        'thebezelproject NES'
        'thebezelproject NGP'
        'thebezelproject NGPC'
        'thebezelproject PCE-CD'
        'thebezelproject PCEngine'
        'thebezelproject PSX'
        'thebezelproject Pico'
        'thebezelproject SFC'
        'thebezelproject SG-1000'
        'thebezelproject SNES'
        'thebezelproject Saturn'
        'thebezelproject Sega32X'
        'thebezelproject SegaCD'
        'thebezelproject SuperGrafx'
        'thebezelproject TG-CD'
        'thebezelproject TG16'
        'thebezelproject Videopac'
        'thebezelproject Virtualboy'
        'thebezelproject WonderSwan'
        'thebezelproject WonderSwanColor'
        'thebezelproject X68000'
        'thebezelproject ZX81'
        'thebezelproject ZXSpectrum'
    )

    while true; do
        local options=()
        local i=1
        for t in "${themes[@]}"; do
            local reponame="${t%% *}"
            local themename="${t##* }"
            options+=("${i}" "Install/Update ${themename}")
            ((i++))
        done

        local choice=$(dialog --backtitle "The Bezel Project" \
            --title "Choose a system-style bezel pack" \
            --menu "Select a bezel pack to install or update." 22 70 16 \
            "${options[@]}" \
            2>&1 >/dev/tty)

        [ -z "$choice" ] && break
        local arrindex=$((choice-1))
        local reponame="${themes[$arrindex]%% *}"
        local themename="${themes[$arrindex]##* }"

        install_bezel_packsa "${themename}" "${reponame}"
    done
}

###############################################################################
# INFO DISPLAY

function retroarch_bezelinfo() {
    # Display a text file with core->system mapping. This is adapted from the original script.
    cat << EOF > /tmp/bezelprojectinfo.txt
The Bezel Project is set up with the following system-to-core mapping.

For each game bezel, RetroArch must have an override config file. These overrides
are placed in subdirectories named according to the RetroArch core that each system uses.

Below is a reference table for which emulator cores are typically used by each system
if you want these overlays to work automatically.

-------------------------------------------------------------
 System                                          Emulator/Core
-------------------------------------------------------------
 Amstrad CPC                                     lr-caprice32
 Atari 800                                       lr-atari800
 Atari 2600                                      lr-stella
 Atari 5200                                      lr-atari800
 Atari 7800                                      lr-prosystem
 Atari Jaguar                                    lr-virtualjaguar
 Atari Lynx                                      lr-handy, lr-beetle-lynx
 Atari ST                                        lr-hatari
 Bandai WonderSwan / Color                       lr-beetle-wswan
 ColecoVision                                    lr-bluemsx
 GCE Vectrex                                     lr-vecx
 MAME                                            lr-various
 Mattel Intellivision                            lr-freeintv
 MSX / MSX2                                      lr-fmsx, lr-bluemsx
 NEC PC Engine / CD / SuperGrafx / TG-16         lr-beetle-pce-fast, lr-beetle-supergrafx
 Nintendo 64                                     lr-mupen64plus
 Nintendo (NES, FDS, Famicom)                    lr-fceumm, lr-nestopia
 Nintendo DS                                     lr-desmume, lr-desmume2015
 Nintendo Game Boy / Color / Advance             lr-gambatte, lr-mgba
 Nintendo (S)Famicom, SNES                       lr-snes9x, lr-snes9x2010
 Nintendo Virtual Boy                            lr-beetle-vb
 Philips Videopac / Magnavox Odyssey2           lr-o2em
 Sammy Atomiswave                                lr-flycast
 Sega (SG-1000, Master System, Megadrive, 32X)   lr-genesis-plus-gx, lr-picodrive
 Sega CD / Pico                                  lr-genesis-plus-gx, lr-picodrive
 Sega Dreamcast / Naomi                          lr-flycast
 Sega Saturn                                     lr-yabause, lr-beetle-saturn
 Sharp X68000                                    lr-px68k
 Sinclair ZX-81 / ZX Spectrum                    lr-81, lr-fuse
 SNK Neo Geo Pocket / Color                      lr-beetle-ngp
 Sony PlayStation (PSX)                          lr-pcsx-rearmed
EOF

    dialog --backtitle "The Bezel Project" \
           --title "RetroArch Bezel Info" \
           --textbox /tmp/bezelprojectinfo.txt 30 100
    rm -f /tmp/bezelprojectinfo.txt
}

###############################################################################
# RUN SCRIPT

main_menu
clear
echo "Exited The Bezel Project script."

