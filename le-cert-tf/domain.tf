locals {
  nameservers_param          = join("&", [for i, ns in local.nameservers : "nameserver${i}=${replace(ns, "/\\.$/", "")}"])
  nameservers_update_request = "https://coreapi.1api.net/api/call.cgi?s_login=${var.domain_user}&s_pw=${var.domain_password}&command=ModifyDomain&domain=${var.domainname}&${local.nameservers_param}"
}
resource "null_resource" "domain_update_nameservers" {
  provisioner "local-exec" {
    command = "curl '${local.nameservers_update_request}' | grep -q CODE=200"
  }
  provisioner "local-exec" {
    # This takes some time to come online. Depends on the TLD nic and your registrar:
    #
    # null_resource.domain_update_nameservers (local-exec): bitrock.best.             3600    IN      NS      ns-cloud-e1.googledomains.com.
    # null_resource.domain_update_nameservers (local-exec): bitrock.best.             21600   IN      NS      ns-cloud-e1.googledomains.com.
    # null_resource.domain_update_nameservers: Creation complete after 7m2s [id=1070874612440103890]
    command = "while true; do dig +trace ns ${var.domainname} | grep '^${var.domainname}.' | grep ${local.nameservers[0]} && exit 0; echo Waiting for nameservers to be updated ...; sleep 15;done"
  }
}
