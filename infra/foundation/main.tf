resource "aws_ecr_repository" "ronin" {
  name                 = "ronin"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name    = "ronin"
    Project = "RONIN"
  }
}

resource "aws_route53_zone" "ronin" {
  name = "ronin.humdaan.co.uk"

  tags = {
    Name    = "ronin.humdaan.co.uk"
    Project = "RONIN"
  }
}

resource "cloudflare_dns_record" "ronin_delegation" {
  for_each = {
    ns1 = aws_route53_zone.ronin.name_servers[0]
    ns2 = aws_route53_zone.ronin.name_servers[1]
    ns3 = aws_route53_zone.ronin.name_servers[2]
    ns4 = aws_route53_zone.ronin.name_servers[3]
  }

  zone_id = var.cloudflare_zone_id
  name    = "ronin"
  type    = "NS"
  content = each.value
  ttl     = 3600
}
