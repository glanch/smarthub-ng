{
  mkDockerCliPath = config: "${config.virtualisation.docker.package}/bin/docker";
  mkDockerNetworkCreationService = dockerCli: networkName: {
    description = "Create the Docker network bridge ${networkName}.";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig.Type = "oneshot";
    script =
      ''
        # Put a true at the end to prevent getting non-zero return code, which will
        # crash the whole service.
        check=$(${dockerCli} network ls | grep "${networkName}" || true)
        if [ -z "$check" ]; then
          ${dockerCli} network create ${networkName}
        else
          echo "Network \"${networkName}\" already exists"
        fi
      '';
  };

  mkDockerStartStopService = dockerCli: name: composeBaseCmd: after: requires: {
    description = "Start and stop Docker Compose file for ${name}";
    after = [ "network.target" ] ++ after;
    wantedBy = [ "multi-user.target" ];
    requires = requires;
    script = "${dockerCli} ${composeBaseCmd} up";
    serviceConfig = {
      ExecStop = "${dockerCli} ${composeBaseCmd} down";
    };
  };
}
