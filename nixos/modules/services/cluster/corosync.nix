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
        Whether to log output messages.
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
          Specify the ring number.
        '';
      };
    };
  };

  boolToYesOrNo = b: if b then "yes" else "no";

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

  loggerSubsysToString = def: ''
    logger_subsys {
      subsys: ${def.subsys}
      to_stderr: ${boolToYesOrNo def.toStderr} 
      to_logfile: ${boolToYesOrNo def.toLogfile} 
      to_syslog: ${boolToYesOrNo def.toSyslog} 
  '' + optionalString (def.logfile != null) "  logfile: ${def.logfile}\n" + ''
      logfile_priority: ${def.logfilePriority}
      syslog_priority: ${def.syslogPriority}
      syslog_facility: ${def.syslogFacility}
      debug: ${boolToYesOrNo def.debug}
    }
  '';

  loggingToString = def: ''
    logging {
      timestamp: ${boolToYesOrNo def.timestamp}
      fileline: ${boolToYesOrNo def.fileline}
      function_name: ${boolToYesOrNo def.functionName}
      to_stderr: ${boolToYesOrNo def.toStderr} 
      to_logfile: ${boolToYesOrNo def.toLogfile} 
      to_syslog: ${boolToYesOrNo def.toSyslog} 
  '' + optionalString (def.logfile != null) "  logfile: ${def.logfile}\n" + indent ''
      logfile_priority: ${def.logfilePriority}
      syslog_facility: ${def.syslogFacility}
      syslog_priority: ${def.syslogPriority}
      debug: ${boolToYesOrNo def.debug}
  '' + indent (concatMapStrings loggerSubsysToString def.loggerSubsys) + ''
    }
  '';

  confToString = def: totemToString def.totem + loggingToString def.logging;

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
            Specify the version of the IP protocol to used."
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
            List of interface sub-directives.
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

    };

  };

  config = mkIf cfg.enable {

    environment.etc."corosync/corosync.conf".text = confToString cfg;

  };

}
