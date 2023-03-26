{ lib, pkgs, config, agenix, ... }:
with lib;
let
  cfg = config.services.traefikDC;
  dockerComposeFileContent = ''
    version: "3"  

    services:
      traefik:
        # container_name: traefik
        image: traefik:v2.4.7
        command:
          - "--api.dashboard=true"
          - "--providers.docker=true"
          - "--entryPoints.web.address=:80"
          - "--entryPoints.websecure.address=:443"
          ${if cfg.acmeStaging then "- \"--certificatesResolvers.le.acme.caServer=https://acme-staging-v02.api.letsencrypt.org/directory\"" else ""}
          - "--certificatesResolvers.le.acme.email=''${TRAEFIK_ACME_EMAIL}"
          - "--certificatesResolvers.le.acme.storage=acme.json"
          - "--certificatesResolvers.le.acme.tlsChallenge=true"
          - "--certificatesResolvers.le.acme.httpChallenge=true"
          - "--certificatesResolvers.le.acme.httpChallenge.entryPoint=web"
        restart: always
        ports:
          - 80:80
          - 443:443
        networks:
          - traefik
        volumes:
          - /var/run/docker.sock:/var/run/docker.sock # Access to Docker daemon
          - traefik_certificate_store:/letsencrypt # ACME support
        labels:
          # Redirect all HTTP to HTTPS permanently
          - traefik.http.routers.http_catchall.rule=HostRegexp(`{any:.+}`)
          - traefik.http.routers.http_catchall.entrypoints=web
          - traefik.http.routers.http_catchall.middlewares=https_redirect
          - traefik.http.middlewares.https_redirect.redirectscheme.scheme=https
          - traefik.http.middlewares.https_redirect.redirectscheme.permanent=true
          # API security
          - traefik.http.routers.api.tls=true # TLS
          - traefik.http.routers.api.tls.certresolver=le # TLS
          - "traefik.http.routers.api.rule=Host(`''${TRAEFIK_API_HOST}`)"
          - "traefik.http.routers.api.service=api@internal"
          - "traefik.http.routers.api.middlewares=auth"
          # See Bitwarden for password      
          - "traefik.http.middlewares.auth.basicauth.users=''${TRAEFIK_API_BASICAUTH}"
    networks:
      ${dockerTraefikNetworkName}:
        external: true
    volumes:
      traefik_certificate_store:

  '';
  dockerComposeFile = (pkgs.writeTextDir "traefik/docker-compose.yml" dockerComposeFileContent) + "/traefik/docker-compose.yml";
  dockercli = "${config.virtualisation.docker.package}/bin/docker";
  dockerComposeBaseCmd = "${dockercli} compose --file ${dockerComposeFile} --env-file ${config.age.secrets.traefikEnvFile.path}";
  dockerTraefikNetworkName = "${cfg.dockerNetworkName}";
in
{
  options.services.traefikDC = {
    enable = mkEnableOption "Traefik using Docker Compose";
    acmeStaging = mkEnableOption "Enable Staging for ACME";
    agenixTraefikEnvFile = mkOption {
      type = types.path;
    };
    dockerNetworkName = mkOption {
      type = types.str;
      default = "traefik";
    };
  };

  config = mkIf cfg.enable {
    age.secrets.traefikEnvFile.file = cfg.agenixTraefikEnvFile;

    virtualisation.docker.enable = true;
    systemd.services.traefik-docker-compose-createnetwork = {
      description = "Create the network bridge traefik-net for traefik.";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig.Type = "oneshot";
      script =
        ''
          # Put a true at the end to prevent getting non-zero return code, which will
          # crash the whole service.
          check=$(${dockercli} network ls | grep "${dockerTraefikNetworkName}" || true)
          if [ -z "$check" ]; then
            ${dockercli} network create ${dockerTraefikNetworkName}
          else
            echo "Network \"${dockerTraefikNetworkName}\" already exists"
          fi
        '';
    };
    systemd.services.traefik-docker-compose-startstop = {
      description = "Start and stop docker compose for Traefik";
      after = [ "network.target" "traefik-docker-compose-createnetwork.service" ];
      wantedBy = [ "multi-user.target" ];
      requires = [ "traefik-docker-compose-createnetwork.service" ];
      script = "${dockerComposeBaseCmd} up";
      serviceConfig = {
        ExecStop = "${dockerComposeBaseCmd} down";
      };
    };
  };
}
