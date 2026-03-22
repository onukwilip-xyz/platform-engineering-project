resource "null_resource" "script_permissions" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash"]
    command     = "chmod +x ${abspath(path.module)}/scripts/*.sh"
  }

  triggers = {
    always = timestamp()
  }
}