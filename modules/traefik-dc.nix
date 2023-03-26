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
  dockerCli = dockerUtils.mkDockerCliPath config;
  composeBaseCmd = "compose --file ${dockerComposeFile} --env-file ${config.age.secrets.traefikEnvFile.path}";
  dockerTraefikNetworkName = "${cfg.dockerNetworkName}";

  dockerUtils = import ./utils/docker-utils.nix;
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

    systemd.services.traefik-docker-compose-createnetwork = dockerUtils.mkDockerNetworkCreationService dockerCli dockerTraefikNetworkName;

    systemd.services.traefik-docker-compose-startstop = dockerUtils.mkDockerStartStopService
      dockerCli # Inject docker cli path
      "Traefik Docker Compose" # Description name 
      composeBaseCmd # Base command for docker compose calls, including docker compose file
      [ "traefik-docker-compose-createnetwork.service" ] # After: network creation
      [ "traefik-docker-compose-createnetwork.service" ]; # Requires: network creation
  };
}
