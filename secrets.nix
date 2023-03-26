let
  christopherAtT20 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPxRvs89rIfr+zkkKfZEndvmL4EEGjgEi89HZRpxVzi/ christopher@christopher-t20";
  users = [ christopherAtT20 ];

  smarthubNg = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDF0RUknhg27Upo//HiipjUjUzbkGyhzF3VIsKy4YJ4K";
  systems = [ smarthubNg ];
in
{
  "secrets/traefik/env.age".publicKeys = users ++ [ smarthubNg ];
  "secrets/wgeasy/env.age".publicKeys = users ++ [ smarthubNg ];
}