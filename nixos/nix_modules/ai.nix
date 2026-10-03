# This has been disabled in the core
# config
{ config, pkgs, ... }:

{
  services.ollama = {
    enable = true;
    loadModels = [ "gemma4"];
    package = pkgs.ollama-cuda;
    acceleration = "cuda";
  };

}
