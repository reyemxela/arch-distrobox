FROM quay.io/toolbx/arch-toolbox AS arch-distrobox

# Pacman Initialization
# Create build user
RUN sed -i 's/#Color/Color/g' /etc/pacman.conf && \
    printf "[multilib]\nInclude = /etc/pacman.d/mirrorlist\n" | tee -a /etc/pacman.conf && \
    sed -i 's/#MAKEFLAGS="-j2"/MAKEFLAGS="-j$(nproc)"/g' /etc/makepkg.conf && \
    pacman -Syu --noconfirm && \
    pacman -S \
        wget \
        base-devel \
        git \
        --noconfirm && \
    useradd -m --shell=/bin/bash build && usermod -L build && \
    echo "build ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    echo "root ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Distrobox Integration
USER build
WORKDIR /home/build
RUN git clone https://github.com/KyleGospo/xdg-utils-distrobox-arch.git --single-branch && \
    cd xdg-utils-distrobox-arch/trunk && \
    makepkg -si --noconfirm && \
    cd ../.. && \
    rm -drf xdg-utils-distrobox-arch
USER root
WORKDIR /
RUN git clone https://github.com/89luca89/distrobox.git --single-branch /tmp/distrobox && \
    cp /tmp/distrobox/distrobox-host-exec /usr/bin/distrobox-host-exec && \
    ln -s /usr/bin/distrobox-host-exec /usr/bin/flatpak && \
    ln -s /usr/bin/distrobox-host-exec /usr/bin/tailscale && \
    ln -s /usr/bin/distrobox-host-exec /usr/bin/podman && \
    ln -s /usr/bin/distrobox-host-exec /usr/bin/rpm-ostree && \
    ln -s /usr/bin/distrobox-host-exec /usr/bin/distrobox && \
    wget https://github.com/1player/host-spawn/releases/download/$(cat /tmp/distrobox/distrobox-host-exec | grep host_spawn_version= | cut -d "\"" -f 2)/host-spawn-$(uname -m) -O /usr/bin/host-spawn && \
    chmod +x /usr/bin/host-spawn && \
    rm -drf /tmp/distrobox

COPY base-packages.txt / 
COPY extra-packages.txt /

# Distrobox base packages
RUN grep -v '^#' /base-packages.txt | xargs pacman -Syu --noconfirm --needed 

# Add paru and install AUR packages
USER build
WORKDIR /home/build
RUN git clone https://aur.archlinux.org/paru-bin.git --single-branch && \
    cd paru-bin && \
    makepkg -si --noconfirm && \
    cd .. && \
    rm -drf paru-bin && \
    grep -v '^#' /extra-packages.txt | xargs paru -Syu --noconfirm --needed

USER root
WORKDIR /

# Cleanup
RUN sed -i 's@#en_US.UTF-8@en_US.UTF-8@g' /etc/locale.gen && \
    echo "LANG=en_US.UTF-8" >> /etc/locale.conf && \
    locale-gen && \
    userdel -r build && \
    rm -drf /home/build && \
    sed -i '/build ALL=(ALL) NOPASSWD: ALL/d' /etc/sudoers && \
    sed -i '/root ALL=(ALL) NOPASSWD: ALL/d' /etc/sudoers && \
    rm -rf \
        /tmp/* \
        /var/cache/pacman/pkg/* \
        /base-packages.txt \
        /extra-packages.txt
