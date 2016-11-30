{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.security.sudo;

  inherit (pkgs) sudo;

  # Careful: OpenLDAP seems to be very picky about the indentation of
  # this file.  Directives HAVE to start in the first column!
  ldapConfig = {
    target = "sudo-ldap.conf";
    source = pkgs.writeText "sudo-ldap.conf" ''
      uri ${cfg.ldap.server}
      sudoers_base ${cfg.ldap.sudoersBase}
      ${optionalString (cfg.ldap.sudoersSearchFilter != null) ''
        sudoers_search_filter ${cfg.ldap.sudoersSearchFilter}
      ''}
      ${optionalString (cfg.ldap.sudoersTimed != null) ''
        sudoers_timed ${if cfg.ldap.sudoersTimed then "true" else "false"}
      ''}
      timelimit ${toString cfg.ldap.timeLimit}
      bind_timelimit ${toString cfg.ldap.bind.timeLimit}
      ${optionalString cfg.ldap.useTLS ''
        ssl start_tls
        tls_checkpeer no
      ''}
      ${optionalString (cfg.ldap.bind.distinguishedName != "") ''
        binddn ${cfg.ldap.bind.distinguishedName}
      ''}
      ${optionalString (cfg.ldap.extraConfig != "") cfg.ldap.extraConfig }
    '';
  };

in

{

  ###### interface

  options = {

    security.sudo.enable = mkOption {
      type = types.bool;
      default = true;
      description =
        ''
          Whether to enable the <command>sudo</command> command, which
          allows non-root users to execute commands as root.
        '';
    };

    security.sudo.wheelNeedsPassword = mkOption {
      type = types.bool;
      default = true;
      description =
        ''
          Whether users of the <code>wheel</code> group can execute
          commands as super user without entering a password.
        '';
      };

    security.sudo.configFile = mkOption {
      type = types.lines;
      # Note: if syntax errors are detected in this file, the NixOS
      # configuration will fail to build.
      description =
        ''
          This string contains the contents of the
          <filename>sudoers</filename> file.
        '';
    };

    security.sudo.ldap = {

      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to enable sudo to be configured via LDAP.
        '';
      };

      server = mkOption {
        example = "ldap://ldap.example.org/";
        description = "The URL of the LDAP server.";
      };

      useTLS = mkOption {
        default = false;
        description = ''
          If enabled, use TLS (encryption) over an LDAP (port 389)
          connection. The alternative is to specify an LDAPS server
          (port 636) in <option>security.sudo.ldap.server</option> or
          to forego security.
        '';
      };

      timeLimit = mkOption {
        default = 0;
        type = types.int;
        description = ''
          Specifies the time limit (in seconds) to use when performing
          searches. A value of zero (0), which is the default, is to
          wait indefinitely for searches to be completed.
        '';
      };

      sudoersBase = mkOption {
        type = types.str;
        description = ''
          The base DN to use when performing sudo LDAP queries.
        '';
      };

      sudoersSearchFilter = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          An LDAP filter which is used to restrict the set of records
          returned when performing a sudo LDAP query.
        '';
      };

      sudoersTimed = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = ''
          Whether to evaluate the sudoNotBefore and sudoNotAfter
          attributes that implement time-dependent sudoers entries.
        '';
      };

      bind = {

        distinguishedName = mkOption {
          default = "";
          example = "cn=admin,dc=example,dc=com";
          type = types.str;
          description = ''
            The distinguished name to bind to the LDAP server with. If this
            is not specified, an anonymous bind will be done.
          '';
        };

        password = mkOption {
          default = "/etc/ldap/bind.password";
          type = types.str;
          description = ''
            The path to a file containing the credentials to use when binding
            to the LDAP server (if not binding anonymously).
          '';
        };

        timeLimit = mkOption {
          default = 30;
          type = types.int;
          description = ''
            Specifies the time limit (in seconds) to use when connecting
            to the directory server. This is distinct from the time limit
            specified in <option>security.sudo.ldap.timeLimit</option>
            and affects the initial server connection only.
          '';
        };

      };

      extraConfig  = mkOption {
        type = types.lines;
        default = "";
        description = ''
          Extra configuration text appended to the LDAP configuration of sudo.
        '';
      };

    };

    security.sudo.extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = ''
        Extra configuration text appended to <filename>sudoers</filename>.
      '';
    };
  };


  ###### implementation

  config = mkIf cfg.enable {

    security.sudo.configFile =
      ''
        # Don't edit this file. Set the NixOS options ‘security.sudo.configFile’
        # or ‘security.sudo.extraConfig’ instead.

        # Environment variables to keep for root and %wheel.
        Defaults:root,%wheel env_keep+=TERMINFO_DIRS
        Defaults:root,%wheel env_keep+=TERMINFO

        # Keep SSH_AUTH_SOCK so that pam_ssh_agent_auth.so can do its magic.
        Defaults env_keep+=SSH_AUTH_SOCK

        # "root" is allowed to do anything.
        root        ALL=(ALL:ALL) SETENV: ALL

        # Users in the "wheel" group can do anything.
        %wheel      ALL=(ALL:ALL) ${if cfg.wheelNeedsPassword then "" else "NOPASSWD: ALL, "}SETENV: ALL
        ${cfg.extraConfig}
      '';

    security.setuidPrograms = [ "sudo" "sudoedit" ];

    environment.systemPackages = [ sudo ];

    security.pam.services.sudo = { sshAgentAuth = true; };

    environment.etc = [
      { source =
          pkgs.runCommand "sudoers"
          { src = pkgs.writeText "sudoers-in" cfg.configFile; }
          # Make sure that the sudoers file is syntactically valid.
          # (currently disabled - NIXOS-66)
          "${pkgs.sudo}/sbin/visudo -f $src -c && cp $src $out";
        target = "sudoers";
        mode = "0440";
      }
    ] ++ optionals cfg.ldap.enable [
      ldapConfig
      { text = ''
          Plugin sudoers_policy sudoers.so ldap_conf=/etc/sudo-ldap.conf
        '';
        target = "sudo.conf";
      }
    ];

    system.activationScripts = mkIf cfg.ldap.enable {
      sudoLdap = stringAfter [ "etc" ] ''
        if test -f "${cfg.ldap.bind.password}" ; then
          echo "bindpw "$(cat ${cfg.ldap.bind.password})"" | cat ${ldapConfig.source} - > /etc/sudo-ldap.conf.bindpw
          mv -fT /etc/sudo-ldap.conf.bindpw /etc/sudo-ldap.conf
          chmod 600 /etc/sudo-ldap.conf
        fi
      '';
    };

  };

}
