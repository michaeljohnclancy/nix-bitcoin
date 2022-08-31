{ config, lib, pkgs, ...}:

with lib;
let
  options.services.teos = {
    enable = mkEnableOption "A Lightning watchtower compliant with BOLT13, written in Rust.";
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/teos";
      description = "The data directory for teos.";
    };
    address = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address to listen on.";
    };
    port = mkOption {
      type = types.port;
      default = 9814;
      description = "Port to listen on.";
    };
    torControlPort = mkOption {
      type = types.port;
      default = 9051;
      description = "Tor control port.";
    };
    onionHiddenServicePort = mkOption {
      type = types.port;
      default = 2121;
      description = "Tor Hidden service port.";
    }; 
    rpcBind = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address to listen on.";
    };
    rpcPort = mkOption {
      type = types.port;
      default = 8814;
      description = "Port to listen on.";
    };
    debugMode = mkOption {
      type = types.bool;
      default = false;
      description = "Run in debug mode.";
    };
    overwriteKey = mkOption {
      type = types.bool;
      default = false;
      description = "Overwrites the tower secret key. THIS IS IRREVERSIBLE AND WILL CHANGE YOUR TOWER ID";
    };
    subscriptionSlots = mkOption {
      type = types.int;
      default = 10000;
      description = "Number of possible subscriptions to this watchtower.";
    };
    subscriptionDuration = mkOption {
      type = types.int;
      default = 4320;
      description = "Duration of subscription, in {what unit?}";
    };
    expiryDelta = mkOption {
      type = types.int;
      default = 6;
      description = "?";
    };
    minToSelfDelay = mkOption {
      type = types.int;
      default = 20;
      description = "?";
    };
    pollingData = mkOption {
      type = types.int;
      default = 60;
      description = "?";
    };
    internalApiBind = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Internal Address to bind to.";
    };
    internalApiPort = mkOption {
      type = types.port;
      default = 50051;
      description = "Internal Port to bind to.";
    };
    user = mkOption {
      type = types.str;
      default = "teos";
      description = "The user as which to run electrs.";
    };
    group = mkOption {
      type = types.str;
      default = cfg.user;
      description = "The group as which to run electrs.";
    };
    tor.enforce = nbLib.tor.enforce;
  };
  
  cfg = config.services.teos;
  nbLib = config.nix-bitcoin.lib;
  secretsDir = config.nix-bitcoin.secretsDir;
  bitcoind = config.services.bitcoind;
in {
  inherit options;

  config = mkIf cfg.enable {
    assertions = [
      { assertion = bitcoind.txindex == true ;
        message = "teos needs txindex enabled to look for non-wallet transactions.";
      }
    ];

    services.bitcoind = {
      enable = true;
      listenWhitelisted = true;
    };

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0770 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.teos = {
      wantedBy = [ "multi-user.target" ];
      requires = [ "bitcoind.service" ];
      after = [ "bitcoind.service" ];
      preStart = ''
        cat > ${cfg.dataDir}/teos.toml <<- EOM
        btc_network = "${bitcoind.makeNetworkName "bitcoin" "regtest"}"
        btc_rpc_user = "${bitcoind.rpc.users.public.name}"
        btc_rpc_password = "$(cat ${secretsDir}/bitcoin-rpcpassword-public)"
        btc_rpc_connect = "${bitcoind.rpc.address}"
        btc_rpc_port = ${toString bitcoind.rpc.port}
        EOM
        '';
        serviceConfig = nbLib.defaultHardening // {
          WorkingDirectory = cfg.dataDir;
          ExecStart = ''
            ${config.nix-bitcoin.pkgs.teos}/bin/teosd \
            --datadir=${cfg.dataDir} \
            --apibind="${cfg.address}" \
            --apiport="${toString cfg.port}" \
            --torsupport=${toString cfg.tor.enforce}
            --torcontrolport=${toString cfg.torControlPort} \
            --onionhiddenserviceport=${toString cfg.onionHiddenServicePort} \
            --rpcbind="${cfg.rpcBind}" \
            --rpcport=${toString cfg.rpcPort} \
            --debug="${toString cfg.debugMode}" \
            --overwritekey="${toString cfg.overwriteKey}" \
            --subscriptionslots=${toString cfg.subscriptionSlots} \
            --subscriptionduration=${toString cfg.subscriptionDuration} \
            --expirydelta=${toString cfg.expiryDelta} \
            --mintoselfdelay=${toString cfg.minToSelfDelay} \
            --pollingdata=${toString cfg.pollingData} \
            --internalapibind=${cfg.internalApiBind} \
            --internalapiport=${toString cfg.internalApiPort} \
          '';
          User = cfg.user;
          Group = cfg.group;
          Restart = "on-failure";
          RestartSec = "10s";
          ReadWritePaths = [ cfg.dataDir ];
        } // nbLib.allowedIPAddresses cfg.tor.enforce;
    };

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      extraGroups = [ "bitcoinrpc-public" ];
    };
    users.groups.${cfg.group} = {};
  };
}



