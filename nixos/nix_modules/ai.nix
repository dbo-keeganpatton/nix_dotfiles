{ config, pkgs, ... }:

{
  services.ollama = {
    enable = true;
    loadModels = [ "gemma4"];
    package = pkgs.ollama-cuda;
    acceleration = "cuda";
  };

}
