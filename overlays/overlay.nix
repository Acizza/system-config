self: super: let
  llvmNativeStdenv = super.impureUseNativeOptimizations super.llvmPackages_latest.stdenv;
  gcc9NativeStdenv = super.impureUseNativeOptimizations super.gcc9Stdenv;
  multiNativeStdenv = super.impureUseNativeOptimizations super.multiStdenv;

  withFlags = pkg: flags:
    pkg.overrideAttrs (old: {
      NIX_CFLAGS_COMPILE = old.NIX_CFLAGS_COMPILE or "" +
        super.lib.concatMapStrings (x: " " + x) flags;
    });

  withStdenv = newStdenv: pkg:
    pkg.override { stdenv = newStdenv; };

  withStdenvAndFlags = newStdenv: pkg:
    withFlags (withStdenv newStdenv pkg);

  with32BitNativeAndFlags = withStdenvAndFlags super.pkgsi686Linux.stdenv;
  withLLVMNative = withStdenv llvmNativeStdenv;
  withLLVMNativeAndFlags = withStdenvAndFlags llvmNativeStdenv;
  withGCC9NativeAndFlags = withStdenvAndFlags gcc9NativeStdenv;

  withRustNative = pkg: pkg.overrideAttrs (old: {
    RUSTFLAGS = old.RUSTFLAGS or "" + " -C target-cpu=native";
  });

  withRustNativeAndPatches = pkg: patches: pkg.overrideAttrs (old: {
    patches = old.patches or [] ++ patches;
    RUSTFLAGS = old.RUSTFLAGS or "" + " -C target-cpu=native";
  });
