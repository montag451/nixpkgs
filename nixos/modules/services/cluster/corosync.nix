{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.services.corosync;

  interfaceOptions = {
    options = {
      ringnumber = mkOption {
        type = types.int;
        default = 0;
        description = ''
          Specify the ring number for the interface.
        '';
      };
      bindnetaddr = mkOption {
        type = types.str;
        description = ''
          Specify the network address the corosync executive should bind to.
        '';
      };
      broadcast = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = ''
          Whether to use the broadcast address for communication.
        '';
      };
      mcastaddr = mkOption {
        type = types.str;
        description = ''
          Specify the multicast address used by the corosync executive.
        '';
      };
      mcastport = mkOption {
        type = types.int;
        description = ''
          Specify the UDP port number.
        '';
      };
      ttl = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = ''
          Specify the Time To Live (TTL).
        '';
      };
    };
  };

  logPriority = [ "alert" "crit" "debug" "emerg" "err" "info" "notice" "warning" ];

  loggingCommonOptions = {
    toStderr = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to log on stderr.
      '';
    };
    toLogfile = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to log on a file.
      '';
    };
    toSyslog = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to send logs to the syslog daemon.
      '';
    };
    logfile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Specify the path of the logfile.
      '';
    };
    logfilePriority = mkOption {
      type = types.enum logPriority;
      default = "info";
      description = ''
        Specify the logfile priority.
      '';
    };
    syslogFacility = mkOption {
      type = types.enum ([ "daemon" ] ++ map (i: "local${toString i}") (range 0 7));
      default = "daemon";
      description = ''
        Specify the syslog facility.
      '';
    };
    syslogPriority = mkOption {
      type = types.enum logPriority;
      default = "info";
      description = ''
        Specify the syslog priority.
      '';
    };
    debug = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to log debug messages.
      '';
    };
  };

  loggerSubsysOptions = {
    options = loggingCommonOptions // {
      subsys = mkOption {
        type = types.str;
        description = ''
          Specify the subsystem whose logging configuration will be modified.
        '';
      };
    };
  };

  nodeOptions = {
    options = {
      ringNumber = mkOption {
        type = types.int;
        description = ''
          Specify the ring number.
        '';
      };
      ipAddr = mkOption {
        type = types.str;
        description = ''
          Specify the IP address of the node.
        '';
      };
      nodeid = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = ''
          Specify the node ID.
        '';
      };
      quorumVotes = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = ''
          Specify the number of votes for this node.
        '';
      };
    };
  };

  boolToYesOrNo = b: if b then "yes" else "no";
  boolToOneOrZero = b: if b then "1" else "0";

  indent = s: if s == "" then "" else "  " + concatStringsSep "\n  " (splitString "\n" s);

  interfaceToString = def: ''
    interface {
      ringnumber: ${toString def.ringnumber}
      bindnetaddr: ${def.bindnetaddr}
      ${optionalString (def.broadcast != null) "  broadcast: ${def.broadcast}\n"}
      mcastaddr: ${def.mcastaddr}
      mcastport: ${toString def.mcastport}
  '' + optionalString (def.ttl != null) "  ttl: ${toString def.ttl}\n" + ''
    }
  '';

  totemToString = def: ''
    totem {
  '' + indent (concatMapStrings interfaceToString def.interfaces) + ''
    }
  '';

  loggingCommonToString = def: ''
    to_stderr: ${boolToYesOrNo def.toStderr} 
    to_logfile: ${boolToYesOrNo def.toLogfile} 
    to_syslog: ${boolToYesOrNo def.toSyslog} 
  '' + optionalString (def.logfile != null) "logfile: ${def.logfile}\n" + ''
    logfile_priority: ${def.logfilePriority}
    syslog_facility: ${def.syslogFacility}
    syslog_priority: ${def.syslogPriority}
    debug: ${boolToYesOrNo def.debug}
  '';

  loggerSubsysToString = def: ''
    logger_subsys {
      subsys: ${def.subsys}
  '' + indent (loggingCommonToString def) + ''
    }
  '';

  loggingToString = def: ''
    logging {
      timestamp: ${boolToYesOrNo def.timestamp}
      fileline: ${boolToYesOrNo def.fileline}
      function_name: ${boolToYesOrNo def.functionName}
  '' + indent (loggingCommonToString def)
     + indent (concatMapStrings loggerSubsysToString def.loggerSubsys) + ''
    }
  '';

  nodeToString = def: ''
    node {
      ring${toString def.ringNumber}_addr: ${def.ipAddr}
  '' + optionalString (def.nodeid != null) "  nodeid: ${toString def.nodeid}\n"
     + optionalString (def.quorumVotes != null) "  quorum_votes: ${toString def.quorumVotes}\n" + ''
    }
  '';

  nodeListToString = def: ''
    nodelist {
  '' + indent (concatMapStrings nodeToString def) + ''
    }
  '';

  quorumToString = def: ''
    quorum {
    '' + optionalString (def.provider != null) (indent ''
      provider: ${def.provider}
      '' + optionalString (def.expectedVotes != null) "  expected_votes: ${toString def.expectedVotes}\n" + indent ''
      two_node: ${boolToOneOrZero def.twoNode}
      wait_for_all: ${boolToOneOrZero def.waitForAll}
      last_man_standing: ${boolToOneOrZero def.lastManStanding}
      last_man_standing_window: ${toString def.lastManStandingWindow}
      auto_tie_breaker: ${boolToOneOrZero def.autoTieBreaker}
      auto_tie_breaker_node: ${
        if isList def.autoTieBreakerNode
        then concatMapStringsSep " " toString def.autoTieBreakerNode
        else toString def.autoTieBreakerNode
      }
      allow_downscale: ${boolToOneOrZero def.allowDownscale}
      expected_votes_tracking: ${boolToOneOrZero def.expectedVotesTracking}
    '') + ''
    }
  '';

  confToString = def: concatStringsSep "\n" [
    (totemToString def.totem)
    (nodeListToString def.nodelist)
    (quorumToString def.quorum)
    (loggingToString def.logging)
  ];

