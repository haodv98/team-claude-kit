---
name: aws-k8s-operations
description: Cung cấp hướng dẫn sử dụng các bash tool script để deploy ECS và kOps
---
Khi người dùng yêu cầu deploy, hãy dùng Bash tool để gọi các script sau trong thư mục `~/.claude/scripts/`:

1. `ecs-deploy.sh <cluster_name> <service_name> <image_tag>`: Force new deployment cho ECS service.
2. `kops-export.sh <cluster_name>`: Export kubeconfig cho kOps cluster.
