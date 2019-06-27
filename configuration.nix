{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  fileSystems = {
    # SSD
    "/".options = [ "noatime" "nodiratime" ];
    "/home".options = [ "noatime" "nodiratime" ];

    # HDD
    "/media/data".options = [ "noatime" "nodiratime" "defaults" ];
  };

  boot = {
    loader.grub = {
      enable = true;
      version = 2;
      useOSProber = false;
      device = "/dev/sdb";
    };
    
    cleanTmpDir = true;
    kernelPackages = pkgs.linuxPackages_5_1;
  };

  i18n = {
    consoleFont = "Lat2-Terminus16";
    consoleKeyMap = "us";
    defaultLocale = "en_US.UTF-8";

    supportedLocales = [
      "en_US.UTF-8/UTF-8"
      "ja_JP.UTF-8/UTF-8"
    ];

    inputMethod.enabled = "ibus";
    inputMethod.ibus.engines = [ pkgs.ibus-engines.mozc ];
  };

  time.timeZone = "America/Los_Angeles";
  
  fonts.fonts = with pkgs; [
    google-fonts
    dejavu_fonts
    noto-fonts-cjk
  ];

  nixpkgs.config = {
    allowUnfree = true;
    packageOverrides = import ./overlays/overlay.nix pkgs;

    android_sdk.accept_license = true;
  };
  
  environment = {
    systemPackages = with pkgs; [
      # Core Applications
      firefox-bin
      alacritty
      ranger
      mpv
      vscode
      git
      deluge
      rustup
      wine
      gnome3.gnome-system-monitor
      gnome3.eog
      veracrypt
      soulseekqt
      lollypop
        
      # Misc Applications
      ripgrep # Improved version of grep
      psmisc # killall
      pywal
      gnome3.networkmanagerapplet
      feh
      atool
      gnupg1
      python3
      numlockx
      binutils
      mediainfo
      libcaca
      highlight
      file
      notify-osd
      pavucontrol
      winetricks
      youtube-dl
      ffmpeg
      rpcs3
      the-powder-toy
      qemu
      srm
      puddletag

      # Compression
      unzip
      unrar
      p7zip
      zlib
        
      # Themes
      arc-icon-theme
      arc-theme
      gnome3.adwaita-icon-theme
    ] ++ [
      # Overlay packages
      dxvk
      d9vk
      bcnotif
      anup
      wpfxm
      nixup
      vapoursynth-plugins
    ];

    variables.PATH = [ "/home/jonathan/.cargo/bin" ];
    variables.TERM = "alacritty";
  };
  
  programs = {
    fish.enable = true;
    adb.enable = true;
    firejail.enable = true;

    # lollypop needs this in order to save settings
    dconf.enable = true;
  };

  services = {
    fstrim.enable = true;

    compton = {
      enable = true;
      backend = "glx";
      vSync = true;
        
      extraOptions = ''
        unredir-if-possible = true;
        use-damage = true;

        glx-no-stencil = true;

        blur-background = true;
        blur-background-fixed = true;
        blur-kern = "7x7box";

        blur-background-exclude = [
            "!window_type = 'dock' &&
                !window_type = 'popup_menu' &&
                !class_g = 'Alacritty'"
        ];
      '';
    };

    redshift = {
      enable = true;
      latitude = "38.58";
      longitude = "-121.49";
      temperature.night = 2400;
    };

    xserver = {
      enable = true;
      layout = "us";
      dpi = 161;
      videoDrivers = [ "nvidiaBeta" ];

      desktopManager = {
        default = "none";
        xterm.enable = false;
      };

      displayManager.lightdm = {
        enable = true;
        autoLogin.enable = true;
        autoLogin.user = "jonathan";
      };

      windowManager = {
        awesome = {
          enable = true;
          luaModules = with pkgs.luaPackages; [
            luafilesystem
          ];
        };

        default = "awesome";
      };

      # Monitor sleep times
      serverFlagsSection = ''
        Option "BlankTime" "15"
        Option "StandbyTime" "16"
        Option "SuspendTime" "16"
        Option "OffTime" "16"
      '';
    };

    # This is required for lollypop to scrobble to services like last.fm
    gnome3.gnome-keyring.enable = true;

    sshd.enable = true;
    searx.enable = true;
  };

  networking = {
    firewall = {
      enable = true;

      # Open these ports when connected to a VPN
      interfaces.tun0 = {
        allowedTCPPorts = [ 5504 20546 ];
      };
    };

    enableIPv6 = false;
    hostName = "jonathan-desktop";

    networkmanager.enable = true;

    # Block ads / tracking from desktop applications
    # This mainly serves as a backup incase I can't use my Pi-hole
    hosts."0.0.0.0" = [
      # Firefox
      "location.services.mozilla.com"
      "shavar.services.mozilla.com"
      "incoming.telemetry.mozilla.org"
      "ocsp.sca1b.amazontrust.com"

      # Unity games
      "config.uca.cloud.unity3d.com"
      "api.uca.cloud.unity3d.com"
      "cdp.cloud.unity3d.com"

      # Unreal Engine 4 (not sure if games actually connect to these)
      "tracking.epicgames.com"
      "tracking.unrealengine.com"

      # Redshell (game analytics)
      "api.redshell.io"
      "treasuredata.com"
      "api.treasuredata.com"
      "in.treasuredata.com"

      # GameAnalytics
      "api.gameanalytics.com"
      "rubick.gameanalytics.com"

      # General
      "www.google-analytics.com"
      "ssl.google-analytics.com"
      "www.googletagmanager.com"
      "www.googletagservices.com"
    ];
  };

  sound.enable = true;

  hardware = {
    cpu.amd.updateMicrocode = true;
    opengl.driSupport32Bit = true;
    pulseaudio.enable = true;
  };

  users.extraUsers.jonathan = {
    isNormalUser = true;
    home = "/home/jonathan";
    description = "Jonathan";
    extraGroups = [ "wheel" "networkmanager" "adbusers" ];
    shell = "/run/current-system/sw/bin/fish";
  };
}
