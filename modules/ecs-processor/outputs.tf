output "cluster_name"          { value = aws_ecs_cluster.processor.name }
output "task_definition_arn"   { value = aws_ecs_task_definition.processor.arn }
output "task_role_arn"         { value = aws_iam_role.ecs_task.arn }