in

{

  options = {

    services.corosync = {

      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to enable corosync.
        '';
      };

      conf = mkOption {
        type = types.str;
        default = "";
        description = ''
          Specify the content of the configuration file.
        '';
      };

      totem = {

        version = mkOption {
          type = types.int;
          default = 2;
          description = ''
            Specify the version of the configuration file."
          '';
        };

        clearNodeHighBit = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Whether to ensure the nodeid is a signed 32 bits integer."
          '';
        };

        cryptoHash = mkOption {
          type = types.enum [ "none" "md5" "sha1" "sha384" "sha512" ];
          default = "sha1";
          description = ''
            Specify the hash function used for HMAC."
          '';
        };

        cryptoCipher = mkOption {
          type = types.enum [ "none" "3des" "aes128" "aes192" "aes256" ];
          default = "aes256";
          description = ''
            Specify the cipher used to encrypt all messages."
          '';
        };

        rrpMode = mkOption {
          type = types.enum [ "none" "active" "passive" ];
          default = "passive";
          description = ''
            Specify the mode of redundant ring."
          '';
        };

        netmtu = mkOption {
          type = types.int;
          default = 1500;
          description = ''
            Specify the network MTU."
          '';
        };

        transport = mkOption {
          type = types.enum [ "udp" "udpu" "iba" ];
          default = "udp";
          description = ''
            Specify the transport mechanism used."
          '';
        };

        clusterName = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            Specify the name of the cluster."
          '';
        };

        configVersion = mkOption {
          type = types.int;
          default = 0;
          description = ''
            Specify the version of the configuration file."
          '';
        };

        ipVersion = mkOption {
          type = types.enum [ "ipv4" "ipv6" ];
          default = "ipv4";
          description = ''
            Specify the version of the IP protocol to use."
          '';
        };

        token = mkOption {
          type = types.int;
          default = 1000;
          description = ''
            Specify the timeout in ms until token loss is declared after not receiving a token.
          '';
        };

        interfaces = mkOption {
          type = types.listOf (types.submodule interfaceOptions);
          default = [];
          description = ''
            List of interfaces.
          '';
        };

      };

      logging = loggingCommonOptions // {

        timestamp = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Whether to timestamp every log messages.
          '';
        };

        fileline = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Whether to log file and line.
          '';
        };

        functionName = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Whether to log function name.
          '';
        };

        loggerSubsys = mkOption {
          type = types.listOf (types.submodule loggerSubsysOptions);
          default = [];
          description = ''
            Specify log configuration for specific subsystems.
          '';
        };

      };

      nodelist = mkOption {
        type = types.listOf (types.submodule nodeOptions);
        default = [];
        description = ''
          Specify specific informations about nodes in the cluster.
        '';
      };

      quorum = {

        provider = mkOption {
          type = types.nullOr (types.enum [ "corosync_votequorum" ]);
          default = null;
          description = ''
            Specify the quorum algorithm to use.
          '';
        };

        expectedVotes = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = ''
            Specify the number of expected votes in the cluster.
          '';
        };

        twoNode = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Enable two node cluster operations.
          '';
        };

        waitForAll = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Enable Wait For All (WFA) feature.
          '';
        };

        lastManStanding = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Enable Last Man Standing (LMS) feature.
          '';
        };

        lastManStandingWindow = mkOption {
          type = types.int;
          default = 10000;
          description = ''
            Sepcify Last Man Standing (LMS) window in ms.
          '';
        };

        autoTieBreaker = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Enable Auto Tie Breaker (ATB) feature.
          '';
        };

        autoTieBreakerNode = mkOption {
          type = with types; either (enum [ "lowest" "highest" ]) (listOf int);
          default = "lowest";
          description = ''
            Enable Auto Tie Breaker (ATB) feature.
          '';
        };

        allowDownscale = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Enable Allow Downscale (AD) feature.
          '';
        };

        expectedVotesTracking = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Enable Expected Votes Tracking (EVT) feature.
          '';
        };

      };

    };

  };

  config = mkIf cfg.enable {

    services.corosync.conf = builtins.toFile "corosync.conf" (confToString cfg);

  };

}
