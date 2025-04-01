{
  description = "Nix flake templates for mulatta";
  outputs =
    { self }:
    {
      templates = {
        python = {
          path = ./python;
          description = "Python template using uv2nix";
        };
      };
    };
}