in {
  qemu = super.qemu.override {
    hostCpuOnly = true;
    smbdSupport = true;
  };

  sudo = super.sudo.override {
    withInsults = true;
  };

  winetricks = super.winetricks.override {
    wine = self.wine;
  };

  # Latest Wine staging with FAudio
  wine = ((super.wine.override {
    # Note: we cannot set wineRelease to staging here, as it will no longer allow us
    # to use overrideAttrs
    wineBuild = "wineWow";

    # https://github.com/NixOS/nixpkgs/issues/28486#issuecomment-324859956
    gstreamerSupport = false;
  }).overrideAttrs (oldAttrs: rec {
    version = "4.11";

    src = super.fetchurl {
      url = "https://dl.winehq.org/wine/source/4.x/wine-${version}.tar.xz";
      sha256 = "1rmyfwlynzs2niz7l2lwjs2axm6in6gb43ldbzyzsflxsmk5fl9f";
    };

    staging = super.fetchFromGitHub {
      owner = "wine-staging";
      repo = "wine-staging";
      rev = "v${version}";
      sha256 = "0h8qldqr9w1kwn48qgg5m1cs2xqkv8xxg2c66cvfka91hy886jcf";
    };

    # TODO: remove when NixOS packages FAudio and the Wine version is >= 4.3
    buildInputs = oldAttrs.buildInputs ++ [ self.faudio self.faudio_32 ];

    # This saves a bit of build time
    configureFlags = oldAttrs.configureFlags or [] ++ [ "--disable-tests" ];

    NIX_CFLAGS_COMPILE = "-O3 -march=native -fomit-frame-pointer";
  })).overrideDerivation (drv: {
    name = "wine-wow-${drv.version}-staging";

    buildInputs = drv.buildInputs ++ [ super.perl super.utillinux super.autoconf super.libtxc_dxtn_s2tc ];

    postPatch = ''
      # staging patches
      patchShebangs tools
      cp -r ${drv.staging}/patches .
      chmod +w patches
      cd patches
      patchShebangs gitapply.sh
      ./patchinstall.sh DESTDIR="$PWD/.." --all \
          -W xaudio2-revert \
          -W xaudio2_7-CreateFX-FXEcho \
          -W xaudio2_7-WMA_support \
          -W xaudio2_CommitChanges
      cd ..
    '';
  });

  # Latest version of RPCS3 + compilation with clang
  rpcs3 = (super.rpcs3.override {
    waylandSupport = false;
    alsaSupport = false;

    stdenv = super.llvmPackages_latest.stdenv;
  }).overrideAttrs (oldAttrs: rec {
    name = "rpcs3-${version}";

    commit = "790962425cfb893529f72b3ef0dd1424fcc42973";
    gitVersion = "8187-${builtins.substring 0 7 commit}";
    version = "0.0.6-${gitVersion}";

    src = super.fetchgit {
      url = "https://github.com/RPCS3/rpcs3";
      rev = "${commit}";
      sha256 = "154ys29b9xdws3bp4b7rb3kc0h9hd49g2yf3z9268cdq8aclahaa";
    };

    # https://github.com/NixOS/nixpkgs/commit/b11558669ebc7472ecaaaa7cafa2729a22b37c17
    # RPCS3 no longer detects Vulkan due to the above commit
    buildInputs = oldAttrs.buildInputs ++ [ super.vulkan-headers ];

    cmakeFlags = oldAttrs.cmakeFlags ++ [
      "-DUSE_DISCORD_RPC=OFF"
      "-DUSE_NATIVE_INSTRUCTIONS=ON"
    ];

    patches = oldAttrs.patches or [] ++ [
      ./patches/rpcs3_clang.patch
    ];

    preConfigure = ''
      cat > ./rpcs3/git-version.h <<EOF
      #define RPCS3_GIT_VERSION "${gitVersion}"
      #define RPCS3_GIT_BRANCH "HEAD"
      #define RPCS3_GIT_VERSION_NO_UPDATE 1
      EOF
    '';

    NIX_CFLAGS_COMPILE = oldAttrs.NIX_CFLAGS_COMPILE or "" + " -O3 -pthread";
  });

  the-powder-toy = (super.the-powder-toy.override {
    stdenv = llvmNativeStdenv;
  }).overrideAttrs (oldAttrs: rec {
    name = "the-powder-toy-${version}";
    version = "94.1";

    src = super.fetchFromGitHub {
      owner = "simtr";
      repo = "The-Powder-Toy";
      rev = "v${version}";
      sha256 = "0w3i4zjkw52qbv3s9cgcwxrdbb1npy0ka7wygyb76xcb17bj0l0b";
    };

    buildInputs = oldAttrs.buildInputs ++ [ super.SDL2 ];

    NIX_CFLAGS_COMPILE = oldAttrs.NIX_CFLAGS_COMPILE + " -Ofast -flto";
  });

  # lollypop seems to need glib-networking in order to make HTTP(S) requests
  lollypop = super.lollypop.overrideAttrs (old: {
    buildInputs = old.buildInputs ++ [ super.glib-networking ];
  });

  soulseekqt = super.soulseekqt.overrideAttrs (oldAttrs: {
    buildInputs = oldAttrs.buildInputs ++ [ super.makeWrapper ];

    fixupPhase = oldAttrs.fixupPhase or "" + ''
      wrapProgram "$out/bin/SoulseekQt" \
        --prefix QT_PLUGIN_PATH : ${super.qt5.qtbase}/${super.qt5.qtbase.qtPluginPrefix}
    '';
  });

  vscode = super.vscode.overrideAttrs (oldAttrs: rec {
    version = "1.35.1";

    src = super.fetchurl {
      url = "https://github.com/VSCodium/vscodium/releases/download/${version}/VSCodium-linux-x64-${version}.tar.gz";
      sha256 = "0577lqpfrjgwbj27hm59kflb558mkl2nx00ys0hwndayqv0bfnvg";
    };

    unpackPhase = ''
      tar xvf ${src}
    '';

    patchPhase = oldAttrs.patchPhase or "" + ''
      mv bin/codium bin/code
    '';
  });

  ### Modifications to make some packages run as fast as possible

  awesome = withLLVMNativeAndFlags super.awesome [ "-O3" "-flto" ];
  lua = withGCC9NativeAndFlags super.lua [ "-O3" ];

  alacritty = withRustNativeAndPatches super.alacritty [ ./patches/alacritty.patch ];
  ripgrep = withRustNativeAndPatches super.ripgrep [ ./patches/ripgrep.patch ];

  mpv = let
    mpvPkg = super.mpv.override {
      vapoursynthSupport = true;
    };
  in withLLVMNativeAndFlags mpvPkg [ "-O3" "-flto" ];

  vapoursynth = withLLVMNativeAndFlags super.vapoursynth [ "-O3" "-flto" ];
  vapoursynth-mvtools = withLLVMNativeAndFlags super.vapoursynth-mvtools [ "-O3" "-flto" ];

  vapoursynth-plugins = super.buildEnv {
    name = "vapoursynth-plugins";
    paths = [ self.vapoursynth-mvtools ];
    pathsToLink = [ "/lib" ];
  };

  ### Custom packages

  anup = withRustNative (super.callPackage ./pkgs/anup.nix { });
  bcnotif = withRustNative (super.callPackage ./pkgs/bcnotif.nix { });
  wpfxm = withRustNative (super.callPackage ./pkgs/wpfxm.nix { });
  nixup = withRustNative (super.callPackage ./pkgs/nixup.nix { });

  dxvk = let
    pkg = super.callPackage ./pkgs/dxvk {
      multiStdenv = multiNativeStdenv;
    };
  in withFlags pkg [ "-Ofast" ];

  d9vk = let
    pkg = super.callPackage ./pkgs/d9vk {
      multiStdenv = multiNativeStdenv;
    };
  in withFlags pkg [ "-Ofast" ];

  faudio = withLLVMNativeAndFlags (super.callPackage ./pkgs/faudio.nix { }) [ "-O3" ];
  faudio_32 = with32BitNativeAndFlags (super.pkgsi686Linux.callPackage ./pkgs/faudio.nix { }) [ "-O3" ];
}
