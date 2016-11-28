{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.services.corosync;

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

      totem = {

        version = mkOption {
          type = types.integer;
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
          type = types.integer;
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
          type = types.integer;
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
          type = types.integer;
          default = "1000";
          description = ''
            Specify the timeout in ms until token loss is declared after not receiving a token.
          '';
        };

      };

    };

  };

  config = {
  };

}
