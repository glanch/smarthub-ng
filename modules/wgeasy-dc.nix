{ lib, pkgs, config, agenix, ... }:
with lib;
let
  cfg = config.services.wgeasyDC;
  dockerComposeFileContent = ''
    version: "3.8"
    services:
      wg-easy:
        environment:
          - WG_HOST=''${WGEASY_WG_HOST}
          - PASSWORD=''${WGEASY_PASSWORD}
          - WG_PORT=''${WGEASY_WG_PORT}
          - WG_DEFAULT_ADDRESS=''${WGEASY_WG_DEFAULT_ADDRESS}
          - WG_DEFAULT_DNS=''${WGEASY_WG_DEFAULT_DNS}
        image: weejewel/wg-easy:latest
        volumes:
          - ${wgeasyStateDirectory}:/etc/wireguard
        ports:
          - "51820:51820/udp"
          - "51821:51821/tcp"
        restart: unless-stopped
        cap_add:
          - NET_ADMIN
          - SYS_MODULE
        sysctls:
          - net.ipv4.ip_forward=1
          - net.ipv4.conf.all.src_valid_mark=1
        labels:
          - traefik.enable=true
          - traefik.docker.network=traefik
          - traefik.http.services.wgeasy.loadbalancer.server.port=51821
          - traefik.http.routers.wgeasy.rule=Host(`''${WGEASY_HOST}`)
          - traefik.http.routers.wgeasy.tls=true
          - traefik.http.routers.wgeasy.tls.certresolver=le
          - traefik.http.routers.wgeasy.middlewares=wgeasy-auth
          - traefik.http.middlewares.wgeasy-auth.basicauth.users=''${WGEASY_BASIC_AUTH}
          - traefik.port=51821
        networks:
          - traefik
    networks:
      traefik:
        external: true

    volumes:
      wgeasy_storage:
  '';
  dockerComposeFile = (pkgs.writeTextDir "wgeasy/docker-compose.yml" dockerComposeFileContent) + "/wgeasy/docker-compose.yml";
  dockerCli = dockerUtils.mkDockerCliPath config;
  composeBaseCmd = "compose --file ${dockerComposeFile} --env-file ${config.age.secrets.wgeasyEnvFile.path}";
  dockerTraefikNetworkName = "${cfg.dockerNetworkName}";

  dockerUtils = import ./utils/docker-utils.nix;

  username = "wgeasyDCUser";
  userHomeDirectory = config.users.users."${username}".home;

  wgeasyStateDirectory = config.users.users.christopher.home + "/services/wg-easy/";
in
{
  options.services.wgeasyDC = {
    enable = mkEnableOption "wgeasy using Docker Compose";
    agenixWgeasyEnvFile = mkOption {
      type = types.path;
    };
  };

  config = mkIf cfg.enable {
    age.secrets.wgeasyEnvFile.file = cfg.agenixWgeasyEnvFile;

    # Create user
    users.users."${username}" = {
      isNormalUser = true;
      createHome = true;
      group = username;
    };

    users.groups."${username}" = { };

    virtualisation.docker.enable = true;

    systemd.services.wgeasy-docker-compose-startstop = dockerUtils.mkDockerStartStopService
      dockerCli # Inject docker cli path
      "wgeasy Docker Compose" # Description name 
      composeBaseCmd # Base command for docker compose calls, including docker compose file
      [ "traefik-docker-compose-startstop.service" ] # After: Traefik
      [ "traefik-docker-compose-startstop.service" ]; # Requires: Traefik
  };
}
