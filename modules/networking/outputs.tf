output "vpc_id" { value = aws_vpc.main.id }
output "private_subnet_ids" { value = aws_subnet.private[*].id }
output "public_subnet_ids" { value = aws_subnet.public[*].id }
output "private_route_table_id" { value = aws_route_table.private.id }
output "sg_lambda_id" { value = aws_security_group.lambda.id }
output "sg_ecs_processor_id" { value = aws_security_group.ecs_processor.id }
output "sg_rds_id" { value = aws_security_group.rds.id }
output "sg_vpce_id" { value = aws_security_group.vpce.id }
